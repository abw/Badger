package My::Class;

use Badger::Class
    uber     => 'Badger::Class',
    debug    => 0,
    hooks    => 'fields',
    constant => {
        BASE => 'Badger::Base',
    };

sub fields{
    my ($self, $value) = @_;
    $self->debug("defining fields: $value") if DEBUG;
    $self->base( $self->BASE );
    $self->mutators($value);
    $self->config($value);
    $self->init_method('configure');
}

1;
