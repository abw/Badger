package Badger::Yup::Element::Yup;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Yup::Element';

sub validator {
    my ($self, $value) = @_;
    return $value;
}

sub string {
    my $self = shift;
    return $self->factory->element( string => \@_, $self );
}

sub number {
    my $self = shift;
    return $self->factory->element( number => \@_, $self );
}

sub hash {
    my $self = shift;
    return $self->factory->element( hash => \@_, $self );
}

sub required {
    my $self = shift;
    return $self->factory->element( 'required' => \@_, $self );
}

sub default {
    my $self = shift;
    $self->arg_required('number.default', 'default', @_);
    return $self->factory->element( 'default' => \@_, $self );
}


#-----------------------------------------------------------------------------
# Simple subclasses
#-----------------------------------------------------------------------------

package Badger::Yup::Element::Required;

use Badger::Class
    base     => 'Badger::Yup::Element::Yup',
    messages => {
        invalid => "Value is required"
    };

sub validator {
    my ($self, $value, $message) = @_;
    return (defined $value && length $value)
        ? $value
        : $self->invalid($message);
}

package Badger::Yup::Element::Default;

use Badger::Class
    base => 'Badger::Yup::Element::Yup';

sub validator {
    my ($self, $value, $default) = @_;
    return defined $value
        ? $value
        : $default;
}




1;
