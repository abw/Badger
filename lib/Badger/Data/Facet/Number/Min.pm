package Badger::Data::Facet::Number::Min;

use Badger::Class
    base  => 'Badger::Data::Facet';


sub validate {
    my ($self, $value, $type) = @_;

    return $$value >= $self->{ value }
        || $self->invalid_msg( 
               too_small => $type || 'Number', $self->{ value }, $$value
           );
}

1;

__END__

=head1 NAME

Badger::Data::Facet::Number::Min - validation facet for a minimum numerical value

=head1 DESCRIPTION

This module implements a validation facets that assert that a numeric value
is equal to or larger than a pre-defined value.

=head1 METHODS

This module implement the following method in addition to those inherited from
the L<Badger::Data::Facet::Number>, L<Badger::Data::Facet> and L<Badger::Base>
base classes.

=head2 validate($value_ref, $type)

This method validates that the number passed by reference as the first 
argument is greater than or equal to the pre-defined minimum limit.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Base>,
L<Badger::Data::Facet>,
L<Badger::Data::Facet::Number>.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
