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
    import  => 'class CLASS',
    codecs  => 'utf8';

our ($HAS_CP_JSON_XS, $HAS_JSON_XS, $HAS_JSON);

# Cpanel::JSON::XS is more complete/correct than JSON::XS
eval "require Cpanel::JSON::XS";
$HAS_CP_JSON_XS = $@ ? 0 : 1;

# JSON::XS has bits missing (e.g. allow_bignum)
unless ($HAS_CP_JSON_XS) {
    eval "require JSON::XS";
    $HAS_JSON_XS = $@ ? 0 : 1;
}

# fallback to Perl implementation
unless ($HAS_CP_JSON_XS || $HAS_JSON_XS) {
    eval "require JSON";
    $HAS_JSON = $@ ? 0 : 1;
}

our $MODULE =
    $HAS_CP_JSON_XS ? 'Cpanel::JSON::XS' :
    $HAS_JSON_XS    ? 'JSON::XS' :
    $HAS_JSON       ? 'JSON'     :
    CLASS->error("You don't have JSON, JSON::XS or Cpanel::JSON::XS installed");

our $JSON = $MODULE->new;

sub encode_json {
    $JSON->encode(shift);
}

sub decode_json {
    my $json = shift;
#   $json = encode_utf8($json);
    $JSON->decode($json);
}

sub encode {
    shift;
    goto &encode_json;
}

sub decode {
    shift;
    goto &decode_json;
}

sub encoder {
    \&encode_json;
}

sub decoder {
    \&decode_json;
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
L<JSON::XS> or L<JSON> module (whichever you have installed) to encode and
decode data to and from JSON. It is little more than an adapter module
to fit L<JSON> into the L<Badger::Codec> mould.

=head1 METHODS

=head2 encode($data)

Encodes the Perl data in C<$data> to a JSON string. This method is a wrapper
around the internal the L<encode_json()> subroutine.

    $encoded = Badger::Codec::JSON->encode($data);

=head2 decode($json)

Decodes the encoded JSON string in C<$json> back into a Perl data structure.
This method is a wrapper around the internal the L<decode_json()> subroutine.

    $decoded = Badger::Codec::JSON->decode($encoded);

=head2 encoder()

This method returns a reference to the real subroutine that's doing
all the encoding work, i.e. the internal C<encode_json()> subroutine.

=head2 decoder()

This method returns a reference to the real subroutine that's doing
all the decoding work, i.e. the C<decode_json()> subroutine in L<JSON>.

=head1 INTERNAL SUBROUTINES

=head2 encode_json($data)

This is the internal subroutine that encodes the JSON data.  It delegates
to the L<JSON::XS> or L<JSON> module, depending on which you have installed.

=head2 decode_json($json)

This is the internal subroutine that decodes the JSON data.  As per
L<encode_json()>, it delegates the task to the L<JSON::XS> or L<JSON> module.

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
