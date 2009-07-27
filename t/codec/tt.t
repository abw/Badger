#========================================================================
#
# t/codec/tt.t
#
# Test the Badger::Codec::TT module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ./lib ../lib ../../lib );
use Badger::Test 
    debug => 'Badger::Codec::TT',
    tests => 32,
    args  => \@ARGV;

use Badger::Codec::TT;
use constant Codec => 'Badger::Codec::TT';


#-----------------------------------------------------------------------
# basic encode/decode throughput tests
#-----------------------------------------------------------------------

my $data = {
    pi    => 3.14,
    e     => 2.718,
    karma => -99,
    hash  => {
        things => [ qw( foo bar baz ) ],
    }
};

my $encoded = Codec->encode($data);
ok( $encoded, 'encoded data' );

my $decoded = Codec->decode($encoded);
ok( $decoded, 'decoded data' );


is( $decoded->{ pi    }, $data->{ pi    }, 'pi remains constant' );
is( $decoded->{ e     }, $data->{ e     }, 'e remains constant' );
is( $decoded->{ karma }, $data->{ karma }, 'karma is unchaged' );
is( $decoded->{ hash  }->{ things }->[0], 'foo', 'foo is unchanged' );


#-----------------------------------------------------------------------
# define some more data and a comparison sub for different syntax tests
#-----------------------------------------------------------------------

$data = {
    message => 'Hello World, this is some text',
    things  => ['a list', 'of some things'],
    stuff   => {
        pi  => 3.14,
        foo => [ { nested => 'hash' }, ['nested', 'list' ] ],
    },
};


sub compare_decoded_data {
    my ($name, $decoded, $data) = @_;
    is( $decoded->{message}, $data->{ message }, "$name message" );
    is( $decoded->{things}->[0], $data->{things}->[0], "$name things 0" );
    is( $decoded->{things}->[1], $data->{things}->[1], "$name things 1" );
    is( $decoded->{stuff}->{pi}, $data->{stuff}->{ pi }, "$name pi" );
    is( $decoded->{stuff}->{foo}->[0]->{nested}, $data->{stuff}->{foo}->[0]->{nested}, "$name foo.nested $data->{stuff}->{foo}->[0]->{nested}" );
    is( $decoded->{stuff}->{foo}->[1]->[1], $data->{stuff}->{foo}->[1]->[1], "$name foo.nested $data->{stuff}->{foo}->[1]->[1]" );
}

#-----------------------------------------------------------------------
# Try it first with Perlish data syntax...
#-----------------------------------------------------------------------

$decoded = Codec->decode(<<EOF);
{
    message => 'Hello World, this is some text',
    things  => ['a list', 'of some things'],
    stuff   => {
        pi  => 3.14,
        foo => [ { nested => 'hash' }, ['nested', 'list' ] ],
    },
}
EOF
ok( $decoded, 'decoded Perlish data' );
compare_decoded_data( Perlish => $decoded, $data );


#-----------------------------------------------------------------------
# ...then with reduced TT syntax...
#-----------------------------------------------------------------------

$decoded = Codec->decode(<<EOF);
{
    message = 'Hello World, this is some text'
    things  = ['a list' 'of some things']
    stuff   = {
        pi  = 3.14
        foo = [ { nested = 'hash' } ['nested' 'list' ] ]
    }
}
EOF
ok( $decoded, 'decoded TTish data' );
compare_decoded_data( TTish => $decoded, $data );

#-----------------------------------------------------------------------
# ...and again with JSON syntax
#-----------------------------------------------------------------------

$decoded = Codec->decode(<<EOF);
{
    message: 'Hello World, this is some text',
    things: ['a list' 'of some things'],
    stuff: {
        pi:  3.14,
        foo: [ { nested: 'hash' }, ['nested', 'list' ] ]
    }
}
EOF
ok( $decoded, 'decoded JSONish data' );
compare_decoded_data( JSONish => $decoded, $data );

#-----------------------------------------------------------------------
# test different output formats
#-----------------------------------------------------------------------

$data = {
    pi => 3.14,
    e  => 2.718,
    foo => ['bar', 'baz'],
};

my $codec = Codec->new( assign => '=>', comma => ',' );
is( $codec->encode($data), "{e=>2.718,foo=>['bar','baz'],pi=>3.14}", 'encoded Perlishly' );

$codec = Codec->new( assign => ':' );
is( $codec->encode($data), "{e:2.718 foo:['bar' 'baz'] pi:3.14}", 'encoded JSONishly' );


#-----------------------------------------------------------------------
# check we can load it via Badger::Codecs
#-----------------------------------------------------------------------

package test1;
use Badger::Codecs codec => 'TT';
use Badger::Test;

is( encode({ msg => 'Hello' }), "{msg='Hello'}", 'encoded via TT codec' );

package test2;
use Badger::Codecs codec => 'tt';
use Badger::Test;

is( encode({ msg => 'Hello' }), "{msg='Hello'}", 'encoded via tt codec' );

package test3;
use Badger::Codecs;
use Badger::Test;

$codec = Badger::Codecs->codec( tt => { assign => ':=' } );
is( $codec->encode({ msg => 'Hello' }), "{msg:='Hello'}", 'encoded via custom tt codec' );
    

__END__

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

