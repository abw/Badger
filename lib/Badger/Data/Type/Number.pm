package Badger::Data::Type::Number;

use Badger::Data::Type::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Data::Type::Simple',
    type      => 'number',
    facets    => 'number',
    size      => 1;

1;

__END__

=head1 NAME

Badger::Data::Type::Number - base class data type for numbers

=head1 DESCRIPTION

This module implements a base class for numerical data types.

=head1 METHODS

This module inherits all methodsfrom the L<Badger::Data::Type::Simple>,
L<Badger::Data::Type> and L<Badger::Base> base classes.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008-2012 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Data::Type::Simple>,
L<Badger::Data::Type>,
L<Badger::Base>.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

