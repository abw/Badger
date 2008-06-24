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
use Badger::Constants qw( DELIMITER ARRAY );
use Badger::Utils 'load_module';
use Carp;
use constant {
    CONSTANTS => 'Badger::Constants',
    EXPORTER  => 'Badger::Exporter',
    CODECS    => 'Badger::Codecs',
    UTILS     => 'Badger::Utils',
};
use overload 
    '""' => 'name',
    fallback => 1;

our $VERSION    = 0.01;
our $DEBUG      = 0 unless defined $DEBUG;
our $LOADED     = { }; 
our @HOOKS      = qw( 
    base version debug constant constants exports throws messages utils
    codec codecs
);


#-----------------------------------------------------------------------
# Define a lexical scope to enclose class lookup table
#-----------------------------------------------------------------------

{
    # lookup table mapping package names to Badger::Class objects
    my $CLASSES = { };
    
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
__PACKAGE__->export_any('class', 'classes');

# define custom hooks for load options
__PACKAGE__->export_hooks({
    map { ($_ => \&export_hook) } @HOOKS
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
    no strict 'refs';
    no warnings 'once';
    ${"${package}::BADGER_LOADED"} ||= 1;
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
# Object methods to access name, symbol table and various symbols in
# the symbol table
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

sub var {
    my $self = shift;
    my $name = shift;
    my $pkg  = $self->{ name };
    no strict 'refs';
    no warnings 'once';
    
    return @_
        ? (${"${pkg}::$name"} = shift)
        :  ${"${pkg}::$name"};
}

sub any_var {
    my $self = shift;
    my $name = shift;
    my $pkg = $self->{ name };
    no strict 'refs';

    if (@_) {
        # we got two arguments (or possibly more): name => value
        _debug("setting $name in $pkg to $_[0]\n") if $DEBUG;
        return (${"${pkg}::$name"} = shift);
    }
    else {
        foreach my $pkg ($self->heritage) {
            _debug("looking for $name in $pkg\n") if $DEBUG;
            return ${"${pkg}::$name"} if defined ${"${pkg}::$name"};
        }
    }
    return undef;
}

sub all_vars {
    my $self  = shift;
    my $name  = uc shift;           # all package vars are UPPER CASE
    my $pkg = $self->{ name };
    my ($value, @values);
    no strict 'refs';

    foreach my $pkg ($self->heritage) {
        _debug("looking for $name in $pkg\n") if $DEBUG;
        no warnings 'once';
        push(@values, $value)
            if defined ($value = ${"${pkg}::${name}"});
    }
    return wantarray ? @values : \@values;
}

sub list_vars {
    my $self = shift;
    my $name = uc shift;           # all package vars are UPPER CASE
    my $vars = $self->all_vars($name);
    my (@merged, $list);

    # reverse the package vars so we get base classes first, followed by subclass,
    # then we add any additional arguments on as well in the order specified
    foreach $list ( reverse(@$vars), @_ ) {
        next unless defined $list;
        return $self->{name}->error("Invalid $name configuration option (not a list ref): $list")
            unless ref $list eq 'ARRAY';
        next unless @$list;
        push(@merged, @$list);
    }

    return \@merged;

    # this causes problems when doing foo( something_that_calls_list_vars() )
    # because list_vars assumed list context when we actually want a scalar ref
    #    return wantarray ? @merged : \@merged;
}

sub hash_vars {
    my $self = shift;
    my $name = uc shift;           # all package vars are UPPER CASE
    my $vars = $self->all_vars($name);
    my (%merged, $hash);

    # reverse the package vars so we get base classes first, followed by subclass,
    # then we add any additional arguments on as well in the order specified
    foreach $hash ( reverse(@$vars), @_ ) {
        next unless defined $hash;
        return $self->{name}->error("Invalid $name configuration option (not a hash ref): $hash")
            unless ref $hash eq 'HASH';
        @merged{ keys %$hash } = values %$hash;
    }
    
    return \%merged;
}

sub hash_value {
    my ($self, $name, $item, $default) = @_;

    foreach my $hash ($self->all_vars($name)) {
        next unless ref $hash eq 'HASH';
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
    my $parents = $self->{ parents } ||= do {
        # make sure the module is loaded before we go looking at its @ISA
        autoload($self->{ name });
#        $LOADED->{ $self->{ name } } ||= UTILS->load_module($self->{ name });
        [ 
            map { class($_) }                   # parents are immediate 
            $self->array('ISA')                 # superclasses defined in @ISA
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
    while (my $base = shift @$bases) {
        no strict 'refs';
        next if $pkg->isa($base);
        _debug("Adding $pkg base class $base\n") if $DEBUG;
        push @{"${pkg}::ISA"}, $base;
        autoload($base);
    }
}


#-----------------------------------------------------------------------
# autoload($module)
#
# Helper subroutine to autoload a module.  Could probably be merged
# with similar method(s) in T::Utils.
#-----------------------------------------------------------------------

sub autoload {
    no strict 'refs';
    my $class = shift;
    my $v;
    if ( defined ${"${class}::BADGER_LOADED"} 
      || defined ${"${class}::VERSION"}
      || @{"${class}::ISA"}) {
        _debug("$class already defines version ", ${"${class}::VERSION"}, "\n") if $DEBUG;
    }
    else {
        _debug("autoloading $class\n") if $DEBUG;
        $v = ${"${class}::VERSION"} ||= 0;
        local $SIG{__DIE__};
        eval "require $class";
        die $@ if $@;
        ${"${class}::BADGER_LOADED"} ||= 1;
#        die $@
#            if $@ && $@ !~ /^Can't locate .*? at \(eval /;
#        die sprintf("Module '%s' is empty in %s at %s line %s\n", $class, caller(2))
#            unless *{"$class\::"};
    }
    return $class;
}


#-----------------------------------------------------------------------
# version($n)
#
# Method to define $VERSION and version() for a class.
#-----------------------------------------------------------------------

sub version {
    my ($self, $version) = @_;
    my $pkg = $self->{ name };
    no strict 'refs';
    _debug("Defining $pkg version $version\n") if $DEBUG;
    *{"${pkg}::VERSION"} = \$version
        unless defined ${"${pkg}::VERSION"}
                    && ${"${pkg}::VERSION"};
    *{"${pkg}::version"} = sub() { $version }
        unless defined *{"${pkg}::version"};
}


#-----------------------------------------------------------------------
# debug($n)
#
# Method to define a $DEBUG variable set to $n and a debugging() method
# used to enable/disable debugging.
#-----------------------------------------------------------------------

sub debug {
    my ($self, $debug) = @_;
    my $pkg = $self->{ name };
    no strict 'refs';

    # define a new debugging() method in the target class (if one doesn't
    # already exist) which calls the debugging() method on it's class object
    unless (defined *{"${pkg}::debugging"}) {
        _debug("Defining $pkg debugging() method\n") if $DEBUG;
        *{"${pkg}::debugging"} = sub { 
            class(shift)->debugging(@_) 
        };
    }

    # On this one occasion, we won't force the $DEBUG value to be set
    # to $debug if it's already been pre-defined to a value.  This 
    # emulates the idiom: our $DEBUG = $debug unless defined $DEBUG;
    # so that we can set $DEBUG flags *before* loading a module (or
    # rather, before TT auto-loads it on demand)
    unless (defined ${"${pkg}::DEBUG"}) {
        _debug("debug() Setting $pkg \$DEBUG to $debug\n") if $DEBUG;
        *{"${pkg}::DEBUG"} = \$debug
    }
}


#-----------------------------------------------------------------------
# debugging($flag)
#
# Class method to enable/disable debugging by switching the $DEBUG flag.
#-----------------------------------------------------------------------

sub debugging {
    my $self = shift;
    my $pkg = $self->{ name };
    no strict 'refs';

    # return current $DEBUG value when called without args
    return ${"${pkg}::DEBUG"} || 0
        unless @_;
    
    # set new debug value when called with an argument
    my $debug = shift;
    $debug = 0 if $debug =~ /^off$/i;

    # TODO: consider setting different parts of the flag, like TT2, 

    _debug("debugging() Setting $pkg debug to $debug\n") if $DEBUG;
    
    if (defined ${"${pkg}::DEBUG"}) {
        # update existing variable
        ${"${pkg}::DEBUG"} = $debug;
    }
    else {
        # define new variable, poking it into the symbol table using
        # *{...} rather than ${...} so that it's visible at compile time,
        # thus preventing any "Variable $DEBUG not defined errors
        *{"${pkg}::DEBUG"} = \$debug;
    }
    return $debug;
}


#-----------------------------------------------------------------------
# constants(\@constants)
#
# Method to export constants from Badger::Constants.
#-----------------------------------------------------------------------

sub constants {
    my $self = shift;
    my $constants = @_ == 1 ? shift : { @_ };
    $constants = [ split(DELIMITER, $constants) ] 
        unless ref $constants eq 'ARRAY';
    CONSTANTS->export($self->{ name }, @$constants);
}


#-----------------------------------------------------------------------
# constant(\%constants)
#
# Method to generate constant methods, just like constant.pm
#-----------------------------------------------------------------------

sub constant {
    my $self = shift;
    my $constants = @_ == 1 ? shift : { @_ };
    my $pkg = $self->{ name };

    # split string into pairs of assignments, e.g. "foo=bar, baz=bam"
    $constants = {
        map { split /\s*=>?\s*/ }
        split(DELIMITER, $constants)
    } unless ref $constants eq 'HASH';
    
    
    while (my ($name, $value) = each %$constants) {
        no strict 'refs';
        my $v = $value;     # new lexical variable to bind in closure
        _debug("Defining $pkg constant $name => $value\n") if $DEBUG;
        *{"${pkg}::$name"} = sub() { $value };
    }
}


#-----------------------------------------------------------------------
# exports(%exports)
#
# Method to define exports for the class.  Adds T::Exporter to base 
# classes (if not already in there) and calls the exports() methods.
#-----------------------------------------------------------------------

sub exports {
    my $self = shift;
    my $pkg  = $self->{ name };
    $self->base(EXPORTER);
    $pkg->exports(@_);
}


#-----------------------------------------------------------------------
# throws($throws)
#
# Method to define $THROWS package variable which defined the exception
# type throw by a module via the T::Base throw() method.
#-----------------------------------------------------------------------

sub throws {
    my ($self, $throws) = @_;
    my $pkg = $self->{ name };
    no strict 'refs';
    _debug("Defining $pkg throws $throws\n") if $DEBUG;
    no warnings;
    ${"${pkg}::THROWS"} = $throws;
}


#-----------------------------------------------------------------------
# messages(\%messages)
#
# Method to define $MESSAGES package variable, or add to existing one,
# which defines message formats for use with the T::Base message() method
#-----------------------------------------------------------------------

sub messages {
    my $self = shift;
    my $args = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };
    my $pkg = $self->{ name };
    no strict 'refs';
    no warnings;
    # if there aren't any existing $MESSAGES then we can store
    # $messages in it and be done, otherwise we have to merge.
    my $messages = ${"${pkg}::MESSAGES"};
    if ($messages) {
        _debug("merging $pkg messages: ", join(', ', keys %$args), "\n") if $DEBUG;
        @$messages{ keys %$args } = values %$args;
    }
    else {
        _debug("adding $pkg messages: ", join(', ', keys %$args), "\n") if $DEBUG;
        ${"${pkg}::MESSAGES"} = $messages = $args;
    }
    return $messages;
}


#-----------------------------------------------------------------------
# utils(@symbols)
#
# Method to import symbols from Badger::Utils
#-----------------------------------------------------------------------

sub utils {
    my $self = shift;
    my $syms = @_ == 1 ? shift : { @_ };
    my $pkg  = $self->{ name };
    $syms = [ split(DELIMITER, $syms) ] 
        unless ref $syms eq ARRAY;

#    _debug("utils for $pkg from ", ref $self, "\n");
    $self->load_utils;
    
    # ...when we would rather use the constant alias
    $self->UTILS->export($self->{ name }, @$syms);
}

sub load_utils {
    # ick! we have to use the real module name if we want to use 'require'...
    require Badger::Utils;
}    

#-----------------------------------------------------------------------
# codec($name)
# codecs($names)
#
# Method to export codec(s) from Badger::Codecs.
#-----------------------------------------------------------------------

sub codec {
    my $self = shift;
    require Badger::Codecs;   # more ick! why bother with CODECS?
    CODECS->export_codec($self->{ name }, shift);
}

sub codecs {
    my $self = shift;
    require Badger::Codecs;   # more ick! why bother with CODECS?
    CODECS->export_codecs($self->{ name }, shift);
}


#-----------------------------------------------------------------------
# method($name, $code)
#
# Method to define a method.
#-----------------------------------------------------------------------

sub method {
    my ($self, $name, $code) = @_;
    no strict 'refs';
    *{$self->{ name } . '::' . $name} = $code;
}

sub get_methods {
    my ($self, $names) = @_;
    $names = [ $names ] unless ref $names eq ARRAY;
    $names = [ map { split DELIMITER } @$names ];
    no strict 'refs';
    foreach (@$names) {
        my $name = $_;
        *{$self->{ name } . '::' . $name} = sub {
            $_[0]->{ $name };
        };
    }
}

sub set_methods {
    my ($self, $names) = @_;
    $names = [ $names ] unless ref $names eq ARRAY;
    $names = [ map { split DELIMITER } @$names ];
    no strict 'refs';
    foreach (@$names) {
        my $name = $_;
        *{$self->{ name } . '::' . $name} = sub {
            @_ == 2 
                ? ($_[0]->{ $name } = $_[1])
                :  $_[0]->{ $name };
        };
    }
}


sub _debug {
    print STDERR @_;
}
    
1;
__END__

=head1 NAME

Badger::Class - base class module for accessing class data

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

TODO

=head1 METHODS

=head2 new($package)

Constructor method for a C<Badger::Class> object.

=head2 name()

=head2 symbols()

=head2 symbol()

=head2 scalar_ref()

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
inconsistent heterarchy. In constrast, this implementation will resolve A
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
and faster implementation.

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
