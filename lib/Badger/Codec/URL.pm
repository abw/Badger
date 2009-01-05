#========================================================================
#
# Badger::Codec::URL
#
# DESCRIPTION
#   Codec module for URL encoding/decoding 
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Codec::URL;

use Badger::Class
    version => 0.01,
    base    => 'Badger::Codec::URI';

# cache of escaped characters is shared with Badger::Codec::URI
our $URI_ESCAPES = $Badger::Codec::URI::URI_ESCAPES;

sub encode_url {
    my $url = shift;
    utf8::encode($url) if $] >= 5.008;
    
    $URI_ESCAPES ||= {
        map { ( chr($_), sprintf("%%%02X", $_) ) } 
        (0..255)
    };
  
    # the different between the URL and URI encoding is that URL does
    # not escape any of: ; / ? : @ & = + $
    $url =~ s/([^;\/?:@&=+\$,A-Za-z0-9\-_.!~*'()])/$URI_ESCAPES->{$1}/eg;
    $url;
}

*decode_url = \&Badger::Codec::URI::decode_uri;

sub encode {
    shift;
    goto &encode_url;
}

sub decode {
    shift;
    goto &decode_url;
}

sub encoder {
    \&encode_url;
}

sub decoder {
    \&decode_url;
}


1;


__END__

=head1 NAME

Badger::Codec::URL - URL encode/decode 

=head1 SYNOPSIS

    use Badger::Codec::URL;
    my $codec   = Badger::Codec::URL->new();
    my $encoded = $codec->encode("Hello World!");
    my $decoded = $codec->decode($encoded);

=head1 DESCRIPTION

This module implements a subclass of L<Badger::Codec> for
URL encoding and decoding.  Note the difference between URI and
URL.  URI encoding is strict and encodes characters like C<;>, C<?>
and C</>.  The URL codec is more lax and does not encode these characters.

The URI codec should be used for encoding URL parameters.  The URL codec
can be used to encode complete URLs.

=head1 FUNCTIONS

=head2 encode_url($data)

This function URL-encodes the C<$data> passed as an argument.

=head2 decode_url($data)

This function URL-decodes the C<$data> passed as an argument.

=head1 METHODS

=head2 encode($data)

This method URL-encodes the data referenced by the first argument.
It delegates to the L<encode_url()> function.

    $encoded = Badger::Codec::URL->encode($data);   

=head2 decode($data)

This method decodes the encoded data passed as the first argument.
It delegates to the L<decode_url()> function.

    $decoded = Badger::Codec::URL->decode($encoded);

=head2 encoder()

This method returns a reference to the L<encode_url()> function.

=head2 decoder()

This method returns a reference to the L<decode_url()> function.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008-2009 Andy Wardley. All rights reserved.

=head1 SEE ALSO

L<Badger::Codecs>, L<Badger::Codec>

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

