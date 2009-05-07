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
    import  => 'class',
    codecs  => 'unicode';

eval "require JSON::XS";
our $HAS_JSON_XS = $@ ? 0 : 1;

eval "require JSON";
our $HAS_JSON = $@ ? 0 : 1;
our $MODULE = 
    $HAS_JSON_XS ? 'JSON::XS' :
    $HAS_JSON    ? 'JSON'     :
    die "No JSON implementation installed\n";

our $JSON    = $MODULE->new->utf8;

sub encode_json {
    $JSON->encode(shift);
}

sub decode_json {
    my $json = shift;
#    utf8::upgrade($json);
    $json = encode_unicode($json);
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

sub OLD_decode {
    my $self = shift;
    my $data = shift;
    $data = encode_unicode($data);
    $JSON->decode($data);
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

