package My::Class;

use Badger::Class
    version  => 3.14,
    uber     => 'Badger::Class',
    hooks    => 'wibble wobble',
    constant => {
        CONSTANTS => 'My::Constants',
    };

sub wibble {
    my ($self, $value) = @_;
    $self->method( wibble => sub { "wibble: $value" } );
}

sub wobble {
    my ($self, $value) = @_;
    $self->method( wobble => sub { "wobble: $value" } );
}

1;
