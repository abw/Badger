#========================================================================
#
# Badger::Class::Defaults
#
# DESCRIPTION
#   Mixin module implementing functionality for defining defaults for
#   a class and initialising an object from them.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Class::Defaults;

use Carp;
use Badger::Debug ':dump';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Exporter',
    import    => 'class CLASS',
    words     => 'DEFAULTS',
    constants => 'PKG REFS HASH',
    constant  => {
        INIT_METHOD => 'init_defaults',
    };

sub export {
    my $class    = shift;
    my $target   = shift;
    my $defaults = @_ == 1 ? shift : { @_ };
    my ($key, $uckey);

    croak("Invalid defaults specified: $defaults")
        unless ref $defaults eq HASH;

    no strict REFS;
    
    foreach $key (keys %$defaults) {
        $uckey = uc $key;
        
        # if the package variable is already defined, we use that value
        # otherwise, create a new pacakge variable with the default value.
        if (defined ${ $target.PKG.$uckey }) {
            # alias ${...} into *{...} to make variable visible
            *{ $target.PKG.$uckey } = \${ $target.PKG.$uckey };
        }
        else {
            my $value = $defaults->{ $key };
            *{ $target.PKG.$uckey } = \$value
        }
    }
    *{ $target.PKG.DEFAULTS } = \$defaults
        unless defined ${ $target.PKG.DEFAULTS };

    # calling can() allows a subclass to redefine init_default() 
    *{ $target.PKG.INIT_METHOD } = $class->can(INIT_METHOD);
}

sub init_defaults {
    my ($self, $config) = @_;
    my $class = class($self);

    $self->debug("init_defaults(", CLASS->dump_data_inline($config), ')') if DEBUG;
    
    # Set values from $config or use the default values in package variables
    # created by the 'defaults' class hook.  We use the keys in $DEFAULTS to
    # tell us what to look for, but look for values in package variables
    # rather than using those in the $DEFAULTS hash.  This is to allow a
    # user to pre-defined the package vars to some value other than the
    # default.  It also make inheritance work (i.e. a subclass can define
    # a different $CACHE, for example)
    my $defaults = $class->hash_vars(DEFAULTS);
    CLASS->debug('$DEFAULTS: ', CLASS->dump_data_inline($defaults)) if DEBUG;
    
    foreach my $key (keys %$defaults) {
        $self->{ $key } =
            defined $config->{ $key }
                  ? $config->{ $key }
                  : $class->any_var(uc $key);
        $self->{ $key } = $defaults->{ $key }
            unless defined $self->{ $key };
        CLASS->debug("default: $key => $self->{ $key }\n") if DEBUG;
    }
    
    return $self;
}
    
1;
