package My::Wobble;

use Badger::Class
    debug    => 0,
    base     => 'Badger::Base',
    constant => {
        name => 'WOBBLE',
    };

sub init {
    my ($self, $config) = @_;
    $self->debug("My::Wobble init: ", $self->dump_data($config)) if DEBUG;
    return $self;
}


1;

