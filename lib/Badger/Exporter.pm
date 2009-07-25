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

use Carp;
use strict;
use warnings;
use constant {
    ALL             => 'all',           # Alas, we can't pull these in from 
    NONE            => 'none',          # Badger::Constants because it's a 
    DEFAULT         => 'default',       # subclass of Badger::Exporter which
    IMPORT          => 'import',        # gives us a chicken-and-egg dependency
    IMPORTS         => 'imports',       # problem.We could pull them into 
    HOOKS           => 'hooks',         # Badger::Constants though because 
    ARRAY           => 'ARRAY',         # that's a subclass... hmmm....
    HASH            => 'HASH',      
    CODE            => 'CODE',
    EXPORT_ALL      => 'EXPORT_ALL',
    EXPORT_ANY      => 'EXPORT_ANY',
    EXPORT_TAGS     => 'EXPORT_TAGS',
    EXPORT_FAIL     => 'EXPORT_FAIL',
    EXPORT_HOOKS    => 'EXPORT_HOOKS',
    EXPORT_BEFORE   => 'EXPORT_BEFORE',
    EXPORT_AFTER    => 'EXPORT_AFTER',
    EXPORTABLES     => 'EXPORTABLES',
    ISA             => 'ISA',
    REFS            => 'refs',
    ONCE            => 'once',
    PKG             => '::',
    DELIMITER       => qr/(?:,\s*)|\s+/,  # match a comma or whitespace
    MISSING         => "Missing value for the '%s' option%s",
    BAD_HANDLER     => "Invalid export %s handler specified: %s",
    BAD_HOOK        => "Invalid export hook handler specified for the '%s' option: %s",
    WANTED          => " (%s wanted, %s specified)",
    UNDEFINED       => " (argument %s of %s is undefined)",
};

our $VERSION   = 0.01;
our $DEBUG     = 0 unless defined $DEBUG;
our $HANDLERS  = {
    all     => \&export_all,
    any     => \&export_any,
    tags    => \&export_tags,
    hooks   => \&export_hooks,
    fail    => \&export_fail,
    before  => \&export_before,
    after   => \&export_after,
};


#-----------------------------------------------------------------------
# export declaration methods:
#   exports( all => [...], any => [...], ...etc... )
#   export_all('foo bar baz')                 
#   export_any('foo bar baz')
#   export_before( sub { ... } )
#   export_after( sub { ... } )
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
    my $self = shift;
    my $args = @_ == 1 ? shift : [ @_ ];
    my $list = $self->export_variable( EXPORT_ALL => [ ] );
    push( @$list, ref $args eq ARRAY ? @$args : split(DELIMITER, $args) );
}

sub export_any {
    my $self = shift;
    my $args = @_ == 1 ? shift : [ @_ ];
    my $list = $self->export_variable( EXPORT_ANY => [ ] );
    push( @$list, ref $args eq ARRAY ? @$args : split(DELIMITER, $args) );
}

sub export_before {
    my $self = shift;
    my $args = @_ == 1 ? shift : [ @_ ];
    my $list = $self->export_variable( EXPORT_BEFORE => [ ] );
    push( @$list, ref $args eq ARRAY ? @$args : $args );
}

sub export_after {
    my $self = shift;
    my $args = @_ == 1 ? shift : [ @_ ];
    my $list = $self->export_variable( EXPORT_AFTER => [ ] );
    push( @$list, ref $args eq ARRAY ? @$args : $args );
}

sub export_tags {
    my $self = shift;
    my $args = (@_ == 1) && (ref $_[0] eq HASH) ? shift : { @_ };
    my $tags = $self->export_variable( EXPORT_TAGS => { } );

    # add new tags into $EXPORT_TAGS hash ref
    @$tags{ keys %$args } = values %$args;

    # all symbols referenced in tagsets (except other tag sets) must be 
    # flagged as exportable
    $self->export_any(
        grep {
            # ignore references to code or other tag sets
            not (ref || /^(:|=)/);
        }
        map {
            # symbols in tagset can be a list ref, hash ref or string
            ref $_ eq ARRAY ? @$_ :
            ref $_ eq HASH  ? %$_ :
            split DELIMITER
        } 
        values %$args
    );
    
    return $tags;
}

sub export_hooks {
    my $self  = shift;
    my $args  = (@_ == 1) && (ref $_[0] eq HASH) ? shift : { @_ };
    my $hooks = $self->export_variable( EXPORT_HOOKS => { } );
    @$hooks{ keys %$args } = values %$args;
    return $hooks;
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
    my ($all, $any, $tags, $hooks, $fails, $before, $after) 
                  = $class->exportables;
    my $can_hook  = (%$hooks ? 1 : 0);
    my $added_all = 0;
    my $count     = 0;
    my ($symbol, $symbols, $source, $hook, $pkg, $nargs, 
        %done, @args, @errors);

    no strict   REFS;
    no warnings ONCE;

    # imports can be a single whitespace delimited string of symbols
    $imports = [ split(DELIMITER, $imports) ]
        unless ref $imports eq ARRAY;
    
    # default to export_all if list of exports not specified
    # TODO: what about: use Badger::Example qw();    ?  perhaps we should
    # return unless @_ up above?
    @$imports = @$all unless @$imports;
    
    foreach $hook (@$before) {
        $hook->($class, $target, $imports);
    }

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
            # a hook can be specified as [$code,$nargs] in which case we 
            # generate a closure around the $code which shifts $nargs off
            # the symbols list and passes them as arguments to $code
            $hook = $hooks->{ $symbol } = $class->export_hook_generator($symbol, $hook)
                unless ref $hook eq CODE;

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
            $source = $pkg.PKG.$source unless $source =~ /::/ or $type eq '=';
           _debug("exporting $type$symbol from $source into $target\n") if $DEBUG;
            *{ $target.PKG.$symbol } =
                $type eq '&' ?    \&{$source} :
                $type eq '$' ?    \${$source} :
                $type eq '@' ?    \@{$source} :
                $type eq '%' ?    \%{$source} :
                $type eq '*' ?     *{$source} :
                $type eq '=' ? sub(){$source} :
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

    foreach $hook (@$after) {
        $hook->($class, $target);
    }

    return 1;
}

sub exportables {
    my $class = shift;
    no strict REFS;
    my $cache = ${ $class.PKG.EXPORTABLES } ||= do {
        my ($pkg, $symbols, %done, @all, %any, %tags, %hooks, @fails, @before, @after);
        my @pending = ($class);
        no strict REFS;

        # walk up inheritance tree collecting values from the @$EXPORT_ALL, 
        # @$EXPORT_ANY, %$EXPORT_TAGS, %$EXPORT_HOOKS and $EXPORT_FAIL pkg 
        # variables, then cache them in $EXPORT_CACHE for subsequent use

        while ($pkg = shift @pending) {
            next if $done{ $pkg }++;

            # TODO: we could optimise here by looking for a previously 
            # computed EXPORTABLES in the base class and merging it in...

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
                $symbols = [ split(DELIMITER, $symbols) ]
                    unless ref $symbols eq ARRAY;
                $any{ $_ } ||= $pkg
                    for @$symbols;
            }

            # $EXPORT_ALL is merged into @all and all symbols are mapped 
            # to their packages in %any
            if ($symbols = ${ $pkg.PKG.EXPORT_ALL }) {
                $symbols = [ split(DELIMITER, $symbols) ]
                    unless ref $symbols eq ARRAY;
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
            # (by a more specific subclass) either as hooks or any/all items
            if ($symbols = ${ $pkg.PKG.EXPORT_HOOKS }) {
                $any{ $_ } or $hooks{ $_ } ||= $symbols->{ $_ } 
                    for keys %$symbols;
            }
            
            # $EXPORT_FAIL has only one value per package, but we can have
            # several packages in the class ancestry
            if ($symbols = ${ $pkg.PKG.EXPORT_FAIL }) {
                push(@fails, $symbols);
            }

            # $EXPORT_BEFORE and $EXPORT_AFTER are references to CODE or 
            # ARRAY refs (of CODE refs, we assume).  As we travel up from
            # subclass to superclass, we unshift() the handlers onto the 
            # start of the @before/@after arrays.  This ensures that the base 
            # class handlers get called before subclass handlers.
            if ($symbols = ${ $pkg.PKG.EXPORT_BEFORE }) {
                unshift(
                    @before, 
                    ref $symbols eq CODE  ?  $symbols :
                    ref $symbols eq ARRAY ? @$symbols :
                    croak sprintf(BAD_HANDLER, before => $symbols)
                );
            }

            if ($symbols = ${ $pkg.PKG.EXPORT_AFTER }) {
                unshift(
                    @after, 
                    ref $symbols eq CODE  ?  $symbols :
                    ref $symbols eq ARRAY ? @$symbols :
                    croak sprintf(BAD_HANDLER, after => $symbols)
                );
            }

            # This is the same depth-first inheritance resolution algorithm
            # that Perl uses.  We can't use the fancy heritage() method in 
            # Badger::Class because of the Chicken-and-Egg dependency problem
            # between Badger::Exporter and Badger::Class
            push(@pending, @{$pkg.PKG.ISA});
        }
        
        [\@all, \%any, \%tags, \%hooks, \@fails, \@before, \@after];
    };
    
    return wantarray
        ? @$cache
        :  $cache;
}

sub export_symbol {
    my ($self, $target, $symbol, $ref) = @_;
    no strict   REFS;
    no warnings ONCE;
    *{ $target.PKG.$symbol } = $ref;
}

sub export_variable {
    my ($self, $name, $default) = @_;
    my $class = ref $self || $self;
    my $var   = $class.PKG.$name;
    my $item;
    no strict REFS;

    unless (defined ($item = ${$var})) {
        # install the default value ref into the SCALAR $EXPORT_XXXX var
        ${$var} = $item = $default;
        # then poke the symbol table to make Perl notice it's defined
        *{$var} = \${$var};
    }
    
    return $item;
}

sub export_hook_generator {
    my $self = shift;
    my $name = shift;
    my $hook = @_ == 1 ? shift : [ @_ ];
    
    # do nothing if we've already got a code ref that doesn't require args
    return $hook 
        if ref $hook eq CODE;
    
    # anything else must be a list ref containing [$code_ref, $n_args]
    croak sprintf(BAD_HOOK, $name, $hook) 
        unless ref $hook eq ARRAY;

    my ($code, $nargs) = @$hook;

    # user is trying to confuse us with [$non_code_ref, ...]
    croak sprintf(BAD_HOOK, $name, $code) 
        unless ref $code eq CODE;

    # [$code, 0] or [$code] is fine as just $code, also reject $nargs < 0
    return $code
        unless $nargs && $nargs > 0;

    # OK it's safe to proceed
    return sub {
        my ($this, $target, $symbol, $symbols) = @_;
        my $n = 1;
        # check we've got enough arguments
        croak sprintf(MISSING, $symbol, sprintf(WANTED, $nargs, scalar @$symbols)) 
            if @$symbols < $nargs;
        
        # call the code ref with the first $nargs arguments, making sure
        # they all have defined values
        $code->(
            $this, $target, $symbol,
            ( map {
                croak sprintf(MISSING, $symbol, sprintf(UNDEFINED, $n, $nargs)) 
                    unless defined $_;
                $n++; 
                $_
              } 
              splice(@$symbols, 0, $nargs)
            ),
            $symbols,
        );
    }
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
        before => sub {                 # pre-import hook
            my ($class, $target, $symbols) = @_;
            print "This gets run before the import\n"
        },
        after => sub {                 # post-import hook
            my ($class, $target) = @_;
            print "This gets run after the import\n"
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
    
    # define generic hooks to run before/after import
    __PACKAGE__->export_before(
        sub {
            my ($class, $target, $symbols) = @_;
            print "This gets run before the import\n"
        }
    );
    __PACKAGE__->export_after(
        sub {
            my ($class, $target) = @_;
            print "This gets run after the import\n"
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

    use Badger::AnyModule ':all';

The special 'C<:default>' set imports the default set of symbols.

    use Badger::AnyModule ':default @BONG';

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

    use Badger::AnyModule ':set4';
    
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

The C<Badger::Exporter> module also recognises the C<=> pseudo-sigil
which can be used to define constant values.

    __PACKAGE__->export_tags(
        set7 => {   
            e   => '=2.718',
            pi  => '=3.142',
            phi => '=1.618',
        }
    );

When this tag set is imported, C<Badger::Exporter> will define constant
subroutines to represent the imported values.

    use Badger::AnyModule ':set7';
    
    print e;            # 2.718
    print pi;           # 3.142
    print phi;          # 1.618

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

You can also define export hooks as an array reference. The code reference
should be the first item in the array. The second item is the number of
arguments it expects. These will be shifted off the C<$more_symbols> list
(automatically raising an error if one or more values are missing or
undefined) and passed as separate arguments to your handler. The
C<$more_symbols> reference will be passed as the final argument.

    __PACKAGE__->export_hooks(
        example => [ \&my_export_hook, 2 ],
    );
    
    sub my_export_hook {
        my ($self, $target, $symbol, $arg1, $arg2, $more_symbols) = @_;
        # your code...
    }

Hooks expressed this way will have closures created around them on demand
by the L<export_hook_generator()> method.  Don't worry if that doesn't
mean anything much to you.  It simply means that we can delay doing any
extra preparation work until we're sure that it's going to be used.

=head2 export_before(\&handler)

This method can be called to register a handler that will be called 
immediately before the exporter starts importing symbols.  The 
handler is passed three arguments: the exporter class, the target class,
and a reference to a list of symbols that are being imported.  The handler
can modify the list of symbols to change what does or doesn't get imported.

    __PACKAGE__->export_before(
        sub {
            my ($class, $target, $symbols) = @_;
            print "About to import symbols: ", join(', ', @$symbols), "\n";
        }
    );

Multiple handlers can be defined, either in the same class or inherited from
base classes.  Handlers defined in base classes are called before those in 
derived classes.  Multiple handlers defined in the same class will be called
in the order that they were defined in.

=head2 export_after(\&handler)

This method can be called to register a handler that will be called 
immediately after the exporter has finished importing symbols.  The 
handler is passed two arguments: the exporter class and target class.

    __PACKAGE__->export_after(
        sub {
            my ($class, $target) = @_;
            print "Finished exporting\n";
        }
    );

Multiple handlers can be defined, as per L<export_before()>.

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

    Badger::Exporter->export_symbol('My::Package', 'Foo', \&foosub);

=head2 export_hook_generator($name,\&code,$nargs)

This method is used to generate a closure (a fancy way of saying "wrapper
subroutine") around an existing export hook subroutine.  Bare naked export
hooks are typically written like this:

    sub code {
        my ($self, $target, $symbol, $more_symbols) = @_
        # your code...
    }

Your code is responsible for shifting any arguments it expects off the front
of the C<$more_symbols> list. It I<should> also being doing all the messy
stuff like making sure the C<$more_symbols> list contains enough arguments and
that they're all set to defined values.  But I bet you forget sometimes, 
don't you?  That's OK, it's easily done.

The purpose of the C<export_hook_generator()> method is to simplify argument 
processing so that hooks can be specified as:

    [\&my_code, $nargs]

and written as:

    sub code {
        my (
            $self, $target, $symbol,    # the usual first three items
            $arg1, $arg2, ..., $argn,   # your $nargs items
            $more_symbols               # the remaining items
        ) = @_
    }

The method should be called like something like this:

    my $hook = Badger::Exporter->export_hook_generator(
        'wibble', \&code, 2
    );

The first argument should be the name of the option that the hook is being
generated for.  This is used to report any argument errors, e.g.

    Missing value for the 'wibble' option (2 wanted, 1 available)

Or:

    Missing value for the 'wibble' option (argument 2 of 2 is undefined)

The second argument is a reference to your handler subroutine.  The third
argument is the number of additional arguments your subroutine expects.

=head1 PACKAGE VARIABLES

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2009 Andy Wardley.  All Rights Reserved.

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

