#========================================================================
#
# Badger::Codec::JSON
#
# DESCRIPTION
#   Codec module for encoding/decoding Base64
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Codec::JSON;

use Badger::Class
    version => 0.01,
    base    => 'Badger::Codec',
    import  => 'class';

use JSON ();
our $JSON = JSON->new;

sub encode {
    my $self = shift;
    $JSON->encode(shift);
}

sub decode {
    my $self = shift;
    $JSON->decode(shift);
}

# shortcuts straight to the real encoder/decoder subs for efficient aliasing

sub encoder {
    \&JSON::encode_json;
}

sub decoder {
    \&JSON::decode_json;
}


1;


__END__

=head1 NAME

Badger::Codec::JSON - encode/decode data using JSON

=head1 SYNOPSIS

    use Badger::Codec::JSON;
    my $codec   = Badger::Codec::JSON->new();
    my $encoded = $codec->encode({ msg => "Hello World" });
    my $decoded = $codec->decode($encoded);

=head1 DESCRIPTION

This module implements a subclass of L<Badger::Codec> which uses the
L<JSON> module to encode and decode data to and from JSON.

=head1 METHODS

=head2 encode($data)

Encodes C<$data> to JSON.

    $encoded = Badger::Codec::JSON->encode($data);   

=head2 decode($data)

Decodes C<$data> from JSON.

    $decoded = Badger::Codec::JSON->decode($encoded);

=head2 encoder()

This method returns a reference to the real subroutine that's doing
all the encoding work, i.e. the C<encode()> subroutine in L<JSON>.

=head2 decoder()

This method returns a reference to the real subroutine that's doing
all the decoding work, i.e. the C<decode()> subroutine in L<JSON>.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2005-2009 Andy Wardley. All rights reserved.

=head1 SEE ALSO

L<Badger::Codecs>, L<Badger::Codec>, L<JSON>

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

