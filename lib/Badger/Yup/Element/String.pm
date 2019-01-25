package Badger::Yup::Element::String;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Yup::Element',
    messages => {
        invalid => "Value must be a text string"
    };

sub validator {
    my ($self, $value, $message) = @_;
    return ref($value)
        ? $self->invalid($message, $value)
        : $value;
}

sub required {
    my $self = shift;
    return $self->factory->element( 'string.required' => \@_, $self );
}

sub min {
    my $self = shift;
    $self->arg_required('string.min', 'min', @_);
    return $self->factory->element( 'string.min' => \@_, $self );
}

sub max {
    my $self = shift;
    $self->arg_required('string.max', 'max', @_);
    return $self->factory->element( 'string.max' => \@_, $self );
}

sub matches {
    my $self = shift;
    $self->arg_required('string.matches', 'regex', @_);
    return $self->factory->element( 'string.matches' => \@_, $self );
}

sub trim {
    my $self = shift;
    return $self->factory->element( 'string.trim' => \@_, $self );
}

sub uppercase {
    my $self = shift;
    return $self->factory->element( 'string.uppercase' => \@_, $self );
}

sub lowercase {
    my $self = shift;
    return $self->factory->element( 'string.lowercase' => \@_, $self );
}

sub capitalize {
    my $self = shift;
    return $self->factory->element( 'string.capitalize' => \@_, $self );
}

sub ensure {
    my $self = shift;
    return $self->factory->element( 'string.ensure' => \@_, $self );
}


#-----------------------------------------------------------------------------
# String subclasses
#-----------------------------------------------------------------------------

package Badger::Yup::Element::String::Required;

use Badger::Class
    base     => 'Badger::Yup::Element::String',
    messages => {
        invalid => "Value is required"
    };

sub validator {
    my ($self, $value, $message) = @_;
    return (defined $value && length $value)
        ? $value
        : $self->invalid($message, $value);
}

package Badger::Yup::Element::String::Min;

use Badger::Class
    base     => 'Badger::Yup::Element::String',
    messages => {
        invalid => "String must be <2> characters or longer"
    };

sub validator {
    my ($self, $value, $min, $message) = @_;
    return (defined $value && length $value >= $min)
        ? $value
        : $self->invalid($message, $value, $min);
}

package Badger::Yup::Element::String::Max;

use Badger::Class
    base     => 'Badger::Yup::Element::String',
    messages => {
        invalid => "String must be <2> characters or shorter"
    };

sub validator {
    my ($self, $value, $max, $message) = @_;
    return (defined $value && length $value <= $max)
        ? $value
        : $self->invalid($message, $value, $max);
}

package Badger::Yup::Element::String::Matches;

use Badger::Class
    base     => 'Badger::Yup::Element::String',
    messages => {
        invalid => "String must match the pattern: <2>"
    };

sub validator {
    my ($self, $value, $regex, $message) = @_;
    return (defined $value && $value =~ $regex)
        ? $value
        : $self->invalid($message, $value, $regex);
}

package Badger::Yup::Element::String::Trim;

use Badger::Class
    base => 'Badger::Yup::Element::String';

sub validator {
    my ($self, $value) = @_;
    for ($value) {
        s/^\s+//;
        s/\s+$//;
    }
    return $value;
}

package Badger::Yup::Element::String::Uppercase;

use Badger::Class
    base => 'Badger::Yup::Element::String';

sub validator {
    my ($self, $value) = @_;
    return uc $value;
}

package Badger::Yup::Element::String::Lowercase;

use Badger::Class
    base => 'Badger::Yup::Element::String';

sub validator {
    my ($self, $value) = @_;
    return lc $value;
}

package Badger::Yup::Element::String::Capitalize;

use Badger::Class
    base => 'Badger::Yup::Element::String';

sub validator {
    my ($self, $value) = @_;
    return ucfirst $value;
}

package Badger::Yup::Element::String::Ensure;

use Badger::Class
    base => 'Badger::Yup::Element::String';

sub validator {
    my ($self, $value) = @_;
    return defined $value
        ? $value
        : '';
}


1;
=head1 NAME

Badger::Yup::String - data validation for text strings

=head1 DESCRIPTION

This implements string validation for L<Badger::Yup>.

=head1 METHODS

These methods each add a constraint to an existing string validator.

=head2 min($limit, $message)

Validates that the value is I<at least> C<$limit> characters in length.

=head2 max($limit, $message)

Validates that the value is I<at most> C<$limit> characters in length.

=head2 matches($regex, $message)

Validates that the value matches the C<$regex> regular expression.

=head2 trim()

Removes any leading and/or trailing whitespace from the value.

=head2 lowercase()

Converts the value to lower case.

=head2 uppercase()

Converts the value to upper case.

=head2 capitalize()

Capitalizes the value, changing the first letter to upper case.

=head2 ensure()

This ensures that the value is defined.  If an undefined value is
provided then it will return a zero length string.  Otherwise it
simply returns the unaltered value.

=head2 email($message)

TODO: check that the value looks like an email address

=head2 url($message)

TODO: check that the value looks like a URL

=head1 AUTHOR

Perl version by Andy Wardley L<http://wardley.org>

Based on the Javascript Yup module: L<https://github.com/jquense/yup>

=head1 COPYRIGHT

Copyright (C) 2019 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
