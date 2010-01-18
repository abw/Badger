package My::Class;

use Badger::Class
    uber  => 'Badger::Class',
    debug => 0,
    hooks => 'fields';

sub fields{
    my ($self, $value) = @_;
    $self->debug("adding mutator fields: $value") if DEBUG;
    $self->mutators($value);
}

1;
