package Badger::Yup::Elements;

use Badger::Class
    version => 0.01,
    debug   => 0,
    base    => 'Badger::Modules';

our $ITEM = 'element';
our $ELEMENT_PATH = [
    'Badger::Yup::Element',
    'BadgerX::Yup::Element',
];

sub attach {
    shift->todo;
}

sub element {
    my $self   = shift->prototype;
    my $name   = shift;
    my $module = $self->{ element }->{ $name }
        || $self->module($name);

    return $module->new( $self, $name, @_ );
}


1;
