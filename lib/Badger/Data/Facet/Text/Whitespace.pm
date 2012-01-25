package Badger::Data::Facet::Text::Whitespace;

use Badger::Data::Facet::Class
    version   => 0.01,
    type      => 'text',
    args      => 'whitespace',
    constant  => {
        PRESERVE => 0,
        FOLD     => 1,
        COLLAPSE => 2,
    };

our $ACTION = {
    preserve => PRESERVE,
    fold     => FOLD,
    collapse => COLLAPSE, 
};


sub init {
    my ($self, $config) = @_;

    $self->SUPER::init($config)
        || return;

    # option must have an entry in $ACCEPT which we store in $self->{ action } 
    return $self->error_msg( whitespace => $self->{ whitespace }, join(', ', keys %$ACTION) )
        unless defined ($self->{ action } = $ACTION->{ $self->{ whitespace } });
        
    return $self;
}


sub validate {
    my ($self, $text, $type) = @_;
    my $action = $self->{ action }      # do nothing for PRESERVE
        || return $text;

    for ($$text) {
        s/[\r\n\t]/ /g;
        if ($action == COLLAPSE) {
            s/ +/ /g;
            s/^ +//;
            s/ +$//;
        }
    }
    
    return $text;
}


1;

__END__

=head1 NAME

Badger::Data::Facet::Text::Whitespace - validation facet for whitespace

=head1 DESCRIPTION

This module implements a validation facets for munging whitespace on text
values.

=head1 METHODS

This module implement the following methods in addition to those inherited
from the L<Badger::Data::Facet::Text>, L<Badger::Data::Facet> and
L<Badger::Base> base classes.

=head2 validate($text_ref, $type)

This method performs whitespace handling on the text passed by reference as
the first argument.

If the pre-defined C<action> is C<preserve> then the text will be unmodified.

If the C<action> is C<fold> then all whitespace characters in the text
(carriage returns, newlines, tabs) will be converted to spaces.

If the C<action> is C<collapse> then all whitespace characters will first be
converted to spaces as per C<fold>.  Any leading and trailing whitespace is
then removed and any sequences of multiple spaces are collapsed to a single
space.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2012 Andy Wardley.  All Rights Reserved.

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
