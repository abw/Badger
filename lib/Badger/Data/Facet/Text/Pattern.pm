package Badger::Data::Facet::Text::Pattern;

use Badger::Data::Facet::Class
    version   => 0.01,
    type      => 'text',
    args      => 'pattern';


sub validate {
    my ($self, $text, $type) = @_;
    my $regex = $self->{ regex } ||= qr/$self->{ pattern }/;

    return $$text =~ $regex
        || $self->invalid_msg( 
               pattern => $type || 'Text', $self->{ pattern }, $$text 
           );
}


1;

__END__

=head1 NAME

Badger::Data::Facet::Text::Pattern - validation facet for text pattern match

=head1 DESCRIPTION

This module implements a validation facets that assert that a text value
matches a regular expression pattern.

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
