package Badger::Data::Facet::Text;

use Badger::Class
    version   => 0.01,
    base      => 'Badger::Data::Facet',
    messages  => {
        not_text        => '%s is not text (got %s)',
        wrong_length    => '%s should be %d characters long (got %d)',
        too_short       => '%s should be at least %d characters long (got %d)',
        too_long        => '%s should be at most %d characters long (got %d)',
        pattern         => '%s does not match pattern: %s',
        whitespace      => 'Invalid whitespace option: %s (expected one of: %s)',

#        not_any        => '%s does not match any of the permitted values: <3>',
#        not_number     => '%s is not a number: <3>',
    };


sub validate {
    my ($self, $value, $type) = @_;

    return textlike $$value
        || $self->invalid_msg( not_text => $type || 'Text', ref $value || $value );
}


1;

__END__

=head1 NAME

Badger::Data::Facet::Text - base class for text validation facets

=head1 DESCRIPTION

This module implements a base class for text validation facets.

=head1 METHODS

This module implements the following methods in addition to those inherited
from the L<Badger::Data::Facet> and L<Badger::Base> base classes.

=head2 validate($value)

Asserts that the C<$value> passed as an argument is a text string or an
object with a overloaded auto-stringification operator that allows it to
behave like a text string.

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
