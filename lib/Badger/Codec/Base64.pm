#========================================================================
#
# Badger::Codec::Base64
#
# DESCRIPTION
#   Codec module for encoding/decoding Base64
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Codec::Base64;

use Badger::Class
    version => 0.01,
    base    => 'Badger::Codec';

use MIME::Base64;

sub encode {
    my $self = shift;
    encode_base64(shift);
}

sub decode {
    my $self = shift;
    decode_base64(shift);
}

# shortcuts straight to the real encoder/decoder subs for efficient aliasing

sub encoder {
    \&encode_base64;
}

sub decoder {
    \&decode_base64;
}


1;


__END__

=head1 NAME

Badger::Codec::Base64 - encode/decode data using MIME::Base64

=head1 SYNOPSIS

    use Badger::Codec::Base64;
    my $codec   = Badger::Codec::Base64->new();
    my $encoded = $codec->encode("Hello World");
    my $decoded = $codec->decode($encoded);

=head1 DESCRIPTION

This module implements a subclass of L<Badger::Codec> which uses the
C<encode_base64> and C<decode_base64> subroutines provided by the
L<MIME::Base64> module to encode and decode data.

It a very thin wrapper around the C<MIME::Base64> module and offers no
functional advantage over it.  It exist only to provide a consistent
API with other L<Badger::Codec> modules.

=head1 METHODS

=head2 encode($data)

Encodes the data referenced by the first argument using C<encode_base64()>.

    $encoded = Badger::Codec::Base64->encode($data);   

=head2 decode($data)

Decodes the encoded data passed as the first argument using C<decode_base64()>.

    $decoded = Badger::Codec::Base64->decode($encoded);

=head2 encoder()

This method returns a reference to the real subroutine that's doing
all the encoding work, i.e. the C<encode_base64()> method in L<MIME::Base64>.

=head2 decoder()

This method returns a reference to the real subroutine that's doing
all the decoding work, i.e. the C<decode_base64()> method in L<MIME::Base64>.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2005-2009 Andy Wardley. All rights reserved.

=head1 SEE ALSO

L<Badger::Codecs>, L<Badger::Codec>, L<MIME::Base64>

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

