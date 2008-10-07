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
use Carp;
use base 'Badger::Exporter';
use Badger::Constants 
    'DELIMITER SCALAR ARRAY HASH CODE PKG REFS ONCE TRUE FALSE';
use constant {
    FILESYSTEM => 'Badger::Filesystem',
    CONSTANTS  => 'Badger::Constants',
    EXPORTER   => 'Badger::Exporter',
    MIXIN      => 'Badger::Mixin',
    CODECS     => 'Badger::Codecs',
    UTILS      => 'Badger::Utils',
    DEBUGGER   => 'Badger::Debug',
    DEFAULTS   => 'Badger::Class::Defaults',
    ALIASES    => 'Badger::Class::Aliases',
    LOADED     => 'BADGER_LOADED',
    MESSAGES   => 'MESSAGES',
    VERSION    => 'VERSION',
    MIXINS     => 'MIXINS',
    THROWS     => 'THROWS',
    ISA        => 'ISA',
    base_id    => 'Badger',
};
use overload 
    '""' => 'name',
    fallback => 1;

our $VERSION    = 0.01;
our $DEBUG      = 0 unless defined $DEBUG;
our $LOADED     = { }; 
our @HOOKS      = qw( 
    base uber mixin mixins version constant constants words vars defaults
    aliases exports throws messages utils codec codecs filesystem hooks
    methods slots accessors mutators get_methods set_methods overload 
    as_text is_true
);
our $HOOKS = { 
    map { $_ => $_ }
    @HOOKS
};


*get_methods = \&accessors;
*set_methods = \&mutators;


#-----------------------------------------------------------------------
# Define a lexical scope to enclose class lookup table
#-----------------------------------------------------------------------

{
    # lookup table mapping package names to Badger::Class objects
    my $CLASSES = { };

    # class/package name - define this up-front so we can use it below
    sub CLASS {
        my $class = @_ ? shift : (caller())[0];
        ref $class || $class;
    }

    # Sorry if this messes with your head.  We want class() and classes()
    # methods that create Badger::Class objects.  However, we also want 
    # Badger::Class to be subclassable (e.g. Template::Class), where class()
    # and classes() return the subclass objects (e.g. Template::Class).  So
    # we have an UBER() class method whose job it is to create the class()
    # and classes() methods for the relevant class or subclass
    sub UBER {
        my $pkg = shift || __PACKAGE__;

        # The class() subroutine is used to fetch/create a Badger::Class 
        # object for a package name.  We create it via a generator so that
        # subclasses can define their own custom class() method which blesses 
        # the class objects into their own class (e.g. Template::Class rather 
        # than Badger::Class)
        my $class_sub = sub {
            my $class = @_ ? shift : (caller())[0];
            my $bless = shift || $pkg;
            $class = ref $class || $class;
            return $CLASSES->{ $class } || $bless->new($class);
        };

        # The classes() method returns a list of Badger::Class objects for 
        # each class in the inheritance chain, starting with the object 
        # itself, followed by each base class, their base classes, and so on. 
        # As with class(), we use a generator to create a closure for the 
        # subroutine to allow the the class object name to be parameterised.
        my $classes_sub = sub {
            my $class = shift || (caller())[0];
            $class_sub->($class)->heritage;
        };

        no strict REFS;
        no warnings 'redefine';
#        *{ $pkg.PKG.'CLASS'     } = sub () { $pkg };
        *{ $pkg.PKG.'class'     } = $class_sub;
        *{ $pkg.PKG.'classes'   } = $classes_sub;
        *{ $pkg.PKG.'_autoload' } = \&_autoload;

        $pkg->export_any('CLASS', 'class', 'classes');
    }

    # call the UBER method to generate class() and classes() for this module
    __PACKAGE__->UBER;
}


#-----------------------------------------------------------------------
# Define exportable items and export hook (see Badger::Exporter)
#-----------------------------------------------------------------------

# define custom hooks for load options
CLASS->export_hooks({
    debug    => \&_debug_hook,
    map { $_ => \&_export_hook } 
    @HOOKS
});

CLASS->export_fail(\&_export_fail);

sub _export_hook {
    my ($class, $target, $key, $symbols) = @_;
    croak "You didn't specify a value for the '$key' load option."
        unless @$symbols;
    # make sure we forward the $class to class() so this module can 
    # be subclassed (e.g. Badger::Web::Class).  NOTE: I'm pretty sure
    # this isn't required any more since I added the UBER method - must check
    class($target, $class)->$key(shift @$symbols);
}

# define catch-all which allows sub-classes to declare hooks via $HOOKS
sub _export_fail {
    my ($class, $target, $key, $symbols, $import) = @_;
#    _debug("_export_fail($class, $target, $key, $symbols)\n");
    my $hook = class($class)->hash_value( HOOKS => $key ) || return;
    croak "You didn't specify a value for the '$key' load option."
        unless @$symbols;
    class($target, $class)->$hook(shift @$symbols);
}
    
sub export {
    my ($class, $package, @args) = @_;
    no strict   REFS;
    no warnings ONCE;
    ${$package.PKG.LOADED} ||= 1;
    $class->SUPER::export($package, @args);
}

sub _debug_hook {
    my ($class, $target, $key, $symbols) = @_;
    croak "You didn't specify a value for the '$key' load option."
        unless @$symbols;
    my $debug = shift @$symbols;
    $debug = { default => $debug }
        unless ref $debug eq HASH;
    _autoload($class->DEBUGGER)->export($target, %$debug);
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

sub id { 
    my $self = shift;
    return @_ 
        ? $self->{ id } = shift
        : $self->{ id } ||= do {
            my $pkg  = $self->{ name };
            my $base = $self->base_id;          # base to remove, e.g. Badger
            if ($base eq $pkg) {
                $pkg = $1 if  $pkg =~ /(\w+)$/; # Badger - Badger --> Badger
            } else {                              
                $pkg =~ s/^${base}:://;         # Badger::X::Y - Badger --> X::Y
            }
            $pkg =~ s/::/./g;                   # X::Y --> X.Y
            lc $pkg;                            # X.Y --> x.y
        };
}


#-----------------------------------------------------------------------
# methods to access symbol table 
#-----------------------------------------------------------------------

*pkg = \&name;
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
    my $self  = shift;
    my $bases = @_ == 1 ? shift : [ @_ ];
    my $pkg   = $self->{ name };

    $bases = [ split(DELIMITER, $bases) ] 
        unless ref $bases eq ARRAY;
    
    # add each of $bases to @ISA and autoload it
    foreach my $base (@$bases) {
        no strict REFS;
        next if $pkg->isa($base);
        _debug("Adding $pkg base class $base\n") if $DEBUG;
        push @{ $pkg.PKG.ISA }, $base;
        _autoload($base);
    }
    return $self;
}

sub mixin {
    my $self   = shift;
    my $mixins = @_ == 1 ? shift : [ @_ ];

    $mixins = [ split(DELIMITER, $mixins) ] 
        unless ref $mixins eq ARRAY;

    foreach my $name (@$mixins) {
#        $name = $target . $name if $name =~ /^::/;
#        $self->debug("mixing $name into $self\n") if $DEBUG;
        _autoload($name)->mixin($self->{ name });
    }

    return $self;
}

sub mixins {
    my $self = shift;
    $self->base(MIXIN);
    $self->{ name }->mixins(@_);
    return $self;

    my $syms   = @_ == 1 ? shift : [ @_ ];
    my $mixins = $self->var_default(MIXINS, [ ]);
    
    $syms = [ split(DELIMITER, $syms) ] 
        unless ref $syms eq ARRAY;

#    $mixins->{ $_ } 
    push(@$mixins, @$syms);

    $self->debug("$self MIXINS are: ", $self->dump_data_inline($mixins), "\n") if $DEBUG;
    
    $self->exports( any => $syms );

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
    *{ $pkg.PKG.VERSION} = sub() { $version }
        unless defined *{ $pkg.PKG.'version' };

    return $self;
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

sub vars {
    my $self = shift;
    my $vars = @_ == 1 ? shift : [ @_ ];
    my $pkg  = $self->{ name };
    my ($symbol, $sigil, $name, $dest, $ref);

    $vars = [ split(DELIMITER, $vars) ] 
        unless ref $vars;

    $vars = { map { $_ => undef } @$vars }
        if ref $vars eq ARRAY;
    
    croak("Invalid vars specified: $vars\n")
        unless ref $vars eq HASH;
    
    # This is a slightly simplified (stricter) version of the equivalent 
    # code in vars.pm
    
    while (($symbol, $ref) = each %$vars) {
        no strict REFS;

        # only accept: $WORD @WORD %WORD WORD
        $symbol =~ /^([\$\@\%])?(\w+)$/
            || croak("Invalid variable name in vars: $_");
        ($sigil, $name) = ($1 || '$', $2);
        
        # expand destination to full package name ($Your::Module::WORD)
        $dest = $pkg.PKG.$name;

        _debug("$sigil$name => ", $ref || '\\'.$sigil.$dest, "\n") if $DEBUG;
        
        if ($sigil eq '$') {
            *$dest = defined $ref
                ? (ref $ref eq SCALAR ? $ref : do { my $copy = $ref; \$copy })
                : \$$dest;
        }
        elsif ($sigil eq '@') {
            *$dest = defined $ref
                ? (ref $ref eq ARRAY ? $ref : [$ref])
                : \@$dest;
        }
        elsif ($sigil eq '%') {
            *$dest = defined $ref
                ? (ref $ref eq HASH 
                     ? $ref 
                     : croak("Invalid hash variable for $symbol in vars: $ref")
                  )
                : \%$dest;
        }
        else {
            # should never happen
            croak("Unrecognised sigil for $symbol in vars");
        }
    }
    return $self;
}

sub defaults {
    my $self = shift;
    _autoload($self->DEFAULTS)->export(
        $self->{ name }, @_
    );
    return $self;
}

sub aliases {
    my $self = shift;
    _autoload($self->ALIASES)->export(
        $self->{ name }, @_
    );
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
    my $syms = @_ == 1 ? shift : [ @_ ];
    my $pkg  = $self->{ name };

    $syms = [ split(DELIMITER, $syms) ] 
        unless ref $syms eq ARRAY;

    _autoload($self->UTILS)->export(
        $self->{ name }, @$syms
    );

    return $self;
}

sub codec {
    my $self   = shift;
    my $codecs = $self->CODECS;

    _autoload($codecs)->export_codec(
        $self->{ name }, shift
    );

    return $self;
}

sub codecs {
    my $self = shift;
    my $codecs = $self->CODECS;

    _autoload($codecs)->export_codecs(
        $self->{ name }, shift
    );

    return $self;
}

sub method {
    my $self = shift;
    my $name = shift;
    no strict REFS;

    # method($name) can be used to fetch a method/sub
    return $self->{ name }->can($name)
        unless @_;
    
    # method($name => $code) or $method($name => $value) to define method
    my $code = shift;
    _debug("defining method: $self\::$name => $code\n") if $DEBUG;

    *{ $self->{name}.PKG.$name } = ref $code eq CODE
        ? $code
        : sub { $code };        # constant method returns value

    return $self;
}

sub methods {
    my $self = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $pkg  = $self->{ name };
    no strict REFS;

    while (my ($name, $code) = each %$args) {
        _debug("defining method: $self\::$name => $code\n") if $DEBUG;
        *{ $pkg.PKG.$name } 
            = ref $code eq CODE ? $code : sub { $code };
    }
    return $self;
}

sub slots {
    my ($self, $slots) = @_;
    my $args = @_ && ref $_[0] eq HASH ? shift : [ @_ ];
    my $pkg  = $self->{ name };
    no strict REFS;

    # slots can be a list of names or delimited string
    $slots = [ split(DELIMITER, $slots) ]
        unless ref $slots eq ARRAY;

    my $index = 0;
    foreach my $slot (@$slots) {
        my $i = $index++;     # new lexical variable to bind in closure
        *{ $pkg.PKG.$slot } = sub {
            return @_ > 1
                ? ($_[0]->[$i] = $_[1])
                :  $_[0]->[$i];
        };
    }
}

sub accessors {
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

sub mutators {
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

sub overload {
    my $self = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    _debug("overload on $self->{name} : { ", join(', ', %$args), " }\n") if $DEBUG;
    overload::OVERLOAD($self->{name}, %$args);
    return $self;
}

sub as_text {
    my ($self, $method) = @_;
    $self->overload( '""' => $method, fallback => 1 );
}

sub is_true {
    my ($self, $arg) = @_;
    my $method = 
        $arg eq FALSE ? \&FALSE :      # allow 0/1 as shortcut 
        $arg eq TRUE  ? \&TRUE  :
        $arg;
    $self->overload( bool => $method, fallback => 1 );
}
    

#-----------------------------------------------------------------------
# misc methods
#-----------------------------------------------------------------------

sub filesystem {
    my $self = shift;
    my $syms = @_ == 1 ? shift : { @_ };

    $syms = [ split(DELIMITER, $syms) ] 
        unless ref $syms eq ARRAY;

    _autoload($self->FILESYSTEM)->export(
        $self->{ name }, @$syms
    );
    
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
    _autoload($self->{ name });
    return $self;
}

sub maybe_load {
    my $self = shift;
    return eval { $self->load } || do {
        _debug("maybe_load($self) caught error: $@\n") if $DEBUG;
        die $@ if $@ && $@ !~ /^Can't locate .*? in \@INC/;
        0;
    }
}


#-----------------------------------------------------------------------
# methods for building Badger::Class subclasses
#-----------------------------------------------------------------------

sub uber {
    my ($self, $base) = @_;
    my $pkg = $self->{ name };
    $self->base($base);
    $pkg->UBER;
    return $self;
}

sub hooks {
    my $self  = shift;
    my $args  = @_ == 1 ? shift : { @_ };
    my $hooks = $self->var_default( HOOKS => { } );

    # split string into list ref
    $args = [ split(DELIMITER, $args) ] 
        unless ref $args;

    # map list ref to hash ref
    $args = {
        map { $_ => $_ }
        @$args
    } if ref $args eq ARRAY;
        
    croak("Invalid hooks specified: $args")
        unless ref $args eq HASH;
        
    _debug("merging $self->{ name } hooks: ", join(', ', keys %$args), "\n") if $DEBUG;

    @$hooks{ keys %$args } = values %$args;
    
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
    no strict   REFS;
    no warnings ONCE;
    
    unless ( $LOADED->{ $class }
#         || %{ $class.PKG } ) {            # not good enough
          || defined ${ $class.PKG.LOADED  } 
          || defined ${ $class.PKG.VERSION }
          || @{ $class.PKG.ISA }) {

        _debug("autoloading $class\n") if $DEBUG;
        $v = ${ $class.PKG.VERSION } ||= 0;
        local $SIG{__DIE__};
        eval "use $class";
#        _debug("autoload error: $@\n") if $DEBUG && $@;
        die $@ if $@;
#        _debug("autoloaded successfully\n") if $DEBUG;
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

    # composing a new module
    package Your::Module;
    
    use Badger::Class
        base        => 'Badger::Base',  # define base class(es)
        version     => 1.00,            # sets $VERSION
        debug       => 0,               # sets $DEBUG
        throws      => 'wobbler',       # sets $THROWS error type
        import      => 'class',         # import class() subroutine
        utils       => 'blessed params',# imports from Badger::Utils
        codec       => 'storable',      # imports from Badger::Codecs
        codecs      => 'base64 utf8'    # codecs do encode/decode
        constants   => 'TRUE FALSE',    # imports from Badger::Constants
        constant    => {                # define your own constants
            pi      => 3.14,
            e       => 2.718,
        },
        words       => 'yes no quit',   # define constant words
        accessors   => 'foo bar',       # create accessor methods
        mutators    => 'wiz bang',      # create mutator methods
        as_text     => 'text',          # auto-stringify via text() method
        is_true     => 1,               # overload boolean operator
        overload    => {                # overload other operators
            '>'     => 'more_than',
            '<'     => 'less_than',
        },
        vars        => {
            '$FOO'  => 'Hello World',   # defines $FOO package var
            '@BAR'  => [10,20,30],      # defines @BAR
            '%BAZ'  => {x=>10, y=>20},  # defines %BAZ
            # leading '$' is optional for scalar package vars
            WIZ     => 'Hello World',   # defines $WIZ as scalar value
            WAZ     => [10,20,30],      # defines $WAZ as list ref
            WOZ     => {a=>10,y=>20},   # defines $WOZ as hash ref
            WUZ     => sub { ... },     # defines $WUZ as code ref
        },
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

    # Other Badger::Class tricks
    use Badger::Class 'class';
    
    # compose a new class on the fly
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

=head1 DESCRIPTION

C<Badger::Class> is a class metaprogramming module. It provides methods for
defining, extending and manipulating object classes and related metadata in a
relatively clean and simple way.

Using the C<Badger::Class> module will automatically enable the C<strict> and
C<warnings> pragmata in your module (thx Moose!). No exceptions. No questions
asked.  No answers given. It's for your own good.

=head2 USING Badger::Class IMPORT HOOKS

C<Badger::Class> provides a number of import hooks that you can specify
when you C<use> the module.  These are mapped to C<Badger::Class> methods
that perform various tasks to help in the construction of object classes.

For example, instead of writing something like this:

    package Your::Module;
    
    use base qw( Exporter Class::Base Class::Accessor::Fast );
    use constant {
        name => 'Badger',
        foo  => 'Nuts',
        bar  => 'Berries',
    };
    use Scalar::Util 'blessed';
    
    our $VERSION   = 3.14;
    our $DEBUG     = 0 unless defined $DEBUG;
    our @EXPORTS   = qw( name );
    our @EXPORT_OK = qw( foo bar );
    
    __PACKAGE__->mk_accessors(qw(nuts berries));

You can write something like this:

    package Your::Module;
    
    use Badger::Class 
        base        => 'Badger::Base',
        version     => 3.14,
        debug       => 0,
        get_methods => 'nuts berries',
        utils       => 'blessed',
        constant    => {
            name => 'Badger',
            foo  => 'Nuts',
            bar  => 'Berries',
        },
        exports     => { 
            all => 'name',
            any => 'nuts berries',
        };

There are a number of benefits to this approach. First and foremost, it allows
you to forget about much of the messy detail typically involved in class
housekeeping and adopt a more declarative style of programming. You don't have
to worry about the details of exporting symbols, for example. Simply declare
what the module exports and leave it up to the corresponding C<Badger::Class>
method to make sure that the L<Badger::Exporter> module is added as a subclass
and the right package variables are defined. This makes life easier for you
and the code more robust by reducing the chances of you doing something silly.
Thus, the job gets done quicker and you get to go home early where you can be
as silly as you like in your own time.

Another benefit is that it brings a degree of consistency to your code. Having
I<more than one way to do it> is all well and good for the Perl community at
large. However, it's not so good when you're writing the boilerplate code for
a module and are forced to use five different ways (count 'em: subclassing,
import flags, imported subroutines, package variables and class methods) in
the space of ten lines of code.

C<Badger::Class> allows you to do away with all that and use a single, uniform
syntax to perform all (or most) of your class metaprogramming tasks. It allows
you to collect similar code in one place where it's easy to read (when you
want to) and easy to ignore (when you don't). Ask Schwern about the value of
skimmable code if you don't agree that it's a Good Thing[tm].

IMPORTANT: if you have a non-trivial class declaration then you should add
C<use strict> and C<use warnings> I<before> you C<use Badger::Class>. Although
C<Badger::Class> will enable them both in your module, the arguments passed to
C<Badger::Class> will be evaluated before C<strict> and C<warnings> get
enabled so any errors may go unreported. 

=head2 CLASS METAPROGRAMMING

The import hooks shown above are syntactic sugar. They're mapped to
C<Badger::Class> methods. You can call those methods yourself using the
importable C<class> subroutine. 

    package Your::Module;
    use Badger::Module 'class';     # import class subroutine

You can also specify this using the C<import> parameter. 

    use Badger::Class import => 'class';

The C<class> subroutine returns a C<Badger::Class> object for the
current package.  (NOTE: we use the term I<package> when we're talking
specifically about Perl's symbol tables - but the term is generally synonymous
with I<class>).  

A C<Badger::Class> object provides a number of methods that allow you to
modify the class.  For example, you can add base classes, generate accessor
and mutator methods, define exportable items, and so on.  

    class->version(3.14);           # define $VERSION
    class->base('Another::Class');  # add base class
    class->accessors('foo bar');    # generate accessors
    class->exports(                 # define exports
        all => '$X $Y',
    )

All the class metaprogramming methods return C<$self> so that you
can chain them together like this:

    class->version(3.14)
         ->base('Another::Class')
         ->accessors('foo bar')
         ->exports( all => '$X $Y' );

The above are the explicit equivalents of using the following import hooks.

    use Badger::Class
        version   => 3.14,
        base      => 'Another::Class';
        accessors => 'foo bar',
        exports   => {
            all   => '$X $Y',
        };

One important benefit of using import hooks is that the methods are called at
compile time. That means that any symbols defined by the hooks/methods will be
available immediately.  For example, the L<debug> hook and corresponding 
L<debug()> method defines a C<$DEBUG> variable (amongst other things).

    use Badger::Class
        debug => 0;
    
    # no need to declare 'our $DEBUG' - the above import hook did that
    print $DEBUG;           # 0

You can also use the class subroutine to modify remote classes, i.e. classes
other than the current one.

    class->('Existing::Class')->methods(
        wiz => sub {
            # new wiz() method for Existing::Class
        }
    );

You can construct entirely new classes on-the-fly.

    class('Amplifier')
        ->base('Badger::Base')
        ->constant( max_volume => 10 )
        ->methods( about => sub { 
              "This amp goes up to " . shift->max_volume 
          } );
    
    Amplifier->about;                   # This amp goes up to 10

And subclasses of your new subclasses.

    class('Nigels::Amplifier')
        ->base('Amplifier')
        ->constant( max_volume => 11 );
    
    Nigels::Amplifier->about;           # This amp goes up to 11

Being able to define new class on the fly using nothing more than a handful of
methods is really quite useful. You can take an existing class, subclass it,
tweak it, attach some custom methods, instantiate it and then call a method on
it, all in a single expression. You don't need to use any Perl statements or
keywords to get the job done, so there's no need to C<eval> any code (this
should make you feel warm and fuzzy in that special Badger place if
auto-generating classes is your thing).

=head2 CLASS INSPECTION

The C<Badger::Class> object provides a number of methods for inspecting
and manipulating the current class.  For example, there are methods to
set and get package variables for class.

    class->var( X => 10 );          # same as: $X = 10
    class->var('X');                # same as: $X

In this simple example, the effect is exactly the same as modifying the C<$X>
I<package> variable directly. However, this method (and related methods)
provides an abstraction of I<class> variables that works correctly with
respect to subclassing. That is, accessing a I<class> variable in a subclass
of C<Your::Module> will resolve to the I<package> variable in the subclass,
rather than the base class. If instead you write C<$X> then you'll always get
the variable in the base class package (which may be what you want, of
course).

A form of inheritance for class variables can be implemented using the 
L<any_var()> method.  This looks for a package variable in the current class
or in any of the base classes.

    class->any_var('X');            # $X with @ISA inheritance

This idiom is particularly useful to provide default values for a class that
you might want to re-define later in a subclass. We'll look at some examples
of that shortly.

=head2 SUBCLASSING Badger::Class

The L<Badger::Class> module can itself be subclassed, allowing you to create
more specialised class metaprogramming modules to suit your own needs. For a
simple example, you can create a class module for a particular project that
hooks into your own modules that define constants, utility functions, and so
on.

    # defining a Badger::Class subclass...
    package My::Class;
    
    # ...using Badger::Class, of course
    use Badger::Class
        uber     => 'Badger::Class',
        constant => {
            CONSTANTS => 'My::Constants',
            UTILS     => 'My::Utils',
        };

The trick here is to use the C<uber> hook instead of C<base>. This is a
special case that applies only when you're subclassing C<Badger::Base> (or
another module derived from C<Badger::Base>). In addition to adding
C<Badger::Class> (or whatever class module you specify) as a base class of the
current module, it also performs some extra magic to ensure that the
L<class()> and L<classes()> subroutines return objects of your new class (e.g.
C<My::Class>) instead of C<Badger::Class>. You don't need to worry too much
about the details. Just use C<uber> instead of C<base> when you're subclass a
C<Badger::Class> module and we'll take care of everything for you. See the
L<uber()> and L<UBER()> methods for further details.

Once your class module is defined, you can use it to generate new classes
for your application.

    # defining classes using your new class module
    package My::Example;
    
    use My::Class
        version   =>  2,                     # inherited Badger::Class options
        base      => 'My::Base',
        constants => 'black white blue',     # imported from My::Constants
        utils     => 'wibble frusset pouch'; # imported from My::Utils

You can easily create your own methods and corresponding import hooks to
implement whatever metaprogramming functionality you require for a 
particular project.  Here's a trivial example which defines a method to
set a C<$FOO> package variable in the target class.

    package My::Class;
    
    use Badger::Class
        uber  => 'Badger::Class',
        hooks => 'foo';
    
    sub foo {
        my ($self, $value) = @_;
        $self->var( FOO => $value );
    }

Now you can use your class module with the C<foo> import hook and it'll 
define the C<$FOO> package variable at compile time.

    package My::Example;
    
    use My::Class
        version =>  3,
        base    => 'My::Base',
        foo     => 'Default foo value';
    
    print $FOO;     # Default foo value

Here's a slightly more advanced example which sets the C<$FOO> package
variable as above and additionally generates a C<foo()> method in the target
class. The C<foo()> method being generated (not to be confused with the
C<foo()> method generating it) is a simple mutator method to get or set the
C<$this-E<gt>{foo}> item.  We use C<$this> to represent the object in our
target class that will have the the generated C<foo()> method called against
it to avoid confusion with the C<$self> reference which is the
C<Badger::Class> metaprogramming object.  If the method doesn't find a C<foo>
value set in C<$this> then it uses the default value defined in the C<$FOO>
package variable.

    package My::Class;
    
    use Badger::Class
        uber  => 'Badger::Class',
        hooks => 'foo';
    
    sub foo {                                   # metaprogramming method
        my ($self, $value) = @_;
        $self->var( FOO => $value );            # define $FOO pkg var
        $self->method(                          
            foo => sub {                        # generate foo() method
                my $this = shift;               # object in target class
                return @_
                    ? $this->{ foo } = shift    # set 
                    : $this->{ foo }            # get
                   || $this->var('FOO');        # default
            }
        );
    }

It is a little confusing at first to have methods in one class generating
methods in another, especially when they share the same name. However, it's
probably I<less> confusing than deliberating giving your generating and
generated method different names. The C<hook> mechanism shown above is
deliberately simple, but you can roll your own more extensive mechanism using
the L<Badger::Exporter> (see the L<exports> hook and L<exports()> method)
if you want to do something more advanced.

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

We won't complain if you accidentally put commas between the items, either
with or without whitespace following.  It's such a common "mistake" to make
(and one which is entirely unambiguous given that commas shouldn't ever be
part of a symbol or module name) so we treat it as officially supported
syntax.

    # this is OK
    use Badger::Class 'class,CLASS';

    # so is this
    use Badger::Class 'class, CLASS';

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

There's nothing special about the class name returned. It's just a plain text
string. This is currently implemented as a runtime subroutine but will
probably be changed at some point to be a compile-time constant subroutine.

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

So you're on ten here, all the way up, all the way up, all the way up,
you're on ten on your guitar. Where can you go from there? Where? Nowhere. 
Exactly. What we do is, if we need that extra push over the cliff, you know 
what we do?

    my $amp = Amplifier->new( max_volume => 11 );

Eleven. Exactly. One louder.

So far, so good. But what if we wanted to make this the default? Sure, we
could make ten louder and make that be the top number, or we could remember to
specify the C<max_volume> parameter each time we use it. But let's assume
we're working with temperamental artistes who will be too busy worrying about
the quality of the backstage catering to think about checking their volume
settings before they go on stage.

Thankfully we didn't hard-code the maximum volume but used the C<$MAX_VOLUME>
package variable instead. We can change it directly like this:

    $Amplifier::MAX_VOLUME = 11;

Or using the class L<var()> method (just to show you what the roundabout way
looks like):

    Amplifier->class->var( MAX_VOLUME => 11 );

Either way has the desired effect of changing the default maximum volume
setting without having to go and edit the source code of the module. 

The downside to this is that it is an all-encompassing change that will affect
all future instances of C<Amplifier> and any subclasses derived from it that
don't define their own C<max_volume> parameter explicitly.

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
scalar context) of C<Badger::Class> objects. As per L<class()>, a package name
or object reference should be passed as the first argument, either explicitly
or implicitly by calling it as an object method.

The first L<Badger::Class> object in the list returned represents the 
current class object, as would be returned by L<class()>.  Any further
items in the list are L<Badger::Class> objects representing all the base
classes of the object.  The order of base classes is determined by the 
L<heritage()> method which implements a simplified variant of the C3
method resolution algorithm. 

=head1 EXPORT HOOKS

NOTE: The terms C<export hook> and C<import hook> refer to the same thing
and can be used interchangeably.  We typically use C<export hook> from the
perspective of the exporting module, and C<import hook> from the perspective
of the importing module.

=head2 base

Allows you to define a base class or classes for the module.  Multiple 
values can be specified by reference to an array or as a single whitespace
delimited string.

    # single base class
    use Badger::Class
        base => 'Your::Base';

    # multiple base classes as list reference
    use Badger::Class
        base => ['My::Base', 'Your::Base'];

    # multiple base classes as single string
    use Badger::Class
        base => 'My::Base Your::Base';

If you accidentally put commas between the names in the string then we'll
silently ignore them instead of chastising you for it.  We know what you
mean.

    # commas are allowed, with or without whitespace afterwards
    use Badger::Class
        base => 'My::Base,Your::Base, Another::Base';

See the L<base()> method for further details.

=head2 mixin

This can be used to mixin subroutines, methods and/or data from another
module.  It works in a similar way to the regular import/export mechanism.

    package Your::Module;
    
    use Badger::Class
        mixin => 'Your::Mixin::Module';

You can specify multiple class using either a list reference or whitespace
delimiter string, as per C<base>.

    package Your::Module;
    
    use Badger::Class
        mixin => 'My::Mixin::Module Your::Mixin::Module';

The modules that you're mixing in should declare the methods that they
make available for mixing using the C<mixins> hook or C<mixins()> method.

See the L<mixin()> method and L<Badger::Mixin> for further details.

=head2 mixins

This is used to declare the symbols that can be mixed into another module.

    package Your::Mixin::Module;
    
    use Badger::Class
        mixins => '$NAME nuts berries';
    
    our $NAME = 'Badger';
    sub nuts    { return 'I like nuts' }
    sub berries { return 'I like berries' }

The C<$NAME> package variable, and C<nuts> and C<berries> subroutines will
be exported to any module that loads C<Your::Mixin::Module> as a mixin.

    package Your::Module;
    
    use Badger::Class
        mixin => 'Your::Mixin::Module';
    
    print $NAME;            # Badger
    print nuts();           # I like nuts
    print berries();        # I like berries

See the L<mixins()> method and L<Badger::Mixin> for further details.

=head2 version

This can be used to declare a version number for your module.  It defines
the C<$VERSION> package variable for you along with a C<VERSION> constant
subroutine that returns the same value.

    package Your::Module;
    
    use Badger::Class
        version => 3.14;
    
    print $VERSION;                 # 3.14
    print  VERSION;                 # 3.14
    
    package main;
    
    print $Your::Module::VERSION;   # 3.14
    print  Your::Module->VERSION;   # 3.14

See the L<version()> method for further details.

=head2 debug

This can be used to define a C<$DEBUG> package variable and C<debugging()>
subroutine that you can use to get or set its value.  It is typically used
in conjunction with the L<Badger::Base> L<debug()|Badger::Base/debug()> 
method like so:

    package Your::Module;
    
    use Badger::Class
        base  => 'Badger::Base',
        debug => 0;
    
    sub some_method {
        my $self = shift;
        $self->debug("Doing some_method()\n") if $DEBUG;
    }

See the L<debug()> method and L<Badger::Debug> for further details.

=head2 constant

This can be used to define constants in your module.

    package Your::Module;
    
    use Badger::Class
        constant => {
            name => 'Badger',
            food => 'Nuts and Berries',
        };
    
    print name;     # Badger
    print food;     # Nuts and Berries

In works just like the C<constant> module in defining constant subroutines
that return the specified value.  Perl resolves these at compile time so
they're very efficient.

Thanks to the wonders of Perl's loosely defined object system, you can call
these subroutines as object methods.  In this case they're not resolved at
compile time so they're no more efficient than regular method calls.  However
they do provide a useful mechanism for defining constants that can be 
redefined by subclasses.

    package Your::Amplifier;
    
    use Badger::Class
        constant => {
            max_volume => 10,
        };
    
    sub how_loud {
        my $self = shift;
        print "This amp goes up to ", $self->max_volume, "\n";
    }
    
    package main;
    
    Your::Amplifier->how_loud;  # This amp goes up to 10

This module can now be subclassed with a new C<max_volume> defined, like
so:

    package My::Amplifier;
    
    use Badger::Class
        base     => 'Your::Amplifier',
        constant => {
            max_volume => 11,
        };
        
    package main;
    
    My::Amplifier->how_loud;  # This amp goes up to 11

This provides an alternative to using package variables to define default
configuration values for a module. The only limitation is that you can't
change them once they're defined (although you can subclass the module and
define a new constant). This limitation may be a Good Thing in some cases.

See the L<constant()> method for further details.

=head2 constants

This can be used to import one or more symbols from the L<Badger::Constants>
module (or a constants module of your choosing if you subclass 
C<Badger::Class> as described above in L<SUBCLASSING Badger::Class>).

    use Badger::Class
        constants => 'ARRAY TRUE FALSE';
    
    sub is_this_an_array_ref {
        my $thingy = shift;
        return ref $thingy eq ARRAY ? TRUE : FALSE;
    }

See the L<constants()> method and L<Badger::Constants> for further details.

=head2 words

This is a short-cut for defining a number of single-word constants.

    use Badger::Class
        words => 'yes no';
    
    print yes;          # yes
    print no;           # no

Defining constants for frequently used words is a good thing because it
eliminates the chance of misspelling. If you misspell the name of a constant
then Perl will raise an error giving you immediate notification of the
problem.  On the other hand, if you misspell a word in a string, then the
chances are you won't find out until you next run your extensive test suite.
You do have an extensive test suite don't you?

    use Badger::Class
        words => 'inclusive exclusive';
    
    sub do_something_goodly {
        my ($self, $params) = @_;
        
        # PASS: Perl throws an error about 'incluvise' bareword
        if ($params->{ mode } eq incluvise) {
            ... 
        }
    }
    
    sub do_something_badly {
        my ($self, $params) = @_;
        
        # FAIL: Perl does what you tell it and has no way of 
        # spotting your typo
        if ($params->{ mode } eq 'incluvise') {
            ...
        }
    }

=head2 vars

This allows you to pre-define one or more package variables.  It works 
rather like the L<vars> module.

    use Badger::Class
        vars => '$FOO @BAR %BAZ';

It also allows you to provide values for variables, like so:

    use Badger::Class
        vars => {
            '$FOO' => 'Hello World',
            '@BAR' => [1.618,2.718,3.142],
            '%BAZ' => { x=>10, y=>20 },
        };

See the L<vars()> method for further information.

=head2 defaults

This is similar to the L<vars> hook in allowing you to define one or more
default values for scalar package variables. If a package variable is already
defined then it is not changed. It also defines the C<$DEFAULTS> package
variable (if not already defined) which contains a reference to the hash array
of default values specified.

    use Badger::Class
        defaults => {
            FOO => 10,
            BAR => 20,
        };

The above example is equivalent to the following code:

    our $FOO = 10 
        unless defined $FOO;
    our $BAR = 20 
        unless defined $BAR;
    our $DEFAULTS = { FOO => 10, BAR => 20 }
        unless defined $DEFAULTS;

It also imports a L<init_defaults()> method into your class that you can
call from your L<init()> method to initialise the object using named
parameters from the C<$config> hash or the default values defined in 
package variables.

    sub init {
        my ($self, $config) = @_;
        $self->init_defaults($config);
        return $self;
    }

This functionality is implemented by the L<Badger::Class::Defaults> 
module.  It should be considered experimental and subject to change.

=head2 aliases

This hook can be used to define aliases for the configuration parameters 
for your object class.  It stores them in a C<$ALIASES> package variable
and exports an C<init_aliases()> method which you can call from your own
C<init()> method.  This method will look for any aliases in the configuration
and update the hash to contain the definitive name for the item.

    use Badger::Class
        base      => 'Badger::Base',
        accessors => 'name user pass',
        aliases   => {
            name  => 'database',
            user  => 'username',
            pass  => 'password',
        };

    sub init {
        my ($self, $config) = @_;
        
        $self->init_aliases($config);
        
        for (qw( name user pass )) {
            $self->{ $_ } = $config->{ $_ };
        }
        return $self;
    }

This functionality is implemented by the L<Badger::Class::Aliases> 
module.  It should be considered experimental and subject to change.

=head2 exports 

This allows you to declare the symbols that your module can export.

    use Badger::Class
        exports => {
            all => 'foo bar',
            any => 'baz bam',
        };

See the L<exports()> method and L<Badger::Exporter> for further details.

=head2 throws

This can be used to set the C<$THROWS> package variable, as used by the
error handling mechanism in L<Badger::Base>.  

    package Your::Module;
    
    use Badger::Class
        base   => 'Badger::Base',
        throws => 'oh.noes';
    
    package main;
    
    eval {
        Your::Module->error('something has gone wrong');
    };
    print $@;       # oh.noes error - something has gone wrong

See the L<throws()> method and L<Badger::Base> for further information.

=head2 messages 

This can be used to define a C<$MESSAGES> package variable which references
a hash array of message formats for use with the
L<message()|Badger::Base/message()> and related methods in L<Badger::Base>

    package Your::Module;
    
    use Badger::Class
        base     => 'Badger::Base',
        messages => {
            request => 'can i haz %s?',
            denied  => 'FAIL: NO %s 4U!!!',
        };
    
    package main;
    
    print Your::Module->message( request => 'cheezburger' );
                    # can i haz cheezburger?
    
    Your::Module->warn_msg( denied => 'cheezburger' );
                    # FAIL: NO cheezburger 4U!!!

See the L<messages()> method and L<Badger::Base> for further details.

=head2 utils

This can be used to import symbols from the L<Badger::Utils> module. This
defines a number of its own utility functions, as well as providing access to
a number of functions from L<Scalar::Util>. (NOTE: only a limited number of
functions from Scalar::Util at present but I plan to make Badger::Utils
delegate to any symbols in any of the *::Util modules).

    use Badger::Class
        utils => 'blessed xprintf';
        
    sub welcome {
        my ($self, $name) = @_;
        
        $name = $name->get_name
            if blessed $name && $name->can('get_name');
        
        xprintf('Hello %s!', $name);
    }

See the L<utils()> method and L<Badger::Utils> for further details.

=head2 codec

This can be used to import a single codec from L<Badger::Codecs>.

    use Badger::Class
        codec => 'base64';
    
    my $encoded = encode('Some text');
    my $decoded = decode($encoded);

See the L<codec()> method and L<Badger::Codecs> for further details.

=head2 codecs 

This can be used to import multiple codecs from L<Badger::Codecs>.

    use Badger::Class
        codecs => 'base64 storable';
    
    my $encoded = encode_base64( encode_storable( $some_data ) );
    my $decoded = decode_storable( decode_base64( $encoded ) );

Codecs can be composed as a pipeline of other codecs. In the following
example, we define a C<session> codec which encodes data by first passing it
through the C<storable> codec (which uses the L<Storable> C<freeze()>
subroutine) and then onto the C<base64> codec (which uses the L<MIME::Base64>
C<encode_base64> subroutine).

    use Badger::Class
        codecs => {
            session => 'base64+storable',
        };
    
    my $encoded = encode_session( $some_data );
    my $decoded = decode_session( $encoded );

In case you were wondering about the significance of this particular codec
combination, the C<Storable> module can generate NULL characters in the 
output stream which will make some databases (e.g. Postgres) choke.  Adding
a second level of Base 64 encoding solves the problem.

See the L<codecs()> method and L<Badger::Codecs> for further details.

=head2 methods

This can be used to define methods for a class on-the-fly or patch existing
subroutines or methods into a class.

    use Badger::Class
        methods => {
            foo => sub { print "This is the foo method" },
            bar => \&Some::Other::Method,
        };

See the L<methods> method for further details.

=head2 slots

This can be used to define methods for list-based objects.

    use Badger::Class
        slots => 'size colour object';
    
    sub new {
        my ($class, @stuff) = @_;
        bless \@stuff, $class;
    }
    
    package main;
    my $bus = Badger::Test::Slots->new(qw(big red bus));
    print $bus->size;       # big
    print $bus->colour;     # red
    print $bus->object;     # bus

See the L<slots> method for further details.

=head2 accessors / get_methods

This can be used to define simple read-only accessor methods for a class.

    use Badger::Class
        accessors => 'foo bar';

You can use C<get_methods> as an alias for C<accessors> if you prefer.

    use Badger::Class
        get_methods => 'foo bar';

See the L<accessors()> method for further details.

=head2 mutators / set_methods

This can be used to define simple read/write mutator methods for a class.

    use Badger::Class
        mutators => 'foo bar';

You can use C<set_methods> as an alias for C<mutators> if you prefer.

    use Badger::Class
        set_methods => 'foo bar';

See the L<mutators()> method for further details.

=head2 overload

This can be used as a shortcut to the C<overload> module to overload
operators for your class.

    use Badger::Class
        overload => {
            '""'     => \&text,
            bool     => sub { 1 },
            fallback => 1,
        };

=head2 as_text

This is a shortcut to the C<overload> module. It can be used to define an
auto-stringification method that generates a text representation of your
object.  The method can be specified by name or as a code reference.

    use Badger::Class
        as_text => 'your_text_method';
        
    sub your_text_method {
        my $self = shift;
        # your code
    }

=head2 is_true

This is a shortcut to the C<overload> module. It can be used to define an
method that is used for boolean truth comparisons. This can be useful in
conjunction with the L<as_text> hook to ensure that an object reference always
evaluates true, even if the auto-stringification method returns a string that
Perl considers false (e.g. an empty string or C<0>).

    use Badger::Class
        as_text => 'your_text_method',
        is_true => sub { 1 };           # always true

The method can be specified as a method name or code reference.  For simple
false/true values you can also specify C<0> or C<1> and leave it up to 
C<Badger::Class> to alias it to an appropriate subroutine.

    use Badger::Class
        as_text => 'your_text_method',
        is_true => 1;                   # always true

=head2 filesystem

This can be used to load and import symbols from the L<Badger::Filesystem>
module.

    use Badger::Class
        filesystem => 'Dir File';
    
    my $dir = Dir('/path/to/dir');

See the L<filesystem()> method for further details.

=head2 uber

This is a special case of the L<base> hook which should be used when 
subclassing a C<Badger::Class> class. 

    package Your::Class;
    
    use Badger::Class
        uber => 'Badger::Class';

See the L<uber()> method for further details.

=head2 hooks

This can be used by C<Badger::Class> subclasses to define their own
import hooks.

    package Your::Class;
    
    use Badger::Class
        uber  => 'Badger::Class',
        hooks => 'foo bar';

See the L<hooks()> method for further details.

=head1 METHODS

=head2 new($package)

Constructor method for a C<Badger::Class> object.  You shouldn't ever
need to call this method directly.  Use the L<class()> subroutine instead.

=head2 name() / pkg()

Returns the class (i.e. package) name.

    print class->name;          # Your::Module

This method is called automatically whenever a C<Badger::Class> object
is stringified.

    print class;                # Your::Module

The C<pkg()> method is an alias for C<name()> for those occasions when it
reads better (for an entirely subjective definition of "better").

    print class->pkg;           # Your::Module
    class->pkg->new;            # Your::Module->new

=head2 parents()

Returns the package names of the immediate parents (base classes) of an object
class.

=head2 heritage()

The heritage() method returns a list of C<Badger::Class> objects representing
each class in the inheritance chain, starting with the current class and
continuing up through its superclasses.

It uses a simplified version of the C3 method resolution algorithm.  See
L<IMPLEMENTATION NOTES> for further details if you're interested in that
kind of thing.

=head2 id()

This method returns a short string used to identify the object class. This is
typically used for error reporting purposes if the object doesn't explicitly
define an error type (see the L<throws|Badger::Base/throws()> configuration
option and L<$THROWS|Badger::Base/$THROWS> package variable in
L<Badger::Base>).

It generates a lower case dotted representation of the class name, with the
common base part removed (C<Badger::> by default). For example a
C<Badger::Example> module would return C<example> as an identifier, and
C<Badger::Foo::Bar> would return C<foo.bar>.

=head2 base_id()

This method returns C<Badger> by default.  It is used by the L<id()>
method to determine the common base part of a module name to remove
when generating an identifer for error reporting.

=head2 instance()

Method to create an instance of an object class.  Delegates to the C<new()>
method for the class.

=head2 loaded()

Returns true or false to indicate if the module class is loaded or not.

=head2 load()

Loads the module class if not already loaded.

=head2 maybe_load()

A wrapper around L<load()> which catches any errors raised by the module
not being found.  It returns the module name if it was loaded correctly,
a false value (0) if not.  If the module was found but contained syntax
errors then these will be throw as errors as usual.

=head1 CLASS VARIABLE METHODS

These methods can be used to access and manipulate the symbol table for a
class, to get and set regular package variables, and to work with inherited
package variables (or I<class variables> as we refer to them when used this
way).

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

    my $xvar = class->scalar('X');      # like: $xvar = $X;

=head2 array()

Returns the ARRAY values for a name in the symbol table.

    my @xvar = class->array('X');       # like: @xvar = @X;

=head2 hash()

Returns the HASH values for a name in the symbol table.

    my %xvar = class->hash('X');        # like: %xvar = %X;

=head2 var($name,$value)

Method to get or set a scalar package variable.  The leading C<$> sigil
is not required.

    class->var( X => 10 );              # like: $X = 10
    class->var('X');                    # like: $X

=head2 var_default($name,$default)

Method to get a scalar package variable.  An optional default value can
be provided in case the package variable is undefined.

    class->var_default( X => 10 );      # like: $X || 10

=head2 any_var($name)

Get the value of a scalar package variable in the current class or those of
any of the base classes.

    class->any_var('X');

=head2 any_var_in($names)

Looks in the current package and those of the base classes for any of the
scalar variables listed in C<$names>. The first defined value is returned, or
undef if none are defined.

Multiple arguments can be specified as a list, a reference to a list or 
a single string of whitespace delimiter variable names (without the leading
C<$> sigil).

    class->any_var_in('X Y Z');
    class->any_var_in('X', 'Y', 'Z');
    class->any_var_in(['X', 'Y', 'Z']);

=head2 all_vars($name)

Get all defined values of a package variable in the current package
or any of the base classes.  Returns a list of values in list context,
or a reference to a list of values in scalar context.

    @values = class->all_vars('X');     # list context returns list
    $values = class->all_vars('X');     # scalar context returns list ref

=head2 list_vars($name)

This method return a reference to a list containing all the values defined
in a particular class variable for the current class and all base classes.
Package variables that reference a list will have their contents merged in.

    package A;
    our $THINGS = ['Foo', 'Bar'];

    package B;
    our $THINGS = ['Baz', 'Bam'];

    package C;
    our $THINGS = 'Wibble';

    package main;
    C->list_vars('THINGS');     # ['Wibble', 'Baz', 'Bam', 'Foo', 'Bar']

Additional arguments may be passed which are merged into the start of the
list. 

    B->list_vars('THINGS', 10, 20); 
                                # [10, 20, 'Baz', 'Bam', 'Foo', 'Bar']

    B->list_vars('THINGS', [30, 40]); 
                                # [30, 40, 'Baz', 'Bam', 'Foo', 'Bar']

This is typically used in object initialisation methods to merge any values
specified as configuration parameters with those defined in package variables.
These "local" configuration value are assumed to take precedence over package
variables. Hence they appear at the start of the list rather than the end.

    sub init {
        my ($self, $config) = @_;
        
        $self->{ things } = $self->class->list_vars( 
            THINGS => $config->{ things } 
        );
    }

An additional list reference of C<things> can now be passed to the 
constructor method.

    my $b = B->new( things => [10,20] );

=head2 hash_vars($name)

Works like L<list_vars()> but merges references to hash arrays into a 
single hash array.  A warning will be raised if any values are defined in
the relevant package variables that don't reference hash arrays.

    package A;
    our $THINGS = {
        foo => 'Foo'
        bar => 'Bar',
    };
    
    package B;
    our $THINGS = {
        bar => 'New Bar',
        baz => 'Baz',
    };
    
    package main;
    B->hash_vars('THINGS');

The call to C<hash_vars('THINGS')> in the example above will return a
reference to a hash array containing the following items:

    { 
        foo => 'Foo', 
        bar => 'New Bar', 
        baz => 'Baz',
    }

Note how the value for C<bar> is taken from the C<B> package rather than 
the C<A> package because C<B> is the more specialised class (i.e. closer
in terms of the inheritance tree).

Additional arguments may be passed which are merged into the hash array. A
common idiom is to use this in an object constructor or initialisation method
to merge the values in package variables with any specified as configuration
parameters.  Values passed as argument will have precedence over those 
defined in package variables.

    sub init {
        my ($self, $config) = @_;
        
        $self->{ things } = $self->class->hash_vars( 
            THINGS => $config->{ things } 
        );
    }

An additional hash reference of C<things> can now be passed to the 
constructor method.

    my $b = B->new( things => { 
        foo => 'New Foo',
        bam => 'Bam',
    } );

The composite hash returned by C<hash_vars> will contain:

    { 
        foo => 'New Foo',
        bar => 'New Bar', 
        baz => 'Baz',
        bam => 'Bam',
    }

=head2 hash_value($name,$key,$default)

Looks for a specific C<$key> in a hash array referenced by the C<$name>
package variable in the current class or any base classes.  Returns the 
first value found or the C<$default> value (which can be undefined) if
no relevant entries are found.

    package A;
    our $THINGS = {
        foo => 'Foo'
        bar => 'Bar',
    };
    
    package B;
    our $THINGS = {
        bar => 'New Bar',
        baz => 'Baz',
    };
    
    package main;
    print B->hash_value( THINGS => 'foo' );     # Foo
    print B->hash_value( THINGS => 'bar' );     # New Bar
    print B->hash_value( THINGS => 'baz' );     # Baz

=head1 CLASS CONFIGURATION METHODS

These methods can be used to perform various class metaprogramming tasks.
They all return a C<$self> reference allowing them to be chained together,
e.g.

    $object->base($b)->version($v)->debug($d);

=head2 base(\@classes)

Method to define one or more base classes for a module.  
It effectively does the same thing as C<base.pm> in adding the specified
classes to the C<@ISA> package variable;

    class->base('Your::Base::Module');

This method can be called via the L<base> import hook.

    use Badger::Class
        base => 'Your::Base::Module';

=head2 version($n)

Method to define the version number for a class.  This has the effect
of setting C<$VERSION> in the target class.  It also defines a C<VERSION>
method which returns the version number.

    package Badger::Example;
    use Badger::Class 'class';
    class->version(3.14);
    
    package main;
    print $Badger::Example::VERSION;        # 3.14
    print  Badger::Example->VERSION;        # 3.14

This method can be called via the L<version> import hook.

    use Badger::Class
        version => 3.14;

=head2 debug($flag)

This method can be used to enable debugging controls for a class.  It 
defines a C<$DEBUG> package variable set to the value of C<$flag> and 
a C<debugging()> method which can be used to enable or disable debugging.

The C<debugging()> method generated simply calls back to the C<Badger::Class>
L<debugging()> method.

The C<debug()> method can be called via the L<debug> import hook.

    use Badger::Class
        debug => 0;

The immediate benefit of using an import hook is that the definition of
C<$DEBUG> happens at compile time. That means you can safely reference
L<$DEBUG> from that point forwards without Perl warning that you're using an
undefined variable. 

    use Badger::Class
        debug => 0;
        
    sub do_something {
        my $self = shift;
        $self->debug("Doing something\n") if $DEBUG;
    }

=head2 debugging($flag)

The method can be used to get or set the value of the C<$DEBUG> package
variable for the class.  Here's how you would typically use it.

    package Your::Module;
    
    use Badger::Class
        debug => 0;         # debugging off by default
        
    sub do_something {
        my $self = shift;
        $self->debug("Doing something\n") if $DEBUG;
    }

    package main;
    
    my $obj = Your::Module->new;
    $obj->debugging(1);     # sets $DEBUG to 1
    $obj->do_something;     # generates debugging message

=head2 constants($names)

This method can be used to import one or more symbols from the
L<Badger::Constants> module (or a constants module of your choosing if you
subclass C<Badger::Class> as described above in L<SUBCLASSING Badger::Class>).

    class->constants('ARRAY TRUE');

Although you I<can> call it manually as a method from inside your code, 
you'll probably want to access it via the L<constants> import hook so that
the symbols are imported at compile time.

    use Badger::Class
        constants => 'ARRAY TRUE FALSE';
    
    sub is_this_an_array_ref {
        my $thingy = shift;
        return ref $thingy eq ARRAY ? TRUE : FALSE;
    }

See L<Badger::Constants> for further details.

=head2 constant(\%constants)

A method to define constants, just like the C<constant.pm> module.  As
with L<constants()>, you probably want to call this via the L<constant>
import hook so that the constants are defined at compile time.

    package Your::Module;
    
    use Badger::Class
        constant => {
            name => 'Badger',
            food => 'Nuts and Berries',
        };

=head2 words($words)

This method is used to define a set of constant words.  As with L<constants()>
and L<constant()>, it generally only make sense to do this via the 
L<words> import hook.

    use Badger::Class
        words => 'yes no';
    
    print yes;          # yes
    print no;           # no

=head2 vars($vars)

This allows you to pre-declare one or more package variables. This is usually
called via the corresponding L<vars> import hook.

    use Badger::Class
        vars => '$FOO @BAR %BAZ';   

In the simple case, it works just like the C<vars.pm> module in pre-declaring
the variables named. 

Unlike C<vars.pm>, this method will I<only> define scalar, list and hash
package variables (e.g. C<$SOMETHING>, C<@SOMETHING> or C<%SOMETHING>). If you
want to define a subroutine/method then use the L<methods> import hook or
L<methods()> method. If you want to define a glob reference then you're
already operating in I<Wizard Mode> and you don't need our help.

If you don't specify a leading sigil (i.e. C<$>, C<@> or C<%>) then it will
default to C<$> and create a scalar variable.

    use Badger::Class
        vars => 'FOO BAR BAZ';      # declares $FOO, $BAR and $BAZ

You can also use a reference to a hash array to define values for variables.

    use Badger::Class
        vars => {                           # Equivalent code:
            '$FOO' => 42,                   #   our $FOO = 25
            '@WIZ' => [100, 200, 300],      #   our @WIZ = (100, 200, 300)
            '%WOZ' => {ping => 'pong'},     #   our %QOZ = (ping => 'pong')
        };

Scalar package variables can be assigned any scalar value or a reference to
some other data type. Again, the leading C<$> is optional on the variable
names. Note the difference in the equivalent code - this time we end up with
scalar variables and references exclusively.

    use Badger::Class
        vars => {                           # Equivalent code:
            FOO => 42,                      #   our $FOO = 42
            BAR => [100, 200, 300],         #   our $BAR = [100, 200, 300]
            BAZ => {ping => 'pong'},        #   our $BAZ = {ping => 'pong'}
            HAI => sub {                    #   our $HAI = sub { ... }
                'Hello ' . (shift || 'World') 
            },
        };

You can also assign any kind of data to a package list variable.  If it's
not already a list reference then the value will be treated as a single
item list.

    use Badger::Class
        vars => {                           # Equivalent code:
            '@FOO' => 42,                   #   our @FOO = (42)
        };

=head2 default($vars)

This method implements the functionality for the L<default> export hook. At
present it only works with scalar package variables.

    use Badger::Class
        default => {                        # Equivalent code:
            ANSWER => 42,                   #   our $ANSWER = 42 
        };                                  #       unless defined $ANSWER

=head2 exports($symbols)

This method is used to declare what symbols the module can export.  It
delegates to the L<exports()|Badger::Exporter/export()> method in 
L<Badger::Exporter>.

You can provide a reference to a hash array or a list of named parameters.
Each name should be one of C<any>, C<all>, C<tags>, C<hooks> or C<fail>.

    # list of named parameters
    class->exports( any => '$FOO $BAR $BAZ' );

    # reference to hash of named parameters
    class->exports({
        any  => '$FOO $BAR $BAZ',
        all  => 'wiz bang',
        tags => {
            wam => '$ONE @TWO',
            bam => '$THREE %FOUR',
        },
        hooks => {
            ding => sub { ... },
            dong => sub { ... },
        },
    });

=head2 throws($type)

This methods sets the C<$THROWS> package variable in the target class to
the value passed as an argument.  This is used by the L<Badger::Base>
error handling mechanism.  See the L<throws()|Badger::Base/throws()> method
for further details

=head2 messages(\%messages)

This method can be used to update the C<$MESSAGES> package variable in the 
target class to include the messages passed as arguments, either as a list
or reference to a hash array of named paramters.

    # define new class message
    class->messages( careful => 'Careful with that %s %s!' );
    
    # method which warns; Careful with that axe Eugene!
    sub some_method {
        my $self = shift;
        $self->warning_msg( careful => axe => 'Eugene' );
    }

The new messages will be merged into any existing C<$MESSAGES> hash reference
or a new one will be created.

=head2 utils($imports)

This method can be use to load symbols from L<Badger::Utils>. As with other
methods that load compile-time constants, it should generally be called via
the L<utils> import hook.

=head2 codecs($names)

This method can be use to load codecs from L<Badger::Codecs>. As with other
methods that load compile-time constants, it should generally be called via
the L<codecs> import hook.

See L<Badger::Codecs> for further information.

=head2 codec($name)

A method to load a single codec from L<Badger::Codecs>.  As with L<codecs()>,
it should be called via the L<code> import hook.

See L<Badger::Codecs> for further information.

=head2 method($name,$code)

This method can be used to get or set a method in the target class.  If a
single argument is specified then it behaves just like the inbuilt C<can()>
method (which it calls).  It returns a CODE reference for the method either
from the class itself or one of its subclasses, or undef if the method is
not implemented by the target class.

    my $method = class->method('foo');

The method can be called with two arguments to define a new method in the
target class.

    class->method( 
        foo => sub { ... }, 
    )       

=head2 methods(\%methods)

This method can be used to define new methods in the target class.

    class->methods( 
        foo => sub { ... }, 
        bar => sub { ... },
    )       

=head2 accessors($name) / get_methods($name)

This method can be used to generate accessor (read-only) methods for a class.
You can pass a list, reference to a list, or a whitespace delimited string
of method names as arguments.  

    # these all do the same thing
    class->accessors('foo bar');
    class->accessors('foo', 'bar');
    class->accessors(['foo', 'bar']);

A method will be generated in the target class for each that returns the
object member data of the same name. The code generated for each method is
equivalent to this:

    sub foo {
        $_[0]->{ foo };
    }

=head2 mutators / set_methods

This method can be used to generate mutator (read/write) methods for a class.
You can pass a list, reference to a list, or a whitespace delimited string
of method names as arguments.  

    # these all do the same thing
    class->accessors('foo bar');
    class->accessors('foo', 'bar');
    class->accessors(['foo', 'bar']);

A method will be generated in the target class for each that returns the
object member data of the same name. If an argument is passed then the 
member data is updated and the new value returned.

The code generated is equivalent to this:

    sub foo {
        @_ == 2 
            ? ($_[0]->{ foo } = $_[1])
            :  $_[0]->{ foo };
    }

Ugly isn't it?   But of course you wouldn't ever write it like that, being 
a conscientious Perl programmer concerned about the future readability and
maintainability of your code.  Instead you might write it something like
this:

    sub foo {
        my $self = shift;
        if (@_) {
            # an argument implies a set
            return ($self->{ foo } = shift);
        }
        else {
            # no argument implies a get
            return $self->{ foo };
        }
    }

Or perhaps like this:

    sub foo {
        my $self = shift;
        # update value if an argument was passed
        $self->{ foo } = shift if @_;
        return $self->{ foo };
    }

Or even like this (my personal favourite):

    sub foo {
        my $self = shift;
        return @_
            ? ($self->{ foo } = shift)
            :  $self->{ foo };
    }

Whichever way you do it is a waste of time, both for you and anyone who has to
read your code at a later. Seriously, give it up! Let us generate the methods
for you. We'll not only save you the effort of typing pages of code that
no-one will ever read (or want to read), but we'll also generate the most
efficient code for you. The kind that you wouldn't normally want to handle by
yourself.

So in summary, using this method will keep your code clean, your code 
efficient, and will free up the rest of the afternoon so you can go out 
skateboarding.  Tell your boss I said it was OK.

=head2 slots($names)

This method can be used to define methods for list-based object classes.
A list, reference to a list, or string of whitespace delimited method
names should be passed an argument(s).  A method will be generated for
each item specified.  The first method will reference the first (0th) item
in the list, the second method will reference the second (1st), and so on.

    package Badger::Example;
    
    use Badger::Class
        slots => 'size colour object';
    
    sub new {
        my ($class, @stuff) = @_;
        bless \@stuff, $class;
    }

The above example defines a simple list-based object class with three
slots: C<size>, C<colour> and C<object>.  You can use it like this:

    my $bus = Badger::Test::Slots->new(qw( big red bus ));
    
    print $bus->size;       # big
    print $bus->colour;     # red
    print $bus->object;     # bus

The methods generated are mutators.  That is, you can pass an argument
to update the slot value.

    $bus->size('large');

=head2 overload(\%operators)

This method provides a simple shortcut to the C<overload> core module to
implement the L<overload> import hook.

=head2 as_text($method)

This method provides a simple wrapper around the L<overload()> method to
implement the L<as_text> import hook.

=head2 is_true($method)

This method provides a simple wrapper around the L<overload()> method to
implement the L<is_true> import hook.

=head2 filesystem(@symbols)

This method can be used to load symbols from L<Badger::Filesystem>.  It
should generally be used via the L<filesystem> hook.

=head2 uber($class)

This method is used when creating a subclass of the C<Badger::Class> module
(or another subclass of it). It does the same thing as the L<base()> module in
adding the C<$class> to the C<@ISA> package variable. It then calls the
internal L<UBER()> method to generate the L<class()> and L<classes()>
subroutines in the subclass.

=head2 hooks($names)

This can be used by C<Badger::Class> subclasses to define their own
import hooks.  For example, an import hook to set a C<$FOO> package
variable could be implemented like this.

    package Your::Class;
    
    use Badger::Class
        uber  => 'Badger::Class',
        hooks => 'foo';
    
    sub foo {
        my ($self, $value) = @_;
        $self->var( FOO => $value );
    }

=head1 INTERNAL METHODS

=head2 UBER

This method generates the L<class()> and L<classes()> subroutines that return
C<Badger::Class> objects when called. You shouldn't ever need to call this
method directly. It is automatically called once when the C<Badger::Class>
module is first loaded. It is also called by the L<uber()> method to generate
the L<class()> and L<classes()> methods in modules subclassed from
C<Badger::Class> (e.g. C<Your::Class>). In this case, the generated
subroutines will return object instances of the subclass (i.e. C<Your::Class>)
instead of C<Badger::Class>.

=head1 INTERNAL CONSTANTS

The following constants are defined for internal use.  You can redefine
them in subclasses to hook in different delegate modules, as shown in 
L<SUBCLASSING Badger::Class>.

=head2 CODECS

The name of the codecs module, as used by the L<codecs()> method: 
C<Badger::Codecs>

=head2 CONSTANTS

The name of the constants method, as used by the L<constants()> metho:
C<Badger::Constants>

=head2 EXPORTER

The name of the exporter module, as used by the L<exports()> method:
C<Badger::Exporter>

=head2 FILESYSTEM

The name of the filesystem module, as used by the L<filesystem()> method:
C<Badger::Filesystem>

=head2 MIXIN

The name of the base class mixin module, as used by the L<mixin()> method:
C<Badger::Mixin>

=head2 UTILS

The name of the utilities module, as used by the L<utils()> method:
C<Badger::Utils>

=head1 REALLY INTERNAL CONSTANTS 

These constants are I<really> internal. You really don't need to know about
them. In fact, even I<I> don't need to know about them. I'm only documenting
then to keep L<Pod::Coverage> quiet.

=head2 VERSION

This constant defines the name of the variable that the L<version()> method
updates.  Guess what?  It's set to C<VERSION>.

=head2 LOADED

This is the name of a variable that the C<Badger::Class> method uses to 
assist in autoloading modules.  The default value is C<BADGER_LOADED>.
Thus, C<Badger::Class> will define a C<$BADGER_LOADED> package variable 
in your module to indicate that it was loaded by Badger.

=head1 IMPLEMENTATION NOTES

=head2 C3 Method Resolution and the heritage() Method

To determine the correct resolution order for superclasses, the L<heritage()>
method implements a simplified version of the C3 method resolution algorithm.
See:

=over

=item *

L<http://www.python.org/2.3/mro.html> for a good introduction to the subject.

=item *

L<Algorithm::C3> on CPAN for an implementation in Perl

=item *

L<http://www.webcom.com/haahr/dylan/linearization-oopsla96.html> for the
original Dylan paper.

=back

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
