#========================================================================
#
# t/codec/codecs.t
#
# Test the Badger::Codecs module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./t/codec/lib ./codec/lib ./lib ../lib ../../lib );
use Badger::Codecs;
use Test::More tests => 34;
use constant CODECS => 'Badger::Codecs';
$Badger::Codecs::DEBUG = grep(/^-d/, @ARGV);

my $hello = 'Hello World';
my $data  = {
    message => $hello,
    author  => 'Brian the Badger',
};
my ($enc, $dec, $codec, $codecs);


#-----------------------------------------------------------------------
# test class methods
#-----------------------------------------------------------------------

$enc = CODECS->encode(storable => $data);
ok( $enc, 'encoded data via Codec' );

$dec = CODECS->decode(storable => $enc);
ok( $dec, 'decoded data via Codec' );

is( $dec->{ message }, $data->{ message }, 'message received via Codec' );
is( $dec->{ author }, $data->{ author }, 'name transcoded via Codec' );


#-----------------------------------------------------------------------
# test object methods
#-----------------------------------------------------------------------

$codec = CODECS->codec('storable');
ok( $codec, 'got Storable codec' );

$enc = $codec->encode($data);
ok( $enc, 'encoded data' );

$dec = $codec->decode($enc);
ok( $dec, 'decoded data' );

is( $dec->{ message }, $data->{ message }, 'message received' );
is( $dec->{ author }, $data->{ author }, 'name transcoded' );


#-----------------------------------------------------------------------
# test base option
#-----------------------------------------------------------------------

$codecs  = Badger::Codecs->new(
    base => 'My::Codec',
);

is( $codecs->encode( foo => 'hello' ), 'FOO:hello', 'encoded foo via codecs' );
is( $codecs->decode( foo => 'FOO:world' ), 'world', 'decoded foo via codecs' );

$codec = $codecs->codec('foo');
is( $codec->encode('hello'), 'FOO:hello', 'encoded foo via codec' );
is( $codec->decode('FOO:world'), 'world', 'decoded foo via codec' );


#-----------------------------------------------------------------------
# test base option with list ref
#-----------------------------------------------------------------------

$codecs  = Badger::Codecs->new(
    base => ['Badger::Code', 'No::Such::Codec', 'My::Codec' ],
);

is( $codecs->decode( Base64 => $codecs->encode( Base64 => $hello ) ), 
    $hello, 'transcoded url via codecs' );

is( $codecs->decode( Foo => $codecs->encode( foo => $hello ) ), 
    $hello, 'transcoded foo via codecs' );


#-----------------------------------------------------------------------
# test codecs option
#-----------------------------------------------------------------------

$codecs  = Badger::Codecs->new(
    codecs => {
        foo => 'Badger::Codec::Base64',
    }
);

is( $codecs->decode( foo => $codecs->encode( Base64 => $hello ) ), 
    $hello, 'transcoded foo/base64 via codecs' );

is( $codecs->decode( base64 => $codecs->encode( foo => $hello ) ), 
    $hello, 'transcoded base64/foo via codecs' );


#-----------------------------------------------------------------------
# import a single codec
#-----------------------------------------------------------------------

package Wibble;
use Test::More;

# importing a single codec
use Badger::Codecs 
    codec => 'Base64';
    
# codec() returns a Badger::Codec::URL object
$enc = codec->encode($hello);
ok( $enc, 'encoded data via imported base64 codec()' );

$dec = codec->decode($enc);
ok( $dec, 'decoded data via imported base64 codec()' );

is( $dec, $hello, 'transcoded hello via base64 codec()' );

# encode() and decode() are imported subroutines
$enc = encode($hello);
ok( $enc, 'encoded data via imported base64 encode()' );

$dec = decode($enc);
ok( $dec, 'decoded data via imported base64 decode()' );

is( $dec, $hello, 'transcoded hello via base64 encode()/decode()' );


#-----------------------------------------------------------------------
# import multiple codecs
#-----------------------------------------------------------------------

# import multiple codecs
use Badger::Codecs
    codecs => 'base64 storable';
    
# codec objects
is( base64->decode( base64->encode($hello) ), 
    $hello, 'imported codecs transcode base64' );

is( storable->decode(storable->encode($data))->{ message }, 
    $hello, 'imported codecs transcode storable' );

# imported subroutines
is( decode_base64( encode_base64($hello) ), 
    $hello, 'imported transcoders for base64' );

is( decode_storable(encode_storable($data))->{ message }, 
    $hello, 'imported transcoders for storable' );


#-----------------------------------------------------------------------
# test codec chains
#-----------------------------------------------------------------------

package Somewhere::Else;        # avoid redefine warnings;
use Test::More;

use Badger::Codecs
    codec => 'storable+base64';

$enc = codec->encode($data);
ok( $enc, 'encoded data via storable+base64 chain' );

$dec = codec->decode($enc);
ok( $enc, 'decoded data via storable+base64 chain' );

is( $dec->{ message }, $hello, 'integrity check' );

is( decode(encode($data))->{ message }, 
    $hello, 'transcoded via storable+base64 encode/decode subs' );

is( Badger::Codecs->decode( 
        'storable+base64' => Badger::Codecs->encode(
            'storable+base64' => $data
        )
    )->{ message }, 
    $hello, 'transcoded via storable+base64 encode/decode subs' );



#-----------------------------------------------------------------------
# test multiple codecs in a hash ref
#-----------------------------------------------------------------------

# multiple codecs with various options
package Another::Place;
use Test::More;

use Badger::Codecs
    codecs => {
#        link  => 'url+html',
        str64 => 'storable+base64',
    };
    
# codec objects
is( str64->decode( str64->encode($data) )->{ message }, 
    $hello, 'transcoded via str64 codec' );

is( decode_str64( encode_str64($data) )->{ message }, 
    $hello, 'transcoded via str64 encode/decode' );


__END__

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

