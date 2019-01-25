package Badger::Yup::Element::Catch;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Yup::Element';

sub validate {
    my ($self, $value) = @_;
    my ($handler) = $self->arguments;
    eval {
        $value = $self->SUPER::validate($value);
    };
    if ($@ && $handler) {
        $value = $handler->($value, $@->info);
    }
    return $value;
}

1;
