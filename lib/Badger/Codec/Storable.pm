#========================================================================
#
# Badger::Codec::Storable
#
# DESCRIPTION
#   Codec for encoding/decoding data via the Storable module.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Codec::Storable;

use Badger::Class
    version => 0.01,
    base    => 'Badger::Codec';

use Storable qw( freeze thaw );

sub encode {
    my $self = shift;
    freeze(@_);
}

sub decode {
    my $self = shift;
    thaw(@_);
}

# shortcuts straight to the real encoder/decoder subs for efficient aliasing

sub encoder {
    \&freeze;
}

sub decoder {
    \&thaw;
}


1;

__END__

=head1 NAME

Badger::Codec::Storable - encode/decode data using Storable

=head1 SYNOPSIS

    use Badger::Codec::Storable;
    
    my $codec = Badger::Codec::Storable->new();
    my $enc   = $codec->encode({ pi => 3.14, e => 2.718 });
    my $dec   = $codec->decode($encoded);

=head1 DESCRIPTION

This module implements a subclass of Badger::Codec which uses the
C<freeze()> and C<thaw()> subroutines provided by the L<Storable> module
to encode and decode data.

It a very thin wrapper around the L<Storable> module and offers no
functional advantage over it.  It exist only to provide a consistent
API with other L<Badger::Codec> modules.

=head1 METHODS

=head2 encode($data)

Encodes the data referenced by the first argument using C<freeze()>.

    $encoded = Badger::Codec::Storable->encode($data);   

=head2 decode($html)

Decodes the encoded data passed as the first argument using C<thaw()>.

    $decoded = Badger::Codec::Storable->decode($encoded);

=head2 encoder()

This method returns a reference to the real subroutine that's doing
all the encoding work, i.e. the C<freeze()> method in L<Storable>.

=head2 decoder()

This method returns a reference to the real subroutine that's doing
all the decoding work, i.e. the C<thaw()> method in L<Storable>.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2005-2008 Andy Wardley. All rights reserved.

=head1 SEE ALSO

L<Badger::Codec>, L<Storable>

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

