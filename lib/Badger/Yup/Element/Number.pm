package Badger::Yup::Element::Number;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Yup::Element',
    utils    => 'numlike',
    messages => {
        invalid => "Value must be a number"
    },
    alias    => {
        ceil  => \&ceiling,
        trunc => \&truncate,
    };


sub validator {
    my ($self, $value, $message) = @_;
    return numlike($value)
        ? $value
        : $self->invalid($message, $value);
}

sub required {
    my $self = shift;
    return $self->factory->element( 'number.required' => \@_, $self );
}

sub min {
    my $self = shift;
    $self->arg_required('number.min', 'min', @_);
    return $self->factory->element( 'number.min' => \@_, $self );
}

sub max {
    my $self = shift;
    $self->arg_required('number.max', 'max', @_);
    return $self->factory->element( 'number.max' => \@_, $self );
}

sub positive {
    my $self = shift;
    return $self->factory->element( 'number.positive' => \@_, $self );
}

sub negative {
    my $self = shift;
    return $self->factory->element( 'number.negative' => \@_, $self );
}

sub nonzero {
    my $self = shift;
    return $self->factory->element( 'number.nonzero' => \@_, $self );
}

sub integer {
    my $self = shift;
    return $self->factory->element( 'number.integer' => \@_, $self );
}

sub floor {
    my $self = shift;
    return $self->factory->element( 'number.floor' => \@_, $self );
}

sub ceiling {
    my $self = shift;
    return $self->factory->element( 'number.ceiling' => \@_, $self );
}

sub round {
    my $self = shift;
    return $self->factory->element( 'number.round' => \@_, $self );
}

sub truncate {
    my $self = shift;
    return $self->factory->element( 'number.truncate' => \@_, $self );
}


#-----------------------------------------------------------------------------
# Number subclasses
#-----------------------------------------------------------------------------

package Badger::Yup::Element::Number::Required;

use Badger::Class
    base     => 'Badger::Yup::Element::Number',
    messages => {
        invalid => "Value is required"
    };

sub validator {
    my ($self, $value, $message) = @_;
    return (defined $value && length $value)
        ? $value
        : $self->invalid($message);
}

package Badger::Yup::Element::Number::Min;

use Badger::Class
    base     => 'Badger::Yup::Element::Number',
    messages => {
        invalid => "Number must be <2> or larger"
    };

sub validator {
    my ($self, $value, $min, $message) = @_;
    return (defined $value && $value >= $min)
        ? $value
        : $self->invalid($message, $value, $min);
}

package Badger::Yup::Element::Number::Max;

use Badger::Class
    base     => 'Badger::Yup::Element::Number',
    messages => {
        invalid => "Number must be <2> or smaller"
    };

sub validator {
    my ($self, $value, $max, $message) = @_;
    return (defined $value && $value <= $max)
        ? $value
        : $self->invalid($message, $value, $max);
}

package Badger::Yup::Element::Number::Positive;

use Badger::Class
    base     => 'Badger::Yup::Element::Number',
    messages => {
        invalid => "Number must be positive"
    };

sub validator {
    my ($self, $value, $message) = @_;
    return (defined $value && $value > 0)
        ? $value
        : $self->invalid($message, $value);
}

package Badger::Yup::Element::Number::Negative;

use Badger::Class
    base     => 'Badger::Yup::Element::Number',
    messages => {
        invalid => "Number must be negative"
    };

sub validator {
    my ($self, $value, $message) = @_;
    return (defined $value && $value < 0)
        ? $value
        : $self->invalid($message, $value);
}

package Badger::Yup::Element::Number::Nonzero;

use Badger::Class
    base     => 'Badger::Yup::Element::Number',
    messages => {
        invalid => "Number must not be zero"
    };

sub validator {
    my ($self, $value, $message) = @_;
    return (defined $value && $value != 0)
        ? $value
        : $self->invalid($message, $value);
}

package Badger::Yup::Element::Number::Integer;

use Badger::Class
    base     => 'Badger::Yup::Element::Number',
    messages => {
        invalid => "Number must be an integer"
    };

sub validator {
    my ($self, $value, $message) = @_;
    return (defined $value && $value =~ /^[-+]?\d+$/)
        ? $value
        : $self->invalid($message, $value);
}

package Badger::Yup::Element::Number::Floor;

use POSIX 'floor';
use Badger::Class
    base => 'Badger::Yup::Element::Number';

sub validator {
    my ($self, $value, $message) = @_;
    return floor($value);
}

package Badger::Yup::Element::Number::Ceiling;

use POSIX 'ceil';
use Badger::Class
    base => 'Badger::Yup::Element::Number';

sub validator {
    my ($self, $value, $message) = @_;
    return ceil($value);
}

package Badger::Yup::Element::Number::Round;

use POSIX 'round';
use Badger::Class
    base => 'Badger::Yup::Element::Number';

sub validator {
    my ($self, $value, $message) = @_;
    return round($value);
}

package Badger::Yup::Element::Number::Truncate;

use POSIX 'trunc';
use Badger::Class
    base => 'Badger::Yup::Element::Number';

sub validator {
    my ($self, $value, $message) = @_;
    return trunc($value);
}

1;
=head1 NAME

Badger::Yup::Number - data validation for numbers

=head1 DESCRIPTION

This implements number validation for L<Badger::Yup>.

=head1 METHODS

These methods each add a constraint to an existing number validator.

=head2 min($limit, $message)

Validates that the value is C<$limit> or larger.

=head2 max($limit, $message)

Validates that the value is C<$limit> or smaller.

=head2 ensure()

This ensures that the value is defined.  If an undefined value is
provided then it will return zero.  Otherwise it
simply returns the unaltered value.

=head1 AUTHOR

Perl version by Andy Wardley L<http://wardley.org>

Based on the Javascript Yup module: L<https://github.com/jquense/yup>

=head1 COPYRIGHT

Copyright (C) 2019 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
