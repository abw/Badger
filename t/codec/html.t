#========================================================================
#
# t/codec/html.t
#
# Test the Badger::Codec::HTML module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger::Test
    lib   => '../../lib',
    tests => 8,
    debug => 'Badger::Codec::HTML',
    args  => \@ARGV;

use Badger::Codecs
    codec => 'HTML';

use constant 
    Codec => 'Badger::Codec::HTML';


my $html = '<foo>"&bar"</foo>';
my $enc  = '&lt;foo&gt;&quot;&amp;bar&quot;&lt;/foo&gt;';

#-----------------------------------------------------------------------
# should be able to access via the Badger::Codec module
#-----------------------------------------------------------------------

is( Badger::Codecs->encode(html => $html), $enc, 'HTML encode() via Badger::Codec' );
is( Badger::Codecs->decode(html => $enc), $html, 'HTML decode() via Badger::Codec' );

#-----------------------------------------------------------------------
# and also directly
#-----------------------------------------------------------------------

is( Codec->encode($html), $enc, 'HTML codec encode() class method' );
is( Codec->decode($enc), $html, 'HTML codec decode() class method' );

my $codec = Codec->new();

is( $codec->encode($html), $enc, 'HTML codec encode() object method' );
is( $codec->decode($enc), $html, 'HTML codec decode() object method' );


#-----------------------------------------------------------------------
# and via the imported encode()/decode() functions
#-----------------------------------------------------------------------

is( encode($html), $enc, 'encode() function' );
is( decode($enc), $html, 'decode() function' );



__END__

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

