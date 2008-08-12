#========================================================================
#
# Badger::Exporter
#
# DESCRIPTION
#   This module is an OO version of the Exporter module.  It 
#   does the same kind of thing but with an OO interface that means
#   you don't have to go messing around with package variables.  It
#   correctly handles inheritance, exporting not only those symbols
#   defined by a subclass, but also those of its base classes.  
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Exporter;

use strict;
use warnings;
use Carp;
use constant {              
    ALL          => 'all',             # Alas, we can't pull these in from 
    NONE         => 'none',            # Badger::Constants because it's a 
    DEFAULT      => 'default',         # subclass of Badger::Exporter which
    IMPORT       => 'import',          # gives us a chicken-and-egg dependency
    IMPORTS      => 'imports',         # problem.  We could pull them into 
    HOOKS        => 'hooks',           # Badger::Constants though because that's
    ARRAY        => 'ARRAY',           # a subclass... hmmm....
    HASH         => 'HASH',      
    CODE         => 'CODE',
    EXPORT_ALL   => 'EXPORT_ALL',
    EXPORT_ANY   => 'EXPORT_ANY',
    EXPORT_TAGS  => 'EXPORT_TAGS',
    EXPORT_FAIL  => 'EXPORT_FAIL',
    EXPORT_HOOKS => 'EXPORT_HOOKS',
    EXPORTABLES  => 'EXPORTABLES',
    ISA          => 'ISA',
    REFS         => 'refs',
    ONCE         => 'once',
    PKG          => '::',
    DELIMITER    => qr/(?:,\s*)|\s+/,  # match a comma or whitespace
};

our $VERSION   = 0.01;
our $DEBUG     = 0 unless defined $DEBUG;
our $HANDLERS  = {
    all   => \&export_all,
    any   => \&export_any,
    tags  => \&export_tags,
    hooks => \&export_hooks,
    fail  => \&export_fail,
};


#-----------------------------------------------------------------------
# export declaration methods:
#   exports( all => [...], any => [...], ...etc... )
#   export_all('foo bar baz')                 
#   export_any('foo bar baz')
#   export_tags( set1 => 'foo bar baz', set2 => 'wam bam' )
#   export_hooks( foo => sub { ... }, bar => sub { ... } )
#   export_fail( sub { ... } )
#-----------------------------------------------------------------------

sub exports {
    my $self = shift;
    my $data = @_ == 1 && ref $_[0] eq HASH ? shift : { @_ };
    my $handler;

    # delegate each key in $data to a handler in $HANDLERS
    while (my ($key, $value) = each %$data) {
        $handler = $HANDLERS->{ $key } 
            || croak "Invalid exports key: $key\n";
        $handler->($self, $value);
    }
}

sub export_all {
    my $self  = shift;
    my $class = ref $self || $self;
    my $tags  = @_ == 1 ? shift : [ @_ ];
    no strict REFS;

    push(
        # add to existing $EXPORT_ALL pkg var or a newly created list...
        @{ ${$class.PKG.EXPORT_ALL} ||= [ ] }, 
        # ...arguments passed as list/list ref, or split single string
        ref $tags eq ARRAY ? @$tags : split(DELIMITER, $tags)
    )
}

sub export_any {
    my $self  = shift;
    my $class = ref $self || $self;
    my $tags  = @_ == 1 ? shift : [ @_ ];
    no strict REFS;

    push(
        # add to existing $EXPORT_ANY pkg var or a newly created list...
        @{ ${$class.PKG.EXPORT_ANY} ||= [ ] }, 
        # ...arguments passed as list/list ref, or split single string
        ref $tags eq ARRAY ? @$tags : split(DELIMITER, $tags)
    )
}

sub export_tags {
    my $self  = shift;
    my $class = ref $self || $self;
    my $tags  = (@_ == 1) && (ref $_[0] eq HASH) ? shift : { @_ };
    no strict REFS;

    # add new tags into $EXPORT_TAGS hash ref
    my $export_tags = ${ $class.PKG.EXPORT_TAGS } ||= { };
    @$export_tags{ keys %$tags } = values %$tags;

    # all symbols referenced in tagsets (except other tag sets) must be 
    # flagged as exportable
    $self->export_any(
        grep {
            # ignore references to code or other tag sets
            not (ref || /^:/);
        }
        map {
            # symbols in tagset can be a list ref, hash ref or string
            ref $_ eq ARRAY ? @$_ :
            ref $_ eq HASH  ? %$_ :
            split DELIMITER
        } 
        values %$tags
    );
    
    return $export_tags;
}

sub export_hooks {
    my $self  = shift;
    my $class = ref $self || $self;
    my $hooks = (@_ == 1) && (ref $_[0] eq HASH) ? shift : { @_ };
    no strict REFS;

    # add new export hooks into $EXPORT_HOOK hash ref
    my $table = ${$class.PKG.EXPORT_HOOKS};
    if ($table) {
        @$table{ keys %$hooks } = values %$hooks;
    }
    else {
        $table = ${$class.PKG.EXPORT_HOOKS} = $hooks;
    }
    return $table;
}

sub export_fail {
    my $self  = shift;
    my $class = ref $self || $self;
    no strict REFS;
    
    # get/set $EXPORT_FAIL
    return @_
        ? (${$class.PKG.EXPORT_FAIL} = shift)
        :  ${$class.PKG.EXPORT_FAIL};
}


#------------------------------------------------------------------------
# import/export methods:
#   import(@imports)
#   export($target, @exports)
#------------------------------------------------------------------------

sub import {
    my $class  = shift;
    my $target = (caller())[0];

    # enable strict and warnings in the caller - this ensures that every 
    # Badger module (that calls this method - which is pretty much all of 
    # them) has strict/warnings enabled, without having to explicitly write 
    # it.  Thx Moose!
    strict->import;
    warnings->import;
    
    # call in the heavy guns
    $class->export($target, @_);
}

sub export {
    my $class     = shift;
    my $target    = shift;
    my $imports   = @_ == 1 ? shift : [ @_ ];
    my ($all, $any, $tags, $hooks, $fails) 
                  = $class->exportables;
    my $can_hook  = (%$hooks ? 1 : 0);
    my $added_all = 0;
    my $count     = 0;
    my ($symbol, $symbols, $source, $hook, $pkg, %done, @errors);

    no strict   REFS;
    no warnings ONCE;

    # imports can be a single whitespace delimited string of symbols
    $imports = [ split(DELIMITER, $imports) ]
        unless ref $imports eq ARRAY;
    
    # default to export_all if list of exports not specified
    # TODO: what about: use Badger::Example qw();    ?  perhaps we should
    # return unless @_ up above?
    @$imports = @$all unless @$imports;

    SYMBOL: while (@$imports) {
        next unless ($symbol = shift @$imports);
        next if $done{ $symbol }++;
        
        # look for :tagset symbols and expand their contents onto @$imports
        if ($symbol =~ s/^://) {
            if ($symbols = $tags->{ $symbol }) {
                if (ref $symbols eq ARRAY) {
                    # expand list of symbols onto @$imports list
                    unshift(@$imports, @$symbols);
                }
                elsif (ref $symbols eq HASH) {
                    # map hash into [name => $symbol] pairs
                    unshift(@$imports, map { [$_ => $symbols->{ $_ }] } keys %$symbols);
                }
                else {
                    # string of space-delimited symbols
                    unshift(@$imports, split(DELIMITER, $symbols));
                }
            }
            elsif ($symbol eq DEFAULT) {
                unshift(@$imports, @$all);
            }
            elsif ($symbol eq ALL) {
                unshift(@$imports, keys %$any);
                $added_all = 1;
            }
            else {
                push(@errors, "Invalid import tag: $symbol\n");
            }
            next SYMBOL;
        }

        if (ref $symbol eq ARRAY) {
            # a pair of [name, $symbol] expanded from a :tag hash set 
            ($symbol, $source) = @$symbol;
#           _debug("expanded export pair: $symbol => $source\n") if $DEBUG;
        }
        elsif ($can_hook && ($hook = $hooks->{ $symbol })) {
            # fire off handler hooked to this import item
            &$hook($class, $target, $symbol, $imports);
            # hooks can be repeated so pretend we haven't done it
            $done{ $symbol }--;     
            next SYMBOL;
        }
        elsif ($symbol eq IMPORTS) {
            # special 'imports' hook disables any more hooks causing
            # all remaining arguments to be imported as symbols
            $can_hook = 0;
            next SYMBOL;
        }
        elsif ($symbol eq IMPORT) {
            # 'import' hook accepts the next item as an import list/string 
            # and unpacks it onto the front of the imports list.  We disable
            # hooks for the duration of the import and insert a dummy HOOKS 
            # symbol at the end to re-enable hooks
            $can_hook = 0;
            if ($symbols = shift @$imports) {
                $symbols = [ split(DELIMITER, $symbols) ] 
                    unless ref $symbols eq ARRAY;
                unshift(@$imports, @$symbols, HOOKS);
            }
            else {
                push(@errors, "Missing argument for $symbol hook\n");
            }
            next SYMBOL;
        }
        elsif ($symbol eq HOOKS) {
            # special 'hooks' item turns hooks back on
            $can_hook = 1;
            next SYMBOL;
        }
        else {
            # otherwise the symbol exported is the one requested
            $source = $symbol;
        }
        
        # check we're allowed to export the symbol requested
        if ($pkg = $any->{ $symbol }) {
#           _debug("exporting $symbol from $pkg to $target\n") if $DEBUG;
        }
        else {
            foreach $hook (@$fails) {
                if (&$hook($class, $target, $symbol, $imports)) {
                    # hooks can be repeated so pretend we haven't done it
                    $done{ $symbol }--;
                    next SYMBOL;
                }
            }
            push(@errors, "$symbol is not exported by $class\n");
            next SYMBOL;
        }

        if (ref $source eq CODE) {
            # patch directly into the code ref
#           _debug("exporting $symbol from code reference\n") if $DEBUG;
            *{ $target.PKG.$symbol } = $source;
        }
        else {
            my $type = "&";
            $symbol =~ s/^(\W)//;
            $source =~ s/^(\W)// and $type = $1;
            $source = $pkg.PKG.$source unless $source =~ /::/;
           _debug("exporting $type$symbol from $source into $target\n") if $DEBUG;
            *{ $target.PKG.$symbol } =
                $type eq '&' ? \&{$source} :
                $type eq '$' ? \${$source} :
                $type eq '@' ? \@{$source} :
                $type eq '%' ? \%{$source} :
                $type eq '*' ?  *{$source} :
                do { push(@errors, "Can't export symbol: $type$symbol\n"); next; };
        }
        $count++;
    }
    continue {
        # if we're on the last item and we've only processed hooks
        # (i.e. no real symbols were specified then we export the 
        # default set of symbols instead
        unless (@$imports or $count or $added_all) {
            unshift(@$imports, @$all);
            $added_all = 1;
        }
    }

    if (@errors) {
        require Carp;
        Carp::croak("@{errors}Can't continue after import errors");
    }

    return 1;
}

sub exportables {
    my $class = shift;
    no strict REFS;
    my $cache = ${ $class.PKG.EXPORTABLES } ||= do {
        my ($pkg, $symbols, %done, @all, %any, %tags, %hooks, @fails);
        my @pending = ($class);
        no strict REFS;

        # walk up inheritance tree collecting values from the @$EXPORT_ALL, 
        # @$EXPORT_ANY, %$EXPORT_TAGS, %$EXPORT_HOOKS and $EXPORT_FAIL pkg 
        # variables, then cache them in $EXPORT_CACHE for subsequent use

        while ($pkg = shift @pending) {
            next if $done{ $pkg }++;

            # $EXPORT_ANY package vars are list references containing symbols,
            # which we use to populate the %any hash which maps symbols to 
            # their source packages.  e.g. { foo => 'My::Package' }
            # The presence of an entry in this table indicates that the symbol
            # key can be exported.  The corresponding value indicates the 
            # package that it must be exported from.  We don't replace any 
            # existing entries in the %any hash because we're working from 
            # sub-class upwards to super-class, .  This ensures that the 
            # entries put in first by more specialised sub-classes are used 
            # in preference to those defined by more general super-classes.
            if ($symbols = ${ $pkg.PKG.EXPORT_ANY }) {
                $any{ $_ } ||= $pkg 
                    for @$symbols;
            }

            # $EXPORT_ALL is merged into @all and all symbols are mapped 
            # to their packages in %any
            if ($symbols = ${ $pkg.PKG.EXPORT_ALL }) {
                push(
                    @all,
                    map { $any{ $_ } ||= $pkg; $_ }
                    @$symbols
                );
            }

            # $EXPORT_TAGS are copied into %tags unless already defined
            if ($symbols = ${ $pkg.PKG.EXPORT_TAGS }) {
                $tags{ $_ } ||= $symbols->{ $_ } 
                    for keys %$symbols;
            }

            # $EXPORT_HOOKS are copied into %hooks unless already defined
            if ($symbols = ${ $pkg.PKG.EXPORT_HOOKS }) {
                $hooks{ $_ } ||= $symbols->{ $_ } 
                    for keys %$symbols;
            }
            
            # $EXPORT_FAIL has only one value per package, but we can have
            # several packages in the class ancestry
            if ($symbols = ${ $pkg.PKG.EXPORT_FAIL }) {
                push(
                    @fails, 
                    $symbols
                );
            }

            # This is the same depth-first inheritance resolution algorithm
            # that Perl uses.  We can't use the fancy heritage() method in 
            # Badger::Class because of the Chicken-and-Egg dependency problem
            # between Badger::Exporter and Badger::Class
            push(@pending, @{$pkg.PKG.ISA});
        }
        
        [\@all, \%any, \%tags, \%hooks, \@fails];
    };
    
    return wantarray
        ? @$cache
        :  $cache;
}

sub export_symbol {
    my ($self, $target, $symbol, $coderef) = @_;
    no strict   REFS;
    no warnings ONCE;
    *{ $target.PKG.$symbol } = $coderef;
}

sub _debug {
    print STDERR @_;
}


1;

__END__

=head1 NAME

Badger::Exporter - symbol exporter 

=head1 SYNOPSIS

Defining a module subclassed from Badger::Exporter:

    package Badger::AnyModule;
    use base 'Badger::Exporter';
    our ($WIZ, $BANG, @BING, %BONG);

Specifying the exports using the all-in-one C<exports()> method:

    __PACKAGE__->exports(
        all  => '$WIZ $BANG',           # like Exporter's @EXPORT
        any  => '@BING %BONG',          # like @EXPORT_OK
        tags => {                       # like %EXPORT_TAGS
            foobar => 'foo bar',
        },
        hooks => {                      # custom hooks
            hello => sub { 
                print "Hello World!\n" 
            },
        },
        fail => sub {                   # handle unknown exports
            print "I'm sorry Dave, I can't do that.\n"
        },
    );

Or individual C<export_XXX()> methods:

    # export all these symbols by default       # methods can take either
    __PACKAGE__->export_all(qw( $WIZ $BANG ));  # a list of symbols or a
    __PACKAGE__->export_all('$WIZ $BANG');      # space-delimited string
    
    # export these symbols if requested
    __PACKAGE__->export_any(qw( @BING %BONG )); # list
    __PACKAGE__->export_any('@BING %BONG');     # string
    
    # define sets of symbols for export
    __PACKAGE__->export_tags(
        set1 => [ qw( $WIZ $BANG ) ],           # list
        set2 => '@BING %BONG',                  # string
        set3 => 'foo bar',                      # string
        set4 => {                               # hash 
            # use hash ref to define aliases for symbols
            foo => '&the_foo_sub',
            bar => '&the_bar_sub',
        },
    );
    
    # define hooks for import symbols
    __PACKAGE__->export_hooks(
        hello => sub {
            my ($class, $target, $symbol, $more_symbols) = @_;
            print $symbol, " ", shift(@$more_symbols), "\n";
        }
    );
    
    # define catch-all for any failed import symbols
    __PACKAGE__->export_fail(
        sub {
            my ($class, $target, $symbol, $more_symbols) = @_;
            warn "Cannot export $symbol from $class to $target\n";
        }
    );

Using the module:

    package main;
    
    # imports default items: $WIZ $BANG
    use Badger::AnyModule;
    
    # import specific items
    use Badger::AnyModule qw( $WIZ @BING );
    
    # import user-defined sets
    use Badger::AnyModule qw( :set1 :set3 );
    
    # specifying the :default set ($WIZ $BANG) and others
    use Badger::AnyModule qw( :default @BING );
    
    # importing all symbols using the :all set
    use Badger::AnyModule ':all';
    
    # specifying multiple symbols in a single string
    use Badger::AnyModule ':set1 $WIZ @BING';
    
    # triggering import hooks: prints "hello world\n";
    use Badger::AnyModule 
        hello => 'world';  
    
    # import hooks and other items
    use Badger::AnyModule 
        hello => 'world', 
        qw( @BING %BONG );  

    # import fail hook gets called for any unknown symbols
    use Badger::AnyModule 'badger';   
        # warns: Cannot export badger from Badger::AnyModule to main
    
    # imports indicates that all remaining arguments are symbols to
    # import, bypassing any hooks
    use Badger::AnyModule 
        hello   => 'world'
        imports => qw( @BING %BONG );  

    # import (singular) option indicates that the next item is an 
    # import symbols (or multiple symbols in a single string) and
    # disables hooks for that item only.
    use Badger::AnyModule 
        import => '@BING %BONG';  

=head1 DESCRIPTION

This module performs the same basic function as the C<Exporter> module in that
it exports symbols from one package namespace to another.

Howevever, unlike the C<Exporter> module it also accounts for object
inheritance. If your base class module defines a set of exportable symbols
then any subclasses derived from it will also have that same set of symbols
(and any others it adds) available for export.

It implements a number of methods that simplify the process of defining what
symbols can be exported, and provides a convenient mechanism for handling
special import flags. 

=head1 METHODS

These methods can be used to declare the symbols that a module exports.

=head2 exports(%exports)

This all-in-one methods accepts a reference to a hash array, or a list 
of named parameters and forwards the arguments onto the relevant method(s).

    __PACKAGE__->exports(
        all  => '$WIZ $BANG',           # like Exporter's @EXPORT
        any  => '@BING %BONG',          # like @EXPORT_OK
        tags => {                       # like %EXPORT_TAGS
            foobar => 'foo bar',
        },
        hooks => {                      # custom hooks
            hello => sub { 
                print "Hello World!\n" 
            },
        },
        fail => sub {                   # handle unknown exports
            print "I'm sorry Dave, I can't do that.\n"
        },
    );

Each key correponds to one of the methods below, specified without the
C<export_> prefix. e.g. C<all> for L<export_all()>, C<any> for L<export_any()>
and so on. The method is called with the corresponding value being passed
as an argument.

=head2 export_all(@symbols)

Adds all the symbols passed as arguments to the list of items that are
exported by default.  This is equivalent to setting the C<@EXPORT>
package variable when using the C<Exporter> module.

    __PACKAGE__->export_all('$WIZ $BANG');

Symbols can be specified as a a string of space-delimited tokens,
as a list of items, or by reference to a list of items.

    __PACKAGE__->export_all('$WIZ $BANG');          # string
    __PACKAGE__->export_all(qw( $WIZ $BANG ));      # list
    __PACKAGE__->export_all([qw( $WIZ $BANG )]);    # list ref

These symbols will be imported when the module is loaded.

    use Badger::AnyModule;                  # import $WIZ and $BANG

This behaviour can be overridden by specifying an explicit list of
imported symbols.

    use Badger::AnyModule '$BANG';          # $BANG only
    use Badger::AnyModule '$BANG @BONG';    # $BANG and @BONG

If you specify a single string of items to export then it will be
split on whitespace or a comma+whitespace combination of characters
to extract multiple symbol names from the string.  The following
three examples all do the same thing.  The last two are effectively
identical in all but syntax.

    use Badger::AnyModule '$BANG @BONG';    # single string
    use Badger::AnyModule '$BANG' '@BONG';  # two strings
    use Badger::AnyModule qw($BANG @BONG);  # same as above

Note that symbol splitting occurs when you specify a single string.
If you specify multiple strings then none are split.

    # this doesn't work
    use Badger::AnyModule '$WIZ' '$BANG $BONG';     # WRONG!
    
Specify an empty list of arguments if you don't want any symbols 
imported.

    use Badger::AnyModule qw();             # imports nothing

=head2 export_any(@symbols)

Adds all the symbols passed as arguments to the list of items that are
exported on request. This is equivalent to setting the C<@EXPORT_OK> package
variable when using the C<Exporter> module.

    __PACKAGE__->export_any(qw( $WIZ $BANG ));

Symbols can be specified as a space-delimited string, a list, or by 
reference to a list, as per L<export_all()>.

The symbols specified as arguments are imported when the module is loaded.

    use Badger::AnyModule '$BANG';          # $BANG only
    use Badger::AnyModule '$BANG @BONG';    # $BANG and @BONG
    use Badger::AnyModule qw($BANG @BONG);  # $BANG and @BONG

=head2 export_tags(%tagsets)

Define one or more sets of symbols.  This is equivalent to setting the 
C<%EXPORT_TAGS> package variable when using the C<Exporter> module.

If a symbol appears in a tag set then it is assumed to be safe to export. You
don't need to explicitly call L<export_any()> because the L<export_tags()>
method does it for you.

    __PACKAGE__->export_tags(
        set1 => [ qw( $WIZ $BANG ) ],
        set2 => [ qw( @BING %BONG ) ],
        set3 => [ qw( foo bar ) ],
    );

The values in the hash array can be specified as references to lists, or 
space-delimited strings.

    __PACKAGE__->export_tags(
        set1 => '$WIZ $BANG',
        set2 => '@BING %BONG',
        set3 => 'foo bar',
    );

To load a set of symbols, specify the tag name with a 'C<:>' prefix.

    use Badger::AnyModule ':set1';
    use Badger::AnyModule ':set1 :set2';
    use Badger::AnyModule qw(:set1 :set2);      

The special 'C<:all>' set imports all symbols.

    use Badger::AnyModule qw(:all);

The special 'C<:default>' set imports the default set of symbols.

    use Badger::AnyModule qw(:default @BONG);

You can also use the C<export_tags()> method to define a hash array
mapping aliases to symbols.

    __PACKAGE__->export_tags(
        set4 => {   
            # use hash ref to define aliases for symbols
            foo => '&the_foo_sub',
            bar => '&the_bar_sub',
        }
    );

When this tagset is imported, the symbols identified by the values 
in the hash reference (C<&the_foo_sub> and C<&the_bar_sub>) are exported 
into the caller's package as the symbols named in the corresponding keys.

    use Badger::AnyModule qw(:set4);
    
    foo();    # Badger::AnyModule::the_foo_sub()
    bar();    # Badger::AnyModule::the_bar_sub()

When defining a tagset with a hash reference, you can provide direct
references to subroutines instead of symbol names.

    __PACKAGE__->export_tags(
        set5 => {   
            # use hash ref to define aliases for subroutines
            foo => \&the_foo_sub,
            bar => \&the_bar_sub,
        }
    );

You can also explicitly specify the package name for a symbol:

    __PACKAGE__->export_tags(
        set6 => {   
            foo  => 'Badger::Example::One::foo',
            bar  => '&Badger:Example::One::bar',
            '$X' => '$Badger::Example::Two:X',
            '$Y' => '$Badger::Example::Two:Y',
        }
    );

=head2 export_hooks(%hooks)

Defines one or more handlers that are invoked when particular import
symbols are specified.

    __PACKAGE__->export_hooks(
        hello => sub {
            my ($class, $target, $symbol, $more_symbols) = @_;
            print $symbol, " ", shift(@$more_symbols), "\n";
        }
    );

This would be used like so:

    use Badger::AnyModule hello => 'world', qw( $WIZ $BANG );

The handler is passed four arguments. The first is the package name of the
exporting class (e.g. C<Badger::AnyModule>). The second argument is the
package name of the target class which wants to import the symbol (e.g.
C<main>). The symbol itself ('C<hello>' in this case) is passed as the third
argument. The final argument is a reference to a list of remaining symbols 
(C<['world', '$WIZ', '$BANG']>). 

This example shifts off the next symbol ('C<world>') and prints the message to
the screen (for debugging purposes only - your handler will most likely do
something more useful).  The handler may remove any number of symbols from the
C<$more_symbols> list to indicate that they have been successfully handled.
Any symbols left in the C<$more_symbols> list will continue to be imported 
as usual.

=head2 export_fail(\&handler)

This method can be used to register a subroutine to handle any export
failures. The arguments passed are as per L<export_hooks()>. The method should
return C<1> to indicate that the symbol was handled without error, or C<0> to
indicate failure which is then reported in the usual way.

    __PACKAGE__->export_fail(
        sub {
            my ($class, $target, $symbol, $more_symbols) = @_;
            if ($symbol eq 'badger') {
                print "OK, we'll let you import a badger\n";
                return 1;
            }
            else {
                print "You cannot import $symbol from $class into $target\n";
                return 0;
            }
        }
    );
    
An C<export_fail> handler may also remove symbols from the C<$more_symbols>
list to indicate that they have been handled, as per C<export_hooks()>.

=head1 INTERNAL METHODS

These methods are used internally to export symbols.

=head2 import(@symbols)

This is the method automatically called by Perl when a module is loaded via
C<use>.  It delegates to the L<export()> method.

=head2 export($package,@symbols)

This is the main method for exporting symbols.

=head2 exportables()

This methods collects and collates the values of the various package
variables that control the exporter (C<EXPORT_ALL>, C<EXPORT_ANY>, etc).
It returns a reference to an array containing:

    [\@all, \%any, \%tags, \%hooks, \@fails];

This array reference is cached in the C<EXPORTABLES> package variable for
future use.

=head2 export_symbol($package,$symbol,$coderef)

This method can be used to install a code reference as a symbol in a 
package.  

=begin Test::Pod::Coverage

This is to keep L<Test::Pod::Coverage> quiet.  You shouldn't see this when 
the POD is displayed.

=head2 EXPORT_ANY EXPORT_ALL EXPORT_TAGS EXPORT_HOOKS EXPORT_FAIL ISA

=end Test::Pod::Coverage

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
