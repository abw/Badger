#========================================================================
#
# t/codec/encoding.t
#
# Test the Badger::Codec::encoding module.
#
# Written by Andy Wardley <abw@wardley.org> using code from the TT2 
# t/unicode.t test written by Mark Fowler <mark@twoshortplanks.com>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Codec::Encoding;
use Badger::Test 
    tests => 4,
    debug => 'Badger::Codec::Encoding',
    args  => \@ARGV;

use constant Codec => 'Badger::Codec::Encoding';
use Encode qw();
use bytes;

my $uncoded = "Hello World";
my $encoded = Codec->encode($uncoded);      # ASCII by default
is( $encoded, $uncoded, 'ASCII encoding nullop' );

my $decoded = Codec->decode($encoded);
is( $decoded, $uncoded, 'ASCII decoding nullop' );


#-----------------------------------------------------------------------
# test utf8, and various other specific encodings
#-----------------------------------------------------------------------

package Badger::Test::Encoding::utf8;
use Badger::Codecs codec => 'utf8';
use Badger::Test;

our $moose   = "\x{ef}\x{bb}\x{bf}m\x{c3}\x{b8}\x{c3}\x{b8}se\x{e2}\x{80}\x{a6}";
our $uncoded = Encode::decode( utf8 => $moose );
our $encoded = encode($uncoded);
our $decoded = decode($encoded);

is( reasciify($encoded), reasciify($moose), "encoded utf8" );
is( $decoded, $uncoded, "decoded utf8" );


sub reasciify {
    my $string = shift;
    $string = join '', map {
        my $ord = ord($_);
        ($ord > 127 || ($ord < 32 && $ord != 10))
            ? sprintf '\x{%x}', $ord
            : $_
        } split //, $string;
    return $string;
}



__END__

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

