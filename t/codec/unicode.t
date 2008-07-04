#========================================================================
#
# t/codec/unicode.t
#
# Test the Badger::Codec::Unicode module.
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
use Badger::Codec::Unicode;
use Badger::Test 
    tests => 40,
    debug => 'Badger::Codec Badger::Codecs',
    args  => \@ARGV;

use constant Codec => 'Badger::Codec::Unicode';
use Encode qw();
use bytes;

my ($encode, $decode);
our $moose   = "\x{ef}\x{bb}\x{bf}m\x{c3}\x{b8}\x{c3}\x{b8}se\x{e2}\x{80}\x{a6}";
our $uncoded = Encode::decode( utf8 => $moose );
our $encoded = {
    'UTF-8'    => "\x{ef}\x{bb}\x{bf}m\x{c3}\x{b8}\x{c3}\x{b8}se\x{e2}\x{80}\x{a6}",
    'UTF-16BE' => "\x{fe}\x{ff}\x{0}m\x{0}\x{f8}\x{0}\x{f8}\x{0}s\x{0}e &",
    'UTF-16LE' => "\x{ff}\x{fe}m\x{0}\x{f8}\x{0}\x{f8}\x{0}s\x{0}e\x{0}& ",
    'UTF-32BE' => "\x{0}\x{0}\x{fe}\x{ff}\x{0}\x{0}\x{0}m\x{0}\x{0}\x{0}\x{f8}\x{0}\x{0}\x{0}\x{f8}\x{0}\x{0}\x{0}s\x{0}\x{0}\x{0}e\x{0}\x{0} &",
    'UTF-32LE' => "\x{ff}\x{fe}\x{0}\x{0}m\x{0}\x{0}\x{0}\x{f8}\x{0}\x{0}\x{0}\x{f8}\x{0}\x{0}\x{0}s\x{0}\x{0}\x{0}e\x{0}\x{0}\x{0}& \x{0}\x{0}",
};

while (my ($enc, $original) = each %$encoded) {
    $decode = Codec->decode($original);
    ok( $decode, "decoded $enc via codec: $decode" );
    is( $decode, $uncoded, "decoded $enc matches uncoded" );

    $encode = Codec->encode($decode);
    ok( $encode, "encoded $enc: " . nicely($encode) );
    is( reasciify($encode), reasciify($moose), "encoded $enc output matches input" );
}

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

sub nicely {
    my $text = shift;
    $text = reasciify($text);
    $text = substr($text, 0, 30) . '...'
        if length $text > 30;
    return $text;
}


#-----------------------------------------------------------------------
# now try it with encode() / decode() subs
#-----------------------------------------------------------------------

package Badger::Test::Encode::Codec;
use Badger::Codecs
    codec => 'unicode';

our $moose   = $main::moose;
our $uncoded = $main::uncoded;
our $encoded = $main::encoded;
*reasciify   = \&main::reasciify;
*nicely      = \&main::nicely;
*ok          = \&main::ok;
*is          = \&main::is;

while (my ($enc, $original) = each %$encoded) {
    $decode = decode($original);
    ok( $decode, "decoded $enc via decode(): $decode" );
    is( $decode, $uncoded, "decode() $enc matches uncoded" );

    $encode = encode($decode);
    ok( $encode, "encoded $enc via encode(): " . nicely($encode) );
    is( reasciify($encode), reasciify($moose), "encode() $enc output matches input" );
}


__END__

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

