package Badger::Data::Facet::List;

use Badger::Class
    version   => 0.01,
    base      => 'Badger::Data::Facet',
    messages  => {
        wrong_size => '%s should have %d elements (got %d)',
        too_few    => '%s should have at least %d elements (got %d)',
        too_many   => '%s should have at most %d elements (got %d)',
    };

1;

__END__

=head1 NAME

Badger::Data::Facet::List - base class for list validation facets

=head1 DESCRIPTION

This module implements a base class for list validation facets.

=head1 METHODS

This module inherits all methods from the L<Badger::Data::Facet> and
L<Badger::Base> base classes.

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
