package My::Wibble;

use Badger::Class
    debug => 0,
    base  => 'Badger::Base';

sub init {
    my ($self, $config) = @_;
    $self->debug("My::Wibble init: ", $self->dump_data($config)) if DEBUG;
    return $self;
}

1;

