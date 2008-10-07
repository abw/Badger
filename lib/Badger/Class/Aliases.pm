#========================================================================
#
# Badger::Class::Aliases
#
# DESCRIPTION
#   Class mixin module for adding code onto a class to provide aliases 
#   for configuration parameters and the like.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Class::Aliases;

use Carp;
use Badger::Debug ':dump';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Exporter Badger::Base',
    import    => 'class CLASS',
    words     => 'ALIASES',
    constants => 'HASH',
    constant  => {
        INIT_METHOD => 'init_aliases',
    };

sub export {
    my $class   = shift;
    my $target  = shift;
    my $aliases = @_ == 1 ? shift : { @_ };

    croak("Invalid defaults specified: $aliases")
        unless ref $aliases eq HASH;
    
    $class->export_symbol(
        $target,
        ALIASES,
        \$aliases
    );
    
    $class->export_symbol(
        $target, 
        INIT_METHOD, 
        $class->can(INIT_METHOD)    # subclass might redefine method
    );
}

sub init_aliases {
    my ($self, $config) = @_;
    my $class = class($self);

    $self->debug("init_aliases(", CLASS->dump_data_inline($config), ')') if DEBUG;
    
    my $aliases = $class->hash_vars(ALIASES);
    CLASS->debug('$ALIASES: ', CLASS->dump_data_inline($aliases)) if DEBUG;
    
    while (my ($key, $alias) = each %$aliases) {
        if (defined $config->{ $key }) {
            CLASS->warn("Both $key and $alias are defined, using $key: $config->{ $key }\n")
                if defined $config->{ $alias };
        }
        else {
            $config->{ $key } = $config->{ $alias };
        }
    }
    
    return $self;
}
    
1;
