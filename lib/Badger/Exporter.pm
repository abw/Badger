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
    ALL     => 'all',           # Alas, we can't pull these in from 
    NONE    => 'none',          # Badger::Constants because it's a 
    DEFAULT => 'default',       # subclass of Badger::Exporter which
    IMPORT  => 'import',        # gives us a chicken-and-egg dependency
    IMPORTS => 'imports',       # problem.
    HOOKS   => 'hooks',         
    ARRAY   => 'ARRAY',         
    HASH    => 'HASH',      
    CODE    => 'CODE',
};

our $VERSION   = 0.01;
our $DEBUG     = 0 unless defined $DEBUG;
our $DELIMITER = qr/(?:,\s*)|\s+/;
our $HANDLERS  = {
    all   => \&export_all,
    any   => \&export_any,
    tags  => \&export_tags,
    hooks => \&export_hooks,
    fail  => \&export_fail,
};
    

#------------------------------------------------------------------------
# exports(%exports)
#
# Maps keys in \%exports to $HANDLERS and calls them, passing the 
# corresponding value as an argument.  e.g.
#   __PACKAGE__->exports( all => '$foo $bar', any => '$wam $bam' )
#------------------------------------------------------------------------

sub exports {
    my $self = shift;
    my $data = @_ == 1 && ref $_[0] eq HASH ? shift : { @_ };
    my $handler;
    while (my ($key, $value) = each %$data) {
        $handler = $HANDLERS->{ $key } 
            || croak "Invalid exports key: $key\n";
        $handler->($self, $value);
    }
}


#------------------------------------------------------------------------
# export_all(@symbols)
#
# Pushes all arguments onto @$EXPORT_ALL for forced exporting.
#------------------------------------------------------------------------

sub export_all {
    my $self  = shift;
    my $class = ref $self || $self;
    my $tags  = @_ == 1 ? shift : [ @_ ];
    $tags = [ split($DELIMITER, $tags) ] unless ref $tags eq ARRAY;
    no strict 'refs';
    my $export_all = ${"${class}::EXPORT_ALL"} ||= [ ];
    push(@$export_all, @$tags);
}


#------------------------------------------------------------------------
# export_any( @symbols )
#
# Pushes all arguments onto @$EXPORT_ANY for optional exporting.
#------------------------------------------------------------------------

sub export_any {
    my $self  = shift;
    my $class = ref $self || $self;
    my $tags  = @_ == 1 ? shift : [ @_ ];
    $tags = [ split($DELIMITER, $tags) ] unless ref $tags eq ARRAY;
    no strict 'refs';
    my $export_any = ${"${class}::EXPORT_ANY"} ||= [ ];
    push(@$export_any, @$tags);
}


#------------------------------------------------------------------------
# export_tags( tagname1 => [ @symbols1 ], tagname2 => [ @symbols2 ] )
#
# Adds all arguments to %$EXPORT_TAGS for exporting as named sets.
#------------------------------------------------------------------------

sub export_tags {
    my $self  = shift;
    my $class = ref $self || $self;
    my $tags  = (@_ == 1) && (ref $_[0] eq HASH) ? shift : { @_ };
    my @syms  = map { 
        ref $_ eq ARRAY ? @$_ :
        ref $_ eq HASH  ? %$_ :
        split $DELIMITER
    } values %$tags;

#    print STDERR __PACKAGE__, ' ', __LINE__, "  export_tags($class, ", join(', ', @syms), ")\n";
    
    no strict 'refs';

    # add new tags into $EXPORT_TAGS hash
    my $export_tags = ${"${class}::EXPORT_TAGS"} ||= { };
    @$export_tags{ keys %$tags } = values %$tags;

    # also add any symbols (except those that reference other tagsets)
    # to $EXPORT_ANY list
    $self->export_any(grep(! /^:/, @syms));
    
    return $export_tags;
}


#------------------------------------------------------------------------
# export_hooks( foo => \&handler, bar => \&handler )
#
# Define a set of handlers to catch arguments specified when the module
# is loaded via use.  e.g. C<foo> in C<use Badger::Example foo => 'Hello'>
#------------------------------------------------------------------------

sub export_hooks {
    my $self  = shift;
    my $class = ref $self || $self;
    my $hooks = (@_ == 1) && (ref $_[0] eq HASH) ? shift : { @_ };

    no strict 'refs';
    my $table = ${"${class}::EXPORT_HOOKS"};
    if ($table) {
        @$table{ keys %$hooks } = values %$hooks;
    }
    else {
        $table = ${"${class}::EXPORT_HOOKS"} = $hooks;
    }
    return $table;
}


#------------------------------------------------------------------------
# export_fail( \&handler )
#
# Define a handler to catch any imports that aren't defined.
#------------------------------------------------------------------------

sub export_fail {
    my $self  = shift;
    my $class = ref $self || $self;
    no strict 'refs';
    return @_
        ? (${"${class}::EXPORT_FAIL"} = shift)
        :  ${"${class}::EXPORT_FAIL"};
}


#------------------------------------------------------------------------
# import(@imports)
# import(\@imports)
#
# Method called when the module is loaded with use.  Merges all @EXPORT,
# @EXPORT_OK, %EXPORT_TAGS and $EXPORT_HOOKS for all base classes, 
# ensuring that all their relevant symbols get exported too.
#------------------------------------------------------------------------

sub import {
    my $class  = shift;
    my $target = (caller())[0];
    # enable strict and warnings in the caller - this ensures that every 
    # TT module (that calls this method - which is pretty much all of them)
    # has strict/warnings enabled, without having to explicitly write it
    strict->import;
    warnings->import;
    $class->export($target, @_);
}


#-----------------------------------------------------------------------
# export(@imports)
#
# Class method to export the symbols to the caller.  This is where all
# the heavy lifting happens.
#-----------------------------------------------------------------------

sub export {
    my $class   = shift;
    my $target  = shift;
    my $imports = (@_ == 1) && ref $_[0] eq ARRAY ? shift : [ @_ ];
    my (@export_all, @export_any, %symbol_pkg, %export_tags, %export_hooks, @export_fail);
    my ($pkg, $symbols, $symbol, $hook, %done, $next);
    my @pending = ($class);
    my @errors;

#    local $DEBUG = 1;
    no strict 'refs';

    # walk up the inheritance tree collecting values from the
    # @$EXPORT_ALL, @$EXPORT_ANY, %$EXPORT_TAGS and %$EXPORT_HOOKS
    # package variables

    # TODO: cache this in the package the first time it is collected?

    while ($pkg = shift @pending) {
        next if $done{ $pkg }++;

        # iterate through any symbols in @$EXPORT_ALL adding
        # the symbol and relevant package (for any we haven't
        # already seen) to a lookup table
        if ($symbols = ${$pkg.'::EXPORT_ALL'}) {
            foreach $symbol (@$symbols) {
                push(@export_all, $symbol); 
                next if $symbol_pkg{ $symbol };
                $symbol_pkg{ $symbol } = $pkg;
            }
        }

        # now do the same for @$EXPORT_ANY
        if ($symbols = ${$pkg.'::EXPORT_ANY'}) {
            foreach $symbol (@$symbols) {
                next if $symbol_pkg{ $symbol };
                $symbol_pkg{ $symbol } = $pkg;
            }
        }

        # and %$EXPORT_TAGS
        if ($symbols = ${$pkg.'::EXPORT_TAGS'}) {
            foreach $symbol (keys %$symbols) {
                next if $export_tags{ $symbol };
                $export_tags{ $symbol } = $symbols->{ $symbol };
            }
        }

        # and %$EXPORT_HOOKS
        if ($symbols = ${$pkg.'::EXPORT_HOOKS'}) {
            foreach $symbol (keys %$symbols) {
                next if $export_hooks{ $symbol };
                $export_hooks{ $symbol } = $symbols->{ $symbol };
            }
        }

        # and $EXPORT_FAIL
        if ($symbol = ${$pkg.'::EXPORT_FAIL'}) {
            push(@export_fail, $symbol);
        }

        push(@pending, @{"$pkg\::ISA"});
    }

    # default to export_all if list of exports not specified
    @$imports = @export_all unless @$imports;

    # if any import hooks are defined then iterate through the symbols 
    # giving them a chance to be called, or look for an 'import' to 
    # indicate the rest of the symbols are for regular import.
    my $can_hook = (%export_hooks ? 1 : 0);
    my $symbols_done = 0;
    my $added_all = 0;
    my $coderef;
    %done = ();

    SYMBOL: while (@$imports) {
        next unless ($symbol = shift @$imports);
        next if $done{ $symbol }++;   #  && ! $export_hooks{ $symbol };   # hooks can repeat
        
        # look for :tagset symbols and expand their contents onto @$imports
        if ($symbol =~ s/^://) {
            if ($symbols = $export_tags{ $symbol }) {
                if (ref $symbols eq ARRAY) {
                    # expand list of symbols onto @$imports list
                    unshift(@$imports, @$symbols);
                }
                elsif (ref $symbols eq HASH) {
                    # map hash of into [name => $symbol] pairs
                    unshift(@$imports, map { [$_ => $symbols->{ $_ }] } keys %$symbols);
                }
                else {
                    # string of space-delimited symbols
                    unshift(@$imports, split($DELIMITER, $symbols));
                }
            }
            elsif ($symbol eq DEFAULT) {
                unshift(@$imports, @export_all);
            }
            elsif ($symbol eq ALL) {
                unshift(@$imports, keys %symbol_pkg);
                $added_all = 1;
            }
            else {
                push(@errors, "Invalid import tag: $symbol\n");
            }
            next SYMBOL;
        }

        my $export_sym;

        if (ref $symbol eq ARRAY) {
            # a pair of [name, $symbol] expanded from a :hash set 
            ($symbol, $export_sym) = @$symbol;
        }
        elsif ($can_hook && ($hook = $export_hooks{ $symbol })) {
            # fire off handler hooked to this import item
            $done{ $symbol }--;     # hooks can be repeated so pretend we haven't done it
            &$hook($class, $target, $symbol, $imports);
            next SYMBOL;
        }
        elsif ($symbol eq IMPORTS) {
            # special 'imports' hook disables any more hooks causing
            # all remaining arguments to be imported as symbols
            $can_hook = 0;
            next SYMBOL;
        }
        elsif ($symbol eq IMPORT) {
            # 'import' hook accepts the next item as an import 
            # list/string and unpacks it onto the front of the imports
            # list.  We disabled hooks for the duration of the import
            # and add a HOOKS token at the end to re-enable hooks
            $can_hook = 0;
            if ($next = shift @$imports) {
                $next = [ split($DELIMITER, $next) ] 
                    unless ref $next eq 'ARRAY';
                unshift(@$imports, @$next, HOOKS);
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
            $export_sym = $symbol;
        }
        
        # check we're allowed to export the symbol requested
        if ($pkg = $symbol_pkg{ $symbol }) {
            print STDERR "exporting $symbol from $pkg to $target\n" if $DEBUG;
        }
        else {
            # TODO: if $can_hook?
            foreach $hook (@export_fail) {
                if (&$hook($class, $target, $symbol, $imports)) {
                    $done{ $symbol }--;     # hooks can be repeated so pretend we haven't done it
                    next SYMBOL;
                }
            }
            push(@errors, "$symbol is not exported by $class\n");
            next SYMBOL;
        }

        if (ref $export_sym eq CODE) {
            # patch directly into the code ref
            *{"${target}::${symbol}"} = $export_sym;
        }
        else {
            my $type = "&";
            $symbol     =~ s/^(\W)//;
            $export_sym =~ s/^(\W)// and $type = $1;
            $export_sym = "${pkg}::${export_sym}";
            *{"${target}::${symbol}"} =
                $type eq '&' ? \&{$export_sym} :
                $type eq '$' ? \${$export_sym} :
                $type eq '@' ? \@{$export_sym} :
                $type eq '%' ? \%{$export_sym} :
                $type eq '*' ?  *{$export_sym} :
                do { push(@errors, "Can't export symbol: $type$symbol\n"); next; };
        }
        $symbols_done++;
    }
    continue {
        # if we're on the last item and we've only processed hooks
        # (i.e. no real symbols were specified then we export the 
        # default set of symbols instead
        unless (@$imports or $symbols_done or $added_all) {
            unshift(@$imports, @export_all);
            $added_all = 1;
        }
    }

    if (@errors) {
        require Carp;
        Carp::croak("@{errors}Can't continue after import errors");
    }

    return 1;
}

sub export_coderef {
    my ($self, $target, $symbol, $coderef) = @_;
    no strict 'refs';
    no warnings;
    *{"${target}::$symbol"} = $coderef;
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
    
    # imports option disables any hooks
    use Badger::AnyModule 
        hello   => 'world'
        imports => qw( @BING %BONG );  

    # import (singular) option unpacks strings and disables hooks
    use Badger::AnyModule 
        import => '@BING %BONG';  

=head1 DESCRIPTION

TODO: this module was originally written for the Template Toolkit v3. It's
currently a cut-n-paste job with the names change. The docs may be incomplete
or slightly inaccurate until I get a chance to sweep it.

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
    use Badger::AnyModule qw($BANG @BONG);  # $BANG and @BONG

Specify an empty list of arguments if you don't want any symbols 
imported.

    use Badger::AnyModule qw();             # imports nothing

Note that you B<cannot> specify a string of symbols when importing a 
module:

    use Badger::AnyModule '$BANG @BONG';    # DOES NOT WORK!!!

We may support this at some point in the future, but not now.

=head2 export_any(@symbols)

Adds all the symbols passed as arguments to the list of items that are
exported on request. This is equivalent to setting the C<@EXPORT_OK> package
variable when using the C<Exporter> module.

    __PACKAGE__->export_any(qw( $WIZ $BANG ));

Symbols can be specified as a space-delimited string, a list, or by 
reference to a list, as per L<export_all()>.

The symbols specified as arguments are imported when the module is loaded.

    use Badger::AnyModule '$BANG';          # $BANG only
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
        set4 => {   
            # use hash ref to define aliases for subroutines
            foo => \&the_foo_sub,
            bar => \&the_bar_sub,
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

This method can be used to register a subroutine to handle any export failures.
The arguments passed are as per L<export_hooks()>.  The method should return C<1>
to indicate that the symbol was handled without error, or C<0> to indicate failure
which is then reported in the usual way.

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
