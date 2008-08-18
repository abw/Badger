# used by t/core/factory.t

package My::Wodget;

use Badger::Class
    version     => 1,
    base        => 'Badger::Base',
    get_methods => 'name';

sub init {
    my ($self, $config) = @_;
    $self->{ name } = $config->{ name };
    return $self;
}

1;
