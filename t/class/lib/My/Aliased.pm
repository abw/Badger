package My::Aliased;

use Badger::Class
    debug    => 0,
    base     => 'Badger::Base',
    alias    => {
        init => \&init_this,
        foo  => \&bar,
    };

sub init_this {
    my ($self, $config) = @_;
    $self->{ init_msg } = 'Hello World!';
    return $self;
}

sub bar {
    return "this is bar";
}

sub init_msg {
    shift->{ init_msg };
}

1;
