#========================================================================
#
# Badger::Class
#
# DESCRIPTION
#   Module implementing metaclass functionality for composing classes
#   (equivalent to C<use base>) and other class-related actions.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Class;

use strict;
use warnings;
use base 'Badger::Exporter';
use Badger::Constants 'DELIMITER ARRAY HASH CODE PKG REFS ONCE';
use Badger::Utils 'load_module';
use Carp;
use constant {
    CONSTANTS => 'Badger::Constants',
    EXPORTER  => 'Badger::Exporter',
    CODECS    => 'Badger::Codecs',
    UTILS     => 'Badger::Utils',
    LOADED    => 'BADGER_LOADED',
    MESSAGES  => 'MESSAGES',
    VERSION   => 'VERSION',
    THROWS    => 'THROWS',
    DEBUG     => 'DEBUG',
    ISA       => 'ISA',
};
use overload 
    '""' => 'name',
    fallback => 1;

our $VERSION    = 0.01;
our $DEBUG      = 0 unless defined $DEBUG;
our $LOADED     = { }; 
our @HOOKS      = qw( 
    base version debug constant constants words exports throws messages 
    utils codec codecs methods get_methods set_methods
);


#-----------------------------------------------------------------------
# Define a lexical scope to enclose class lookup table
#-----------------------------------------------------------------------

{
    # lookup table mapping package names to Badger::Class objects
    my $CLASSES = { };

    # class/package name
    sub CLASS {
        shift || (caller())[0];
    }
    
    # fetch/create a Badger::Class object for a package name
    sub class {
        my $class = @_ ? shift : (caller())[0];
        my $bless = shift || __PACKAGE__;       # allow for subclassing
        $class = ref $class || $class;
        return $CLASSES->{ $class } || $bless->new($class);
    }

    # return a list of Badger::Class objects for each class in the
    # inheritance chain, starting with the object itself, followed by
    # each base class, their base classes, and so on.  The order of
    # base classes is determined by the heritage() method which implements
    # a simplified version of the C3 method resolution algorithm.
    sub classes {
        my $class = shift || (caller())[0];
        class($class)->heritage;
    }

}


#-----------------------------------------------------------------------
# Define exportable items and export hook (see Badger::Exporter)
#-----------------------------------------------------------------------

# any of these can be exported on demand (like @EXPORT_OK)    
CLASS->export_any('CLASS', 'class', 'classes');

# define custom hooks for load options
CLASS->export_hooks({
    map { $_ => \&export_hook } 
    @HOOKS
});

sub export_hook {
    my ($class, $target, $key, $symbols, $import) = @_;
    croak "You didn't specify a value for the '$key' load option."
        unless @$symbols;
    # make sure we forward the $class to class() so this module can 
    # be subclassed (e.g. Badger::Web::Class)
    class($target, $class)->$key(shift @$symbols);
}
    
sub export {
    my ($class, $package, @args) = @_;
    no strict   REFS;
    no warnings ONCE;
    ${$package.PKG.LOADED} ||= 1;
    $class->SUPER::export($package, @args);
}


#-----------------------------------------------------------------------
# constructor method
#-----------------------------------------------------------------------

sub new {
    my ($class, $package) = @_;
    $package = ref $package || $package;
    no strict 'refs';
    bless { 
        name    => $package,
        symbols => \%{"${package}::"},
    }, $class;
}


#-----------------------------------------------------------------------
# methods to access symbol table 
#-----------------------------------------------------------------------

sub name       {    $_[0]->{ name    } }
sub symbols    {    $_[0]->{ symbols } }
sub symbol     {    $_[0]->{ symbols }->{ $_[1] } }
sub scalar_ref { *{ $_[0]->{ symbols }->{ $_[1] } || return }{ SCALAR } }
sub array_ref  { *{ $_[0]->{ symbols }->{ $_[1] } || return }{ ARRAY  } }
sub hash_ref   { *{ $_[0]->{ symbols }->{ $_[1] } || return }{ HASH   } }
sub code_ref   { *{ $_[0]->{ symbols }->{ $_[1] } || return }{ CODE   } }
sub glob_ref   { *{ $_[0]->{ symbols }->{ $_[1] } || return }{ GLOB   } }
sub scalar     { ${ scalar_ref(@_) || return } }
sub array      { @{ array_ref(@_)  || return } }
sub hash       { %{ hash_ref(@_)   || return } }


#-----------------------------------------------------------------------
# methods for accessing class variables that DTRT in subclasses
#-----------------------------------------------------------------------

sub var {
    my $self = shift;
    my $name = shift;
    no strict   REFS;
    no warnings ONCE;

#    _debug("Looking for $self->{ name }", PKG, $name, "  args: ", scalar(@_), " => ", join(', ', @_), "\n");
    return @_
        ? (${ $self->{name}.PKG.$name } = shift)
        :  ${ $self->{name}.PKG.$name };
}

sub var_default {
    my ($self, $name, $default) = @_;
    no strict   REFS;
    no warnings ONCE;

    return ${ $self->{name}.PKG.$name } 
        ||= $default;
}

sub any_var {
    my $self = shift;
    my $name = shift;
    my $pkg = $self->{ name };
    no strict REFS;

    foreach my $pkg ($self->heritage) {
        _debug("looking for $name in $pkg\n") if $DEBUG;
        return ${ $pkg.PKG.$name } if defined ${ $pkg.PKG.$name };
    }

    return undef;
}

sub all_vars {
    my ($self, $name) = @_;
    my $pkg  = $self->{ name };
    my ($value, @values);
    no strict   REFS;
    no warnings ONCE;

    foreach my $pkg ($self->heritage) {
        _debug("looking for $name in $pkg\n") if $DEBUG;
        push(@values, $value)
            if defined ($value = ${ $pkg.PKG.$name });
        _debug("got: $value\n") if $DEBUG && $value;
    }
    
    return wantarray ? @values : \@values;
}

sub list_vars {
    my $self = shift;               # must remove these from @_ here
    my $name = shift;
    my $vars = $self->all_vars($name);
    my (@merged, $list);
    
    foreach $list (@_, @$vars) {    # use whatever is left in @_ here
        next unless defined $list;
        if (ref $list eq ARRAY) {
            next unless @$list;
            push(@merged, @$list);
        }
        else {
            push(@merged, $list);
        }
    }

#    return \@merged;

    # NOTE TO SELF: this causes problems when doing something like 
    # foo( something_that_calls_list_vars() ) because list_vars assumed 
    # list context when we actually want a scalar ref.  Must find where 
    # this is and fix it.
    return wantarray ? @merged : \@merged;

}

sub hash_vars {
    my $self = shift;               # must remove these from @_ here
    my $name = shift;
    my $vars = $self->all_vars($name);
    my (%merged, $hash);

    # reverse the package vars so we get base classes first, followed by subclass,
    # then we add any additional arguments on as well in the order specified
    foreach $hash ( reverse(@$vars), @_ ) { 
        next unless defined $hash;
        unless (ref $hash eq HASH) {
            warn "Ignoring $name configuration option (not a hash ref): $hash\n";
            next;
        }
        @merged{ keys %$hash } = values %$hash;
    }
    
    return \%merged;
}

sub hash_value {
    my ($self, $name, $item, $default) = @_;

    foreach my $hash ($self->all_vars($name)) {
        next unless ref $hash eq HASH;
        return $hash->{ $item }
            if defined $hash->{ $item };
    }

    return $default;
}


#-----------------------------------------------------------------------
# Methods to return immediate parent classes and all ancestor classes.
#-----------------------------------------------------------------------

sub parents {
    my $self    = shift;
    my $pkg     = $self->{ name };
    my $parents = $self->{ parents } ||= do {
        no strict REFS;

        # make sure the module is loaded before we go looking at its @ISA
        _autoload($pkg);
        [ 
            map { class($_) }               # parents are immediate 
            @{ $pkg.PKG.ISA }               # superclasses defined in @ISA
        ];
    };
    
    return wantarray
        ? @$parents
        :  $parents;
}

sub heritage {
    my $self     = shift;
    my $heritage = $self->{ heritage } ||= do {    
        my @pending = ($self);
        my (%seen, $item, @order);
        while (@pending) {
            next unless defined ($item = pop @pending);
            unshift(@order, $item);
            push(@pending, reverse @{ $item->parents });
        }
        [ reverse grep { ! $seen{$_}++ } @order ];
    };
    return wantarray
        ? @$heritage
        :  $heritage;
}


#-----------------------------------------------------------------------
# class configuration methods - also available as import hooks
#-----------------------------------------------------------------------

sub base {
    my ($self, $bases) = @_;
    my $pkg = $self->{ name };
    $bases = [ $bases ] unless ref $bases eq 'ARRAY';
    $bases = [ map { split DELIMITER } @$bases ];
    my @load;
    
    # add each of $bases to @ISA and autoload it
    while (my $base = shift @$bases) {
        no strict REFS;
        next if $pkg->isa($base);
        _debug("Adding $pkg base class $base\n") if $DEBUG;
        push @{ $pkg.PKG.ISA }, $base;
        _autoload($base);
    }
}

sub version {
    my ($self, $version) = @_;
    my $pkg = $self->{ name };
    no strict 'refs';
    _debug("Defining $pkg version $version\n") if $DEBUG;

    # define $VERSION and version()
    *{ $pkg.PKG.VERSION } = \$version
        unless defined ${ $pkg.PKG.VERSION }
                    && ${ $pkg.PKG.VERSION };
    *{ $pkg.PKG.'version'} = sub() { $version }
        unless defined *{ $pkg.PKG.'version' };
}

sub debug {
    my ($self, $debug) = @_;
    my $pkg = $self->{ name };
    no strict REFS;

    # define a new debugging() method in the target class (if one doesn't
    # already exist) which calls the debugging() method on it's class object
    unless (defined *{ $pkg.PKG.'debugging' }) {
        _debug("Defining $pkg debugging() method\n") if $DEBUG;
        *{ $pkg.PKG.'debugging' } = sub { 
            class(shift)->debugging(@_) 
        };
    }

    # On this one occasion, we won't force the $DEBUG value to be set
    # to $debug if it's already been pre-defined to a value.  This 
    # emulates the idiom: our $DEBUG = $debug unless defined $DEBUG;
    # so that we can set $DEBUG flags *before* loading a module (which
    # might happen on demand)
    unless (defined ${ $pkg.PKG.DEBUG }) {
        _debug("debug() Setting $pkg \$DEBUG to $debug\n") if $DEBUG;
        *{ $pkg.PKG.DEBUG } = \$debug
    }
}

sub debugging {
    my $self = shift;
    my $pkg = $self->{ name };
    no strict REFS;

    # return current $DEBUG value when called without args
    return ${ $pkg.PKG.DEBUG } || 0
        unless @_;
    
    # set new debug value when called with an argument
    my $debug = shift;
    $debug = 0 if $debug =~ /^off$/i;

    # TODO: consider setting different parts of the flag, like TT2, 

    _debug("debugging() Setting $pkg debug to $debug\n") if $DEBUG;
    
    if (defined ${ $pkg.PKG.DEBUG }) {
        # update existing variable
        ${ $pkg.PKG.DEBUG } = $debug;
    }
    else {
        # define new variable, poking it into the symbol table using
        # *{...} rather than ${...} so that it's visible at compile time,
        # thus preventing any "Variable $DEBUG not defined errors
        *{ $pkg.PKG.DEBUG } = \$debug;
    }
    return $debug;
}

sub constants {
    my $self = shift;
    my $constants = @_ == 1 ? shift : { @_ };
    $constants = [ split(DELIMITER, $constants) ] 
        unless ref $constants eq ARRAY;
    CONSTANTS->export($self->{ name }, @$constants);
}

sub constant {
    my $self = shift;
    my $constants = @_ == 1 ? shift : { @_ };
    my $pkg = $self->{ name };

    # split string into pairs of assignments, e.g. "foo=bar, baz=bam"
    $constants = {
        map { split /\s*=>?\s*/ }
        split(DELIMITER, $constants)
    } unless ref $constants eq HASH;
    
    
    while (my ($name, $value) = each %$constants) {
        no strict REFS;
        my $v = $value;     # new lexical variable to bind in closure
        _debug("Defining $pkg constant $name => $value\n") if $DEBUG;
        *{ $pkg.PKG.$name } = sub() { $value };
    }
}

sub words {
    my $self  = shift;
    my $words = @_ == 1 ? shift : [ @_ ];
    my $pkg   = $self->{ name };

    $words = [ split(DELIMITER, $words) ] 
        unless ref $words eq ARRAY;
        
    foreach (@$words) {
        no strict REFS;
        my $word = $_;  # new lexical variable to bind in closure
        _debug("Defining $pkg word $word\n") if $DEBUG;
        *{ $pkg.PKG.$word } = sub() { $word };
    }
}
    
sub exports {
    my $self = shift;
    my $pkg  = $self->{ name };
    $self->base(EXPORTER);
    $pkg->exports(@_);
}

sub throws {
    my ($self, $throws) = @_;
    no strict   REFS;
    no warnings ONCE;
    _debug("defining $self THROWS $throws\n") if $DEBUG;
    *{ $self->{name}.PKG.THROWS } = \$throws;
}

sub messages {
    my $self = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $pkg = $self->{ name };
    no strict   REFS;
    no warnings ONCE;
    
    # if there aren't any existing $MESSAGES then we can store
    # $messages in it and be done, otherwise we have to merge.
    my $messages = ${ $pkg.PKG.MESSAGES };
    
    if ($messages) {
        _debug("merging $pkg messages: ", join(', ', keys %$args), "\n") if $DEBUG;
        @$messages{ keys %$args } = values %$args;
    }
    else {
        _debug("adding $pkg messages: ", join(', ', keys %$args), "\n") if $DEBUG;
        ${ $pkg.PKG.MESSAGES } = $messages = $args;
    }
    return $messages;
}

sub utils {
    my $self = shift;
    my $syms = @_ == 1 ? shift : { @_ };
    my $pkg  = $self->{ name };
    $syms = [ split(DELIMITER, $syms) ] 
        unless ref $syms eq ARRAY;

    # call UTILS as a class method so that subclasses of Badger::Class
    # (like Badger::Web::Class) can define their own UTILS to replace
    # the default set (like Badger::Web::Utils).
    my $utils = $self->UTILS;

    _autoload($utils);
    
    $utils->export($self->{ name }, @$syms);
}

sub codec {
    my $self   = shift;
    my $codecs = $self->CODECS;
    _autoload($codecs);
    $codecs->export_codec($self->{ name }, shift);
}

sub codecs {
    my $self = shift;
    my $codecs = $self->CODECS;
    _autoload($codecs);
    $codecs->export_codecs($self->{ name }, shift);
}

sub method {
    my ($self, $name, $code) = @_;
    no strict REFS;
    _debug("defining method: $self\::$name => $code\n") if $DEBUG;
    *{ $self->{name}.PKG.$name } = $code;
}

sub methods {
    my $self = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    no strict REFS;

    while (my ($name, $code) = each %$args) {
        _debug("defining method: $self\::$name => $code\n") if $DEBUG;
        *{ $self->{name}.PKG.$name } 
            = ref $code eq CODE ? $code : sub { $code };
    }
}

sub get_methods {
    my ($self, $names) = @_;
    $names = [ $names ] unless ref $names eq ARRAY;
    $names = [ map { split DELIMITER } @$names ];
    no strict REFS;

    foreach (@$names) {
        my $name = $_;      # new lexically scoped var for closure
        *{ $self->{name}.PKG.$name } = sub {
            $_[0]->{ $name };
        };
    }
}

sub set_methods {
    my ($self, $names) = @_;
    $names = [ $names ] unless ref $names eq ARRAY;
    $names = [ map { split DELIMITER } @$names ];
    no strict REFS;
    
    foreach (@$names) {
        my $name = $_;
        *{ $self->{name}.PKG.$name } = sub {
            # You wouldn't ever want to write a real subroutine like this.
            # But that's OK, because we're here to do it for you.  You get
            # the efficiency without having to ever look at code like this:
            @_ == 2 
                ? ($_[0]->{ $name } = $_[1])
                :  $_[0]->{ $name };
        };
    }
}



#-----------------------------------------------------------------------
# autoload($module)
#
# Helper subroutine to autoload a module.  Could probably be merged
# with similar method(s) in T::Utils.
#-----------------------------------------------------------------------

sub _autoload {
    my $class = shift;
    my $v;
    no strict REFS;
    
    unless ( $LOADED->{ $class }
          || defined ${ $class.PKG.LOADED  } 
          || defined ${ $class.PKG.VERSION }
          || @{ $class.PKG.ISA }) {

        _debug("autoloading $class\n") if $DEBUG;
        $v = ${ $class.PKG.VERSION } ||= 0;
        local $SIG{__DIE__};
        eval "require $class";
        die $@ if $@;
        ${ $class.PKG.LOADED } ||= 1;
#        die $@
#            if $@ && $@ !~ /^Can't locate .*? at \(eval /;
#        die sprintf("Module '%s' is empty in %s at %s line %s\n", $class, caller(2))
#            unless *{"$class\::"};
    }
    return $class;
}

sub _debug {
    print STDERR @_;
}
    
1;
__END__

=head1 NAME

Badger::Class - class metaprogramming module

=head1 SYNOPSIS

    # build a badger-based module
    package Your::Module;
    
    # import hooks allow you to define class properties up front
    use Badger::Class
        version     => 1.00,            # sets $VERSION
        debug       => 0,               # sets $DEBUG
        throws      => 'wobbler',       # sets $THROWS error type
        base        => 'Badger::Base',  # define base class(es)
        import      => 'class',         # class() gets metaclass object
        utils       => 'blessed UTILS', # imports from Badger::Utils
        codec       => 'storable',      # imports from Badger::Codecs
        codecs      => 'base64 utf8'    # codecs do encode/decode
        constants   => 'TRUE FALSE',    # imports from Badger::Constants
        constant    => {                # define your own constants
            pi      => 3.14,
            e       => 2.718,
        },
        words       => 'yes no quit',   # define constant words
        get_methods => 'foo bar',       # create accessors
        set_methods => 'wiz bang',      # create mutators
        methods     => {                # create/bind methods
            wam     => sub { ... },
            bam     => sub { ... },
        },
        exports     => {                # exports via Badger::Exporter
            all     => '$X $Y wibble',  # like @EXPORTS
            any     => '$P $Q pi e',    # like @EXPORT_OK
            tags    => {                # like %EXPORT_TAGS
                xy  => '$X $Y',         #   NOTE: 'X Y Z' is syntactic
                pq  => '$P $Q',         #   sugar for ['X', 'Y', 'Z']
            },
            hooks   => {                # export hooks - this synopsis
                one => sub { ... },     # shows the various hooks that
                two => sub { ... },     # Badger::Class defines: base,
            },                          # version, debug, etc.
        },
        messages    => {                # define messages, e.g. for 
            missing => 'Not found: %s', # errors, warnings, prompts, etc.
            have_u  => 'Have you %s my %s?',
            volume  => 'This %s goes up to %s',
        };                              # Phew!

    # the rest of your module follows...
    our $X = 10;
    our $Y = 20;
    sub whatever { ... }
    # ...etc...
    
    # The import hooks above are shortcuts to Badger::Class methods which
    # you can access via 'class', e.g.
    class->base('Another::Base', 'And::Another');
    class->get_methods('method1', 'method2');
    class->exports( all => '$X $Y' );   # short for ['$X', '$Y']
    class->methods(
        wam => sub { ... }
        bam => sub { ... }
    );
    
    # methods for accessing class (package) variables with inheritance
    class->var('X');                    # get $X in current class
    class->var( X => 10 );              # set $X in current class
    class->any_var('X');                # get $X in current or base classes
    class->all_vars('X');               # all $X in current/base classes
    # ...and more...
    
    # class() can access other classes, too
    class('Another::Module')->var('X'); # $Another::Module::X
    
    # and you can call it as a $self method
    sub wibble {
        my $self  = shift;
        my $class = $self->class;       # Badger::Class object
        my $xvar  = $class->var('X');   # fetch $X
        print $class;                   # auto-stringifies to class
    }                                   # name, e.g. Your::Module
                                        
=head1 DESCRIPTION

L<Badger::Class> is a class metaprogramming module which you can use
to simplify the process of building Perl Modules.

In the simplest case, it provides an exportable C<class> subroutine
which returns a L<Badger::Class> object for the current package (we
use the term I<package> when we're talking specifically about Perl's
symbol tables - but the term is generally synonymous with I<class>)

    package Your::Module;
    use Badger::Module 'class';

You can also specify this using the C<import> parameter. 

    use Badger::Class
        import => 'class';

(NOTE: the C<import> doesn't have to start on a new line - it can follow
the C<use Badger::Class> on the same line if you prefer)

The C<Badger::Class> object provides a number of methods for inspecting
and manipulating the current class.  For example, there are methods
providing access to class variables.

    class->var( X => 10 );          # same as: $X = 10
    class->var('X');                # same as: $X

In this simple example, the effect is exactly the same as modifying the C<$X>
I<package> variable directly. However, this method (and related methods)
provides an abstraction of I<class> variables that works correctly with
respect to subclassing. That is, accessing a I<class> variable in a subclass
of L<Your::Module> will resolve to the I<package> variable in the subclass,
rather than the base class I<$X> that you'll always get if you hard-code it.
More on that later...

Other C<Badger::Class> methods allow you to modify the class by adding 
base classes, generating accessor/mutator methods, defining exportable
items and so on.

    class->base('Another::Class');  # add new base class
    class->get_methods('foo bar');  # generate accessors
    class->exports(                 # define exports
        all => '$X $Y',
    )

These methods can also be accessed using import hooks, as shown in detail
in the synposis.

    use Badger::Class
        import  => 'class',
        version => 1.00,
        base    => 'Badger::Class Another::Class';
        # ...etc...

=head1 METHODS

=head2 new($package)

Constructor method for a C<Badger::Class> object.

=head2 name()

Returns the class (i.e. package) name.

=head2 symbols()

Returns a reference to the package symbol table for the class.

=head2 symbol($name)

Returns a symbol table entry for a particular name.

=head2 scalar_ref($name)

Returns a reference to the scalar value for a name in a symbol table.

=head2 array_ref()

=head2 hash_ref()

=head2 code_ref()

=head2 glob_ref()

=head2 scalar()

=head2 array()

=head2 hash()

=head2 var($name,$value)

Method to get or set a scalar package variable.

=head2 any_var($name)

Get the value of a package variable in the current package or those
of any of the base classes.  

=head2 all_vars($name)

Get all defined values of a package variable in the current package
or any of the base classes.  Returns a reference to a list.

=head2 list_vars($name)

This method return a reference to a list containing all the values defined
in a particular class variable for the current class and all base classes.
Each package variable should reference a list.

    package A;
    our $THINGS = ['Foo', 'Bar'];
    
    package B;
    our $THINGS = ['Baz', 'Bam'];
    
    package main;
    B->list_vars('THINGS');     # ['Foo', 'Bar', 'Baz', 'Bam']

=head2 hash_vars($name)

Works like L<list_vars()> but merges references to hash arrays into a 
single hash array.


=head2 parents()

Returns the immediate parents (base classes) of an object class.

=head2 heritage()

The heritage() method returns a list of Badger::Class objects
representing each class in the inheritance chain, starting with the
current class and continuing up through its superclasses.  To determine
the correct resolution order for superclasses, it implements a 
simplified version of the C3 method resolution algorithm.  See:

    * http://www.python.org/2.3/mro.html for a good introduction to the
      subject.

    * Algorithm::C3 on CPAN for an implementation in Perl

    * http://www.webcom.com/haahr/dylan/linearization-oopsla96.html for the
      original Dylan paper.

This implementation differs from the original C3 algorithm by relaxing
the constraint on maintaining local precedence order in the face of a 
more specialised precedence order that contradicts it.  What that means 
in simple terms can be demonstrated by the following example.  

Assume A and B are base classes, while AB is a subclass of (A, B), and BA is a
subclass of (B, A). If we now create a subclass ABBA of (AB, BA) then the
local precedence order of AB says that A should resolve before B, while the
LPO of BA says that B should come before A. The C3 algorithm will
intentionally fail at this point and throw an error warning about an
inconsistent heterarchy. In contrast, this implementation will resolve A
before B becase the more specialised ABBA subclass defines AB before BA. AB is
the winner that takes it all and BA is the loser standing small.

This implementation was originally written for the C<Template Toolkit> where
this variation in the algorithm had no relevance (i.e. because none of the TT
modules use multiple inheritance in an ambiguous way). The same thing applies
for all the core modules in the C<Badger> bundle. However, if you rely on this
method in your own classes then be warned of the fact that it's not a strict
implementation of the C3 algorithm. You may prefer to use C<Class::C3>
instead.

On the other hand, this kind of multiple inheritance ambiguity is something of
an edge case anyway. Unless you're doing lots of MI in weird and wonderful
ways, the chances are that it'll never affect you. So in the general case,
this algorithm works the same as C3, but with the benefit of being a simpler
and faster implementation.  I'm inclined towards the belief that a 
deterministic algorithm 

=head1 CLASS CONFIGURATION METHODS

=head2 base(\@classes)

Method to add one or more base classes to the C<@ISA> inheritance list.
Effectively does the same thing as C<base.pm>.


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
