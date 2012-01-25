package Badger::Data::Facet::List::MinSize;

use Badger::Data::Facet::Class
    version   => 0.01,
    type      => 'list',
    args      => 'min_size';


sub validate {
    my ($self, $value, $type) = @_;

    return scalar(@$value) >= $self->{ min_size }
        ? $value
        : $self->invalid_msg( 
            too_few => $type || 'List', $self->{ min_size }, scalar(@$value) 
          );

}

1;

__END__

=head1 NAME

Badger::Data::Facet::List::MinSize - validation facet for the size of a list

=head1 DESCRIPTION

This module implements a validation facets that checks the size of a list
to assert that it is equal to or above a certain size in terms of items it
contains.

=head1 METHODS

This module implement the following method in addition to those inherited from
the L<Badger::Data::Facet::List>, L<Badger::Data::Facet> and L<Badger::Base>
base classes.

=head2 validate($list_ref, $type)

This method validates that the size of the list (i.e. number of elements)
passed by reference as the first  argument is less than or equal to the pre-
defined maximum limit.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008-2012 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Base>,
L<Badger::Data::Facet>,
L<Badger::Data::Facet::List>.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
