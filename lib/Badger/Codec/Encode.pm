#========================================================================
#
# Badger::Codec::Encode
#
# DESCRIPTION
#   A codec wrapper for Encode
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Codec::Encode;

use Badger::Class
    version => 0.01,
    base    => 'Badger::Codec';

use Encode qw();
use bytes;

sub encode {
    my $self = shift;
    # No, really, it's OK.  This isn't one of those kind of GOTOs.
    # This is an Offically OK version of GOTO which is really a special
    # kind of subroutine call.  See: perldoc -f goto
    goto &Encode::encode;
}

sub decode {
    my $self = shift;
    # we use goto rather than a call because a) it's quicker (the call 
    # stack frame is re-used) and b) because the prototypes for encode()
    # and decode() would require us to shift all the arguments off the 
    # stack in order to pass them to encode()/decode() in an orderly
    # fashion, e.g. my ($enc, $data) = @_; Encode::encode($enc, $data)
    # rather than: Encode::encode(@_);  # not allowed - prototype mismatch
    goto &Encode::decode;
}

sub encoder {
    \&Encode::encode;
}

sub decoder {
    \&Encode::decode;
}

1;


__END__

=head1 NAME

Badger::Codec::Encode - codec wrapper around Encode

=head1 SYNOPSIS

    use Badger::Codec::Encode;
    
    my $codec    = Badger::Codec::Encode->new();
    my $encoded = $codec->encode( utf8 => "...some utf8 data..." );
    my $decoded = $codec->decode( utf8 => $encoded );

=head1 DESCRIPTION

This module is a subclass of L<Badger::Codec> implementing a very thin wrapper
around the L<Encode> module. It exists only to provide a consistent API with
other L<Badger::Codec> modules and to facilitate codec chaining.

You would normally use a codec via the L<Badger::Codecs> module.

    use Badger::Codecs 
        codec => 'encode';
    
    my $encoding = 'UTF-8';
    my $uncoded  = "...some UTF-8 data...";
    my $encoded  = encode($encoding, $uncoded);
    my $decoded  = decode($encoding, $encoded)

The above example is identical to using the L<Encode> module directly:

    use Encode;     # also exports encode()/decode()

In addition, a L<Badger::Codec::Encode> object will be available via
the C<codec()> subroutine.

    my $encoded  = codec->encode($encoding, $uncoded);
    my $decoded  = codec->decode($encoding, $encoded)

=head1 METHODS

=head2 encode($encoding, $data)

Method for encoding data which forwards all arguments to the L<Encode>
L<encode()|Encode/encode()> method.  The first argument is the encoding,
the second is the data to encode.

    $encoded = Badger::Codec::Encode->encode( utf8 => $data );

=head2 decode($encoding, $data)

Method for decoding data which forwards all arguments to the L<Encode>
L<decode()|Encode/decode()> method.  The first argument is the encoding,
the second is the data to decode.

    $decoded = Badger::Codec::Encode->decode( utf8 => $encoded );

=head2 encoder()

This method returns a reference to the real subroutine that's doing
all the encoding work, i.e. the L<encode()|Encode/encode()> method in 
L<Encode>.

=head2 decoder()

This method returns a reference to the real subroutine that's doing
all the encoding work, i.e. the L<decode()|Encode/decode()> method in 
L<Encode>.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2005-2008 Andy Wardley. All rights reserved.

=head1 SEE ALSO

L<Encode>, L<Badger::Codecs>, L<Badger::Codec>, L<Badger::Codec::Unicode>.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

