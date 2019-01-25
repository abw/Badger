package Badger::Yup::Element::Hash;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Yup::Element';

sub validate {
    my ($self, $hash) = @_;
    my ($schema, $accept, $reject) = $self->arguments;
    my $result = { };
    my $errors = { };

    $self->debug_data("validating hash: ", $hash) if DEBUG or 1;

    while (my ($name, $validator) = each %$schema) {
        my $value = $hash->{ $name };
        eval {
            my $valid = $validator($value);
            if ($accept) {
                $accept->($name, $valid);
            }
            $result->{ $name } = $valid;
        };
        if ($@) {
            if ($reject) {
                $reject->($name, $value, $@);
            }
            $errors->{ $name } = $@;
        }
    }

    return $value;
}

1;
