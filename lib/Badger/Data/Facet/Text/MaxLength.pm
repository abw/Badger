package Badger::Data::Facet::Text::MaxLength;

use Badger::Data::Facet::Class
    version   => 0.01,
    type      => 'text',
    args      => 'max_length';


sub validate {
    my ($self, $text, $type) = @_;

    return length($$text) <= $self->{ max_length }
        || $self->invalid_msg( 
               too_long => $type || 'Text', 
               $self->{ max_length }, length($$text) 
           );
}

1;

__END__

=head1 NAME

Badger::Data::Facet::Text::MaxLength - validation facet for text length

=head1 DESCRIPTION

This module implements a validation facets that checks the length of a
text value to assert that it is less than or equal to a pre-defined length.

=head1 METHODS

This module inherits all methods from the L<Badger::Data::Facet::Text>,
L<Badger::Data::Facet> and L<Badger::Base> base classes.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Base>,
L<Badger::Data::Facet>,
L<Badger::Data::Facet::Text>.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
