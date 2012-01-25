package Badger::Data::Type::Simple;

use Badger::Class
    version     => 0.01,
    base        => 'Badger::Data::Type',
    constant    => {
        simple  => 1,
    };

1;

__END__

=head1 NAME

Badger::Data::Type::Simple - base class for simple data types

=head1 DESCRIPTION

This module implements a base class for simple (single value) data types.

=head1 METHODS

The following methods are defined in addition to those inherited from the 
L<Badger::Data::Type> and L<Badger::Base> base classes.

=head2 simple()

This constant method always returns the value C<1>.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Base>,
L<Badger::Data::Type>.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
