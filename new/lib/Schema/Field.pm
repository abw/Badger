#========================================================================
#
# Badger::Schema::Field
#
# DESCRIPTION
#   Base class schema field.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Schema::Field;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base';
#    import    => 'class',
#    constants => 'HASH ARRAY',
#    constant  => {
#        DEFAULT_TYPE => 'text',
#    };

sub init {
    my ($self, $config) = @_;
    $self->{ name } = $config->{ 
    return $self;
}


1;
