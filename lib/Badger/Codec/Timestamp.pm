#========================================================================
#
# Badger::Codec::Timestamp
#
# DESCRIPTION
#   Codec module for encoding/decoding a timestamp via Badger::Timestamp
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Codec::Timestamp;

use Badger::Class
    version => 0.01,
    base    => 'Badger::Codec';

use Badger::Timestamp 'Timestamp';


sub encode {
    my $self = shift;
    return Timestamp(@_)->timestamp;
}


sub decode {
    my $self = shift;
    return Timestamp(@_);
}


1;


__END__

=head1 NAME

Badger::Codec::Timestamp - encode/decode a timestamp via Badger::Timestamp

=head1 SYNOPSIS

    use Badger::Codec::Timestamp;
    use Badger::Timestamp 'Now';

    my $codec   = Badger::Codec::Timestamp->new();
    my $encoded = $codec->encode(Now);
    my $decoded = $codec->decode($encoded);

=head1 DESCRIPTION

This module implements a subclass of L<Badger::Codec> for encoded and decoding
timestamps using the Badger::Timestamp module. It is trivially simple,
existing only to provide a consistent API with other L<Badger::Codec> modules.
It is typically used as a codec for reading and writing timestamps to and from
a file via the L<Badger::Filesystem> modules.

    use Badger::Filesystem 'File';
    use Badger::Timestamp 'Now';
    
    my $stamp = Now;                     # current data/time
    my $file  = File(
        'example.ts',                   # filename
        { codec => 'timestamp' }        # specify timestamp codec
    );
    
    # write timestamp to file
    $file->data($stamp);
    
    # read timestamp from file
    $stamp = $file->data;

=head1 METHODS

=head2 encode($timestamp)

Encodes the timestamp passed as an argument. The argument can be a
L<Badger::Timestamp> object or any of the constructor parameters accepted by
L<Badger::Timestamp>. The following example demonstrates how this works in
principle, although it should be noted that it's completely pointless in
practice. It is sufficient to simply call C<Now-E<gt>timestamp> to serialise a
L<Badger::Timestamp> to text without the need for any codec module (in fact,
that's all the C<encode()> method does behind the scenes).

    use Badger::Timestamp 'Now';
    $encoded = Badger::Codec::Timestamp->encode(Now);

=head2 decode($data)

Decodes the encoded timestamp passed as the first argument.  Returns a 
L<Badger::Timestamp> object.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2012 Andy Wardley. All rights reserved.

=head1 SEE ALSO

L<Badger::Codecs>, L<Badger::Codec>, L<Badger::Timestamp>

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

