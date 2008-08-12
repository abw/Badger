#========================================================================
#
# Badger::Codec::Unicode
#
# DESCRIPTION
#   Codec module for encoding/decoding Unicode via Encode
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Codec::Unicode;

use 5.008;                      # Unicode not fully supported prior to 5.8
use Badger::Class
    version => 0.01,
    base    => 'Badger::Codec::Encode';

use Encode qw();
use bytes;

# Default encoding
our $ENCODING = 'UTF-8';

# Byte Order Markers for different UTF encodings
our $UTFBOMS = [
    'UTF-8'    => "\x{ef}\x{bb}\x{bf}",
    'UTF-32BE' => "\x{0}\x{0}\x{fe}\x{ff}",
    'UTF-32LE' => "\x{ff}\x{fe}\x{0}\x{0}",
    'UTF-16BE' => "\x{fe}\x{ff}",
    'UTF-16LE' => "\x{ff}\x{fe}",
];

sub encode {
    my ($self, $enc, $data) = @_ == 3 ? @_ : (shift, $ENCODING, shift);
    Encode::encode($enc, $data);
}

sub decode {
    my $self = shift;
    if (@_ >= 2) {
        goto &Encode::decode;       # not a real GOTO - more like a magic
    }                               # subroutine call - see perldoc -f goto
    else {
        my $data  = shift;
        my $count = 0;
        
        # try all the BOMs in order looking for one (order is important
        # 32bit BOMs look like 16bit BOMs)
        while ($count < @$UTFBOMS) {
            my $enc = $UTFBOMS->[$count++];
            my $bom = $UTFBOMS->[$count++];
        
            # does the string start with the bom?
            if ($bom eq substr($data, 0, length($bom))) {
                # decode it and hand it back
                return Encode::decode($enc, $data);
                return Encode::decode($enc, substr($data, length($bom)));
            }
        }
        return $data;
    }
}

sub encoder {
    my $self = shift;
    return sub { $self->encode(@_) };
}

sub decoder {
    my $self = shift;
    return sub { $self->decode(@_) };
}

1;

__END__

=head1 NAME

Badger::Codec::Unicode - encode/decode Unicode 

=head1 SYNOPSIS

    use Badger::Codec::Unicode;
    my $codec   = Badger::Codec::Unicode->new();
    my $uncoded = "...some Unicode data...";
    my $encoded = $codec->encode($uncoded);
    my $decoded = $codec->decode($encoded);

=head1 DESCRIPTION

This module is a subclass of L<Badger::Codec> implementing a very thin wrapper
around the L<Encode> module for encoding and decoding Unicode.

A C<Badger::Codec::Unicode> object provides the L<encode()> and L<decode()>
methods for encoding and decoding Unicode.

    use Badger::Codec::Unicode;
    my $codec   = Badger::Codec::Unicode->new();
    my $uncoded = "...some Unicode data...";
    my $encoded = $codec->encode($uncoded);
    my $decoded = $codec->decode($encoded);

You can also call L<encode()> and L<decode()> as class methods.

    my $encoded = Badger::Code::Unicode->encode($uncoded);
    my $decoded = Badger::Code::Unicode->decode($encoded);

You can also use a codec via the L<Badger::Codecs> module.

    use Badger::Codecs 
        codec => 'unicode';

This exports the C<encode()> and C<decode()> subroutines.

    my $uncoded  = "...some Unicode data...";
    my $encoded  = encode($uncoded);
    my $decoded  = decode($encoded)

=head1 METHODS

=head2 encode($encoding, $data)

Method for encoding Unicode data.  If two arguments are provided then 
the first is the encoding and the second the data to encode.

    $encoded = $codec->encode( utf8 => $data );

If one argument is provided then the encoding defaults to C<UTF-8>.

    $utf8 = $codec->encode($data);

=head2 decode($encoding, $data)

Method for decoding Unicode data.  If two arguments are provided then 
the first is the encoding and the second the data to decode.

    $decoded = $codec->decode( utf8 => $encoded );

If one argument is provided then the method will look for a Byte Order
Mark (BOM) to determine the encoding.  If a BOM isn't present, or if the
BOM doesn't match a supported Unicode BOM (any of C<UTF-8>, C<UTF-32BE>
C<UTF-32LE>, C<UTF-16BE> or C<UTF-16LE>) then the data will not be 
decoded as Unicode.

    $decoded = $codec->decode($encoded);    # use BOM to detect encoding

=head2 encoder()

This method returns a subroutine reference which can be called to encode
Unicode data.  Internally it calls the L<encode()> method.

    my $encoder = $codec->encode;
    $encoded = $encoder->($data);

=head2 decoder()

This method returns a suboroutine reference which can be called to decode
Unicode data. Internally it calls the L<decode()> method.

    my $decoder = $codec->decode;
    $decoded = $decoder->($data);

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2005-2008 Andy Wardley. All rights reserved.

=head1 SEE ALSO

L<Encode>, L<Badger::Codec::Encode>, L<Badger::Codecs>, L<Badger::Codec>.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

