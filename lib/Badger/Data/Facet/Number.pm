package Badger::Data::Facet::Number;

use Badger::Class
    version   => 0.01,
    base      => 'Badger::Data::Facet',
    utils     => 'numlike',
    messages  => {
        not_number  => '%s is not a number (got %s)',
        too_small   => '%s should be no less than %d (got %d)',
        too_large   => '%s should be no more than %d (got %d)',
    };


sub validate {
    my ($self, $value, $type) = @_;

    return numlike $$value
        || $self->invalid_msg( not_number => $type || 'Text', $$value );
}


1;

__END__

=head1 NAME

Badger::Data::Facet::Number - base class for numerical validation facets

=head1 DESCRIPTION

This module implements a base class for numerical validation facets.

=head1 METHODS

This module implements the following methods in addition to those inherited
from the L<Badger::Data::Facet> and L<Badger::Base> base classes.

=head2 validate($value)

Asserts that the C<$value> passed as an argument is a number.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Base>,
L<Badger::Data::Facet>.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
