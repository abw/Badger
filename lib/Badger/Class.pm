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
        my $class = @_ ? shift : (caller())[0];
        ref $class || $class;
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
    map { $_ => \&_export_hook } 
    @HOOKS
});

sub _export_hook {
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
    no strict REFS;
    
    # remove any leading '$' 
    $name =~ s/^\$//;

    foreach my $pkg ($self->heritage) {
        _debug("looking for $name in $pkg\n") if $DEBUG;
        return ${ $pkg.PKG.$name } if defined ${ $pkg.PKG.$name };
    }

    return undef;
}

sub any_var_in {
    my $self  = shift;
    my $names = @_ == 1 ? shift : [@_];
    my ($pkg, $name);
    no strict REFS;
    
    $names = [ split DELIMITER, $names ] 
        unless ref $names eq ARRAY;
        
    # remove any leading '$' 
    $names = [ map { s/^\$//; $_ } @$names ];

    foreach $pkg ($self->heritage) {
        foreach $name (@$names) {
            _debug("looking for $name in $pkg\n") if $DEBUG;
            return ${ $pkg.PKG.$name } if defined ${ $pkg.PKG.$name };
        }
    }

    return undef;
}

sub all_vars {
    my ($self, $name) = @_;
    my $pkg  = $self->{ name };
    my ($value, @values);
    no strict   REFS;
    no warnings ONCE;

    # remove any leading '$' 
    $name =~ s/^\$//;

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
    
    # remove any leading '$' 
    $name =~ s/^\$//;

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

    # remove any leading '$' 
    $name =~ s/^\$//;

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

    # remove any leading '$' 
    $name =~ s/^\$//;

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
    return $self;
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

    return $self;
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


    $debug = ${ $pkg.PKG.DEBUG }
        if defined ${ $pkg.PKG.DEBUG };
        
    _debug("debug() Setting $pkg \$DEBUG to $debug\n") if $DEBUG;
    *{ $pkg.PKG.DEBUG } = \$debug;

    return $self;
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

    _autoload($self->CONSTANTS)->export(
        $self->{ name }, @$constants
    );
    
    return $self;
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
    return $self;
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
    return $self;
}
    
sub exports {
    my $self = shift;
    my $pkg  = $self->{ name };
    $self->base(EXPORTER);
    $pkg->exports(@_);
    return $self;
}

sub throws {
    my ($self, $throws) = @_;
    no strict   REFS;
    no warnings ONCE;
    _debug("defining $self THROWS $throws\n") if $DEBUG;
    *{ $self->{name}.PKG.THROWS } = \$throws;
    return $self;
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
    
    return $self;
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
    _autoload($self->UTILS)->export(
        $self->{ name }, @$syms
    );

    return $self;
}

sub codec {
    my $self   = shift;
    my $codecs = $self->CODECS;
    _autoload($codecs);
    $codecs->export_codec($self->{ name }, shift);
    return $self;
}

sub codecs {
    my $self = shift;
    my $codecs = $self->CODECS;
    _autoload($codecs);
    $codecs->export_codecs($self->{ name }, shift);
    return $self;
}

sub method {
    my ($self, $name, $code) = @_;
    no strict REFS;
    _debug("defining method: $self\::$name => $code\n") if $DEBUG;
    *{ $self->{name}.PKG.$name } = $code;
    return $self;
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
    return $self;
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
    return $self;
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
    return $self;
}

sub instance {
    my $self = shift;
    $self->{ name }->new(@_);
}

sub loaded {
    # "loaded" is defined as "has an entry in the symbol table"
    keys %{ $_[0]->{ symbols } } ? 1 : 0;
}

sub load {
    my $self = shift;
    no strict REFS;
    
    # CARGO CULT ALERT: I copied some of this code from Moose (I think)
    # and then modified it without really thinking about what I was doing.
    # Needs a careful check.
    
    unless ($self->loaded) {
        local $SIG{__DIE__};                # Hmmm... why am I doing this?
        my $module = $self->{ name };
        eval "require $module";             # Hmmm... why not 'use'?
        die $@ if $@;
        ${ $module.PKG.LOADED } ||= 1;         # mark it with our scent
    }
    
    return $self;
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
    class->exports( all => '$X $Y' );   # '$X $Y' is short for ['$X', '$Y']
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

    # class() can access other classes...
    class('Another::Module')->var('X'); # $Another::Module::X
    
    # ...and be used to compose new classes
    class('Amplifier')
        ->base('Badger::Base')
        ->constant( max_volume => 10 )
        ->methods( about => sub { 
              "This amp goes up to " . shift->max_volume 
          } );
    
    Amplifier->about;                   # This amp goes up to 10
    
    # when you need that push over the cliff...
    class('Nigels::Amplifier')
        ->base('Amplifier')
        ->constant( max_volume => 11 );
    
    Nigels::Amplifier->about;           # This amp goes up to 11

    # you can also call class as an object method
    sub wibble {
        my $self  = shift;
        my $class = $self->class;       # Badger::Class object
        my $xvar  = $class->var('X');   # fetch $X
        print $class;                   # auto-stringifies to class
    }                                   # name, e.g. Your::Module
    
    # e.g. dynamically adding a method to an object's class
    $object->class->method( foo => sub { ... } );

=head1 DESCRIPTION

L<Badger::Class> is a class metaprogramming module. It provides methods for
defining, extending and manipulating object classes and related metadata in a
relatively clean and simple way.

The module defines an exportable C<class> subroutine which returns a
L<Badger::Class> object for the current package (we use the term I<package>
when we're talking specifically about Perl's symbol tables - but the term is
generally synonymous with I<class>)

    package Your::Module;
    use Badger::Module 'class';     # import class subroutine

You can also specify this using the C<import> parameter. 

    use Badger::Class import => 'class';

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
rather than the base class.  On the other hand, writing C<$X> will always
resolve to the base class package (which may be what you want, of course).

A form of inheritance for class variables can be implemented using the 
L<any_var()> method.  This looks for a package variable in the current class
or in any of the base classes.

    class->any_var('X');            # $X with @ISA inheritance

This idiom is particularly useful to default values for a class that you might
want to re-define later in a subclass. We'll look at some examples of that
shortly.

Other C<Badger::Class> methods allow you to modify the class by adding 
base classes, generating accessor/mutator methods, defining exportable
items and so on.

    class->version(3.14);           # define $VERSION
    class->base('Another::Class');  # add base class
    class->get_methods('foo bar');  # generate accessors
    class->exports(                 # define exports
        all => '$X $Y',
    )

These methods can also be accessed using import hooks.  The above example
can be expressed more succinctly as:

    use Badger::Class
        version     => 3.14,
        base        => 'Another::Class';
        get_methods => 'foo bar',
        exports     => {
            all     => '$X $Y',
        };

You can also modify remote classes (i.e. classes other than the current
one) and construct entirely new classes.

    # extending an existing class 
    class->('Existing::Class')->methods(
        wiz => sub {
            # new wiz() method for Existing::Class
        }
    );

    # creating a new class
    class('Amplifier')
        ->base('Badger::Base')
        ->constant( max_volume => 10 )
        ->methods( about => sub { 
              "This amp goes up to " . shift->max_volume 
          } );
    
    Amplifier->about;                   # This amp goes up to 10

    # creating a new subclass of the new class
    class('Nigels::Amplifier')
        ->base('Amplifier')
        ->constant( max_volume => 11 );
    
    Nigels::Amplifier->about;           # This amp goes up to 11

The L<Badger::Class> module can itself be subclassed, allowing you to create
more specialised class metaprogramming modules to suit your own needs. For
example, you could create a class module for a particular project that hooks
into your own modules that define constants, utility functions, and so on.

    # defining a Badger::Class subclass...
    package My::Class;
    
    # ...using Badger::Class, of course
    use Badger::Class
        base     => 'Badger::Class',
        constant => {
            CONSTANTS => 'My::Constants',
            UTILS     => 'My::Utils',
        };

    # defining classes using your new class module
    package My::Example;
    
    use My::Class
        version   => 11,                     # inherited Badger::Class options
        base      => 'My::Base',
        constants => 'black white blue',     # imported from My::Constants
        utils     => 'wibble frusset pouch'; # imported from My::Utils

=head1 EXPORTABLE SUBROUTINES

The subroutines listed in this section can be imported into your module in the
usual way:

    # single argument
    use Badger::Class 'class';

    # multiple arguments
    use Badger::Class 'class', 'CLASS';

You can also use the short form where multiple items are concatenated into 
a whitespace delimited string.

    # single argument, multiple symbols
    use Badger::Class 'class CLASS';

You can also use the explicit C<import> flag if you prefer:

    # single argument
    use Badger::Class import => 'class';

    # single argument, multiple symbols
    use Badger::Class import => 'class CLASS';

    # multiple arguments
    use Badger::Class import => ['class', 'CLASS'];

=head2 CLASS($pkg)

This subroutine returns the class name (i.e. package) of the class or 
object it was called against, or the package of the caller if no argument
is specified.

    CLASS->method;          # same as __PACKAGE__->method
    $object->CLASS->method; # same as ref($object)->method

There's nothing special about the class name returned.  It's just a plain
text string.

=head2 class($pkg)

This subroutine returns a C<Badger::Class> object for the package name
or object passed as an argument.  If no argument is passed then it uses
the package of the caller.

    # Badger::Class object for current __PACKAGE__
    my $class = class;

    # Badger::Class object for another package
    my $class = class('Another::Class');

Be aware that the C<Badger::Class> object returns the package name when
stringified (i.e. printed, appended to another string, etc).   That means
that you can treat it like a string for most practical purposes, even
though it's actually an object.

    print class;            # Your Module

You can also call C<class> as an object method. Perl implicitly passes the
object reference (traditionally called C<$self>) as the first argument So the
C<class> subroutine Just Works[tm] and returns a C<Badger::Class> object for
the object's class.

    package Your::Module;
    
    use Badger::Class 'class';
    
    sub introspect {
        my $self  = shift;          # object $self is first argument
        my $class = $self->class;   # same as class($self)
        
        # $class is an object, but gets auto-stringified to class name
        print "I am a $class instance\n";
    }

One important thing to understand is that calling C<class> as a method
will always return the relevant class for the object.  If C<$self> is
an instance of C<Your::Module>, then you'll get a C<Badger::Class>
object for C<Your::Module>. 

    my $ym = Your::Module->new;
    $ym->introspect;                # I am a Your::Module instance

However, if C<$self> is an instance of a I<subclass> of C<Your::Module>, say,
C<My::Module>, then you'll get a C<Badger::Object> back for C<My::Module>
instead.

    package My::Module;
    use base 'Your::Module';
    
    package main;
    my $mm = My::Module->new;
    $mm->introspect;                # I am a My::Module instance

In this simple example it would have been just as easy to use C<ref> to find
out what kind of object we were dealing with, especially when all we're doing
is printing the class name. However, things get more interesting when we
combine that with the ability to inspect and define class variables.

Consider this base class module:

    package Amplifier;
    
    use Badger::Class
        base        => 'Badger::Base',
        import      => 'class',
        get_methods => 'max_volume';
        
    our $MAX_VOLUME = 10;
    
    sub init {
        my ($self, $config) = @_;
        $self->{ volume     } = 0;   # start quietly
        $self->{ max_volume } = $config->{ max_volume } 
            || $MAX_VOLUME;
        return $self;
    }

The C<init()> method (see L<Badger::Base>) looks for a C<max_volume> 
setting in the configuration parameters, or defaults to the C<$MAX_VOLUME>
package variable.

    my $amp = Amplifer->new;      # default max_volume: 10

So if you're on ten here, all the way up, all the way up, all the way up,
you're on ten on your guitar. Where can you go from there? Where? Nowhere. 
Exactly. What we do is, if we need that extra push over the cliff, you know 
what we do?

    my $amp = Amplifier->new( max_volume => 11 );

Eleven. Exactly. One louder.

But what if we wanted to make this the default?  Sure, we could make ten
louder and make that be the top number, or we could remember to specify 
the C<max_volume> parameter each time we use it.  But let's assume we're
working with temperamental artistes who will be too busy worrying about
the quality of the backstage catering to think about checking their volume
settings before they go on stage.

(BTW, if you're thoroughly confused at this point as to what amplifiers 
going up to eleven has to do with anything then you might like to try 
googling "eleven one louder" for enlightenment).

Thankfully we didn't hard-code the maximum volume but used the C<$MAX_VOLUME>
package variable instead. We can change it directly like this:

    $Amplifier::MAX_VOLUME = 11;

Or using the class L<var()> method (just to show you what the roundabout way
looks like):

    Amplifier->class->var( MAX_VOLUME => 11 );

Either way has the desired effect of changing the default maximum volume
setting without having to go and edit the source code of the module. However,
it is an all-encompassing change that will affect all future instances of
C<Amplifier> (and any subclasses derived from it) that don't define
their own C<max_volume> parameter explicitly.

But what if that's not what you want? What if you're playing a Jazz/Blues
festival on the Isle of Lucy, for example, or performing a musical trilogy in
D minor, the saddest of all keys? In that case you don't want to change I<all>
the amplifiers, just I<some> of them. 

This is the kind of problem that is easily solved by using inheritance. Your
base class amplifier defines the default properties and behaviours for the
I<general case>, leaving subclasses to reimplement anything that needs
changing for more I<specific cases>.  All the bits that don't get redefined
by a subclass are automatically inherited from the base class.

The only problem is that Perl's limited OO model only applies inheritance to
methods and not package variables. However, we can use the C<Badger::Class>
object to roll our own inheritance mechanism for package variables where
needed.

Let's look again at the relevant line from the C<init()> method where 
the C<max_volume> is set:

    $self->{ max_volume } = $config->{ max_volume } 
        || $MAX_VOLUME;

Rather than accessing C<$MAX_VOLUME> directly, we can instead use the 
class object to fetch the value of the C<$MAX_VOLUME> class variable for us.

    $self->{ max_volume } = $config->{ max_volume } 
        || $self->class->var('MAX_VOLUME');

This will continue to work as before for all instances of C<Amplifer>. It's a
little more long-winded and involves an extra method call or two, but it has
the benefit of working correctly with respect to inheritance. That means we
can now subclass C<Amplifier> and define a different default value for
C<$MAX_VOLUME>.

    package Nigels::Amplifier;
    use base 'Amplifier';
    our $VOLUME = 11;

The C<init()> method will now look for the C<$MAX_VOLUME> variable in our
subclass package (C<Nigels::Amplifier>) instead of the base class
package (C<Amplifier>).

One further enhancement we can make is to use L<any_var()> instead of
L<var()>.

    $self->{ max_volume } = $config->{ max_volume } 
        || $self->class->any_var('MAX_VOLUME');

If you don't define a new C<$MAX_VOLUME> class variable in the subclass then
C<any_var()> will walk upwards through all the base classes until it finds
one that does.  The end result is that your class variables will appear to
be inherited from super-class to sub-class. 

It's worth stressing at this point that there isn't any I<real> inheritance
going on here with respect to package variables. Nothing is being copied or
shuffled around to give your subclasses the package variables that they
inherit from their base classes (except perhaps for the odd bit of internal
caching for the sake of efficiency).  Instead it's the C<Badger::Class>
object that is smart enough to go looking for package variables in all
the right places, but only if you ask it to do so.

Accessing package variables via a method is obviously going to be slower than
referencing them direct. The benefit comes from flexibility and ease of use
(and it's generally better to optimise for programmer convenience unless you
have good reason to do otherwise). In most real-world applications,
performance is unlikely to be affected to any significant degree unless you're
doing it often in a speed critical section of code. If this is an issue, then
you can perform the more expensive variable lookup once when the object is
initialised and cache the value(s) internally for other methods to use, as
shown in the earlier examples with C<$self-E<gt>{ max_volume }>.

=head2 classes($pkg)

This subroutine returns a list (in list context) or a reference to a list (in
scalar context) of C<Badger::Class> objects. As per L<class>, a package name
or object reference should be passed as the first argument, either explicitly
or implicitly by calling it as an object method.

The first L<Badger::Class> object in the list returned represents the 
current class object, as would be returned by L<class>.  Any further
items in the list are L<Badger::Class> objects representing all the base
classes of the object.  The order of base classes is determined by the 
L<heritage()> method which implements a simplified variant of the C3
method resolution algorithm. 

=head1 METHODS

=head2 new($package)

Constructor method for a C<Badger::Class> object.  You shouldn't ever
need to call this method directly.  Use the L<class> subroutine instead.

=head2 name()

Returns the class (i.e. package) name.

    print class->name;          # Your::Module

This method is called automatically whenever a C<Badger::Class> object
is stringified.

    print class;                # Your::Module

=head2 symbols()

Returns a reference to the package symbol table for the class.

    my $symbols = class->symbols;

=head2 symbol($name)

Returns a symbol table entry for a particular name.

    my $symbol = class->symbol('FOO');

=head2 scalar_ref($name)

Returns a reference to the SCALAR value for a name in the symbol table.

    my $xref = class->scalar_ref('X');  # like: $xref = \$X;

=head2 array_ref()

Returns a reference to the ARRAY value for a name in the symbol table.

    my $xref = class->array_ref('X');   # like: $xref = \@X;

=head2 hash_ref()

Returns a reference to the HASH value for a name in the symbol table.

    my $xref = class->hash_ref('X');    # like: $xref = \%X;

=head2 code_ref()

Returns a reference to the CODE value for a name in the symbol table.

    my $xref = class->code_ref('X');    # like: $xref = \&X;

=head2 glob_ref()

Returns a reference to the GLOB value for a name in the symbol table.

    my $xref = class->glob_ref('X');    # like: $xref = \*X;

=head2 scalar()

Returns the SCALAR value for a name in the symbol table.

    my $x = class->scalar('X');         # like: $x = $X;

=head2 array()

Returns the ARRAY values for a name in the symbol table.

    my @x = class->scalar('X');         # like: @x = @X;

=head2 hash()

Returns the HASH values for a name in the symbol table.

    my %x = class->scalar('X');         # like: %x = %X;

=head2 var($name,$value)

Method to get or set a scalar package variable.  The leading C<$> sigil
is not required.

    class->var( X => 10 );                  

=head2 any_var($name)

Get the value of a package variable in the current package or those
of any of the base classes.  

=head2 any_var_in($names)

Looks in the current package and those of the base classes for any of the
scalar variables listed in C<$names>. The first defined value is returned, or
undef if none are defined.

Multiple arguments can be specified as a list, a reference to a list or 
a single string of whitespace delimiter variable names (without the leading
C<$> sigil).

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
this variation in the algorithm has no relevance because none of the TT
modules use multiple inheritance in an ambiguous way. The same thing applies
for all the core modules in the C<Badger> bundle which generally restrict
themselves to single inheritance. Furthermore, this I<only> affects the
resolution of class variables and has no bearing on the way in which Perl
resolves methods (depth-first, left-to-right in Perl 5, C3 in Perl6). 

Unless you're using MI in weird and wonderful ways, then the chances are that
it won't affect you. But if you do use this method in your own code then be
warned of the fact that it's not a strict implementation of the C3 algorithm.
However it is better than Perl 5's default implementation (in the face of
conflict resolution) and has the benefit of being a smaller, simpler and
faster implementation than regular C3. It's also fully deterministic (i.e. it
never fails) which removes the need for any error handling (which can be
tricky if you're trying to call an error method on an object which can't
resolve its own methods).

=head1 CLASS CONFIGURATION METHODS

=head2 base(\@classes)

Method to add one or more base classes to the C<@ISA> inheritance list.
Effectively does the same thing as C<base.pm>.

=head1 TODO

Finish documentation.

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
