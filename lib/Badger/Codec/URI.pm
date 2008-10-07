#========================================================================
#
# Badger::Codec::URI
#
# DESCRIPTION
#   Codec module for URI encoding/decoding 
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Codec::URI;

use Badger::Class
    version => 0.01,
    base    => 'Badger::Codec';

# cache of escaped characters
our $URI_ESCAPES;

sub encode_uri {
    my $uri = shift;
    utf8::encode($uri) if $] >= 5.008;
    
    $URI_ESCAPES ||= {
        map { ( chr($_), sprintf("%%%02X", $_) ) } 
        (0..255)
    };
  
    $uri =~ s/([^A-Za-z0-9\-_.!~*'()])/$URI_ESCAPES->{$1}/eg;
    $uri;
}

sub decode_uri {
    my $uri = shift;
    $uri =~ tr/+/ /;
    $uri =~ s/%([0-9a-fA-F]{2})/pack("c", hex($1))/ge;
    $uri;
}

sub encode {
    shift;
    goto &encode_uri;
}

sub decode {
    shift;
    goto &decode_uri;
}

sub encoder {
    \&encode_uri;
}

sub decoder {
    \&decode_uri;
}


1;


__END__

=head1 NAME

Badger::Codec::URI - URI encode/decode 

=head1 SYNOPSIS

    use Badger::Codec::URI;
    my $codec   = Badger::Codec::URI->new();
    my $encoded = $codec->encode("Hello World!");
    my $decoded = $codec->decode($encoded);

=head1 DESCRIPTION

This module implements a subclass of L<Badger::Codec> for
URI encoding and decoding.

=head1 FUNCTIONS

=head2 encode_uri($data)

This function URI-encodes the C<$data> passed as an argument.

=head2 decode_uri($data)

This function URI-decodes the C<$data> passed as an argument.

=head1 METHODS

=head2 encode($data)

This method URI-encodes the data referenced by the first argument.
It delegates to the L<encode_uri()> function.

    $encoded = Badger::Codec::URI->encode($data);   

=head2 decode($data)

This method decodes the encoded data passed as the first argument.
It delegates to the L<decode_uri()> function.

    $decoded = Badger::Codec::URI->decode($encoded);

=head2 encoder()

This method returns a reference to the L<encode_uri()> function.

=head2 decoder()

This method returns a reference to the L<decode_uri()> function.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2008 Andy Wardley. All rights reserved.

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

