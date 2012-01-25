package Badger::Data::Type::Class;

use Badger::Debug ':dump';
use Badger::Class
    version    => 0.01,
    debug      => 0,
    uber       => 'Badger::Class',
#    words      => 'FACETS',
    constants  => 'ARRAY DELIMITER',
    hooks      => {
        type   => \&type,
        size   => \&size,
        facets => \&facets,
    };


sub type {
    my ($self, $type) = @_;
    $self->debug("set type to $type") if DEBUG;
    $self->method( type => $type );
}


sub size {
    my ($self, $size) = @_;
    $self->debug("set size to $size") if DEBUG;
    $self->method( size => $size );
}


sub facets {
    my ($self, $facets) = @_;
    my $current = $self->var_default( FACETS => [ ] );

    foreach ($facets, $current) {
        $_ = [ split DELIMITER ]
            unless ref eq ARRAY;
    }

    push(@$current, @$facets);
    
    $self->debug("merged facets are ", $self->dump_data($facets)) if DEBUG;
    
    $self->var( FACETS => $current );
}


1;

=head1 NAME

Badger::Data::Type::Class - metaprogramming module for data type classes

=head1 SYNOPSIS


=head1 DESCRIPTION

This module implements a subclass of L<Badger::Class> for creating data
types.

=head1 METHODS

This module implements the following methods in addition to those inherited 
from the L<Badger::Class> base class.

=head2 type($type)

This method implements the C<type> import hook for specifying the base data
type.

=head2 size($size)

This method implements the C<type> import hook for specifying the data size.
NOTE: subject to change

=head2 facets($facets)

This method implements the C<facets> import hook for specifying validation
facets for a data type.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008-2012 Andy Wardley.  All Rights Reserved.

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
