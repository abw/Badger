#========================================================================
#
# Badger::Schema::Fields
#
# DESCRIPTION
#   Factory for locating and instantiating Badger::Schema::Field objects.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Schema::Fields;

use Badger::Factory::Class
    version   => 0.01,
    debug     => 0,
    item      => 'field',
    path      => 'Badger::Schema::Field BadgerX::Schema::Field',
    constants => 'HASH',
    constant  => {
        DEFAULT_TYPE => 'text',
    };

sub type_args {
    my $self = shift;
    my $args = @_ == 1 && ref $_[0] eq HASH ? shift : { @_ };
    my $type = $args->{ type } || $self->DEFAULT_TYPE;
    return ($type, $args);
}

1;
