#============================================================= -*-perl-*-
#
# t/core/config.t
#
# Test the Badger::Config module.
#
# Copyright (C) 2008 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;

use lib qw( ./lib ../lib ../../lib );
use Badger::Config;
use Badger::Test 
    tests => 20,
    debug => 'Badger::Config',
    args  => \@ARGV;

my $pkg = 'Badger::Config';

my $config = $pkg->new({ x => 10, y => 20 });
is( $config->x, 10, 'x is 10' );
is( $config->y, 20, 'y is y0' );

eval { $config->z };
like( $@, qr/Invalid method 'z' called on Badger::Config/, 'bad method' );

$config = $pkg->new( data => { x => 10, y => 20 }, items => 'a b c' );
is( $config->x, 10, 'x is 10' );
is( $config->y, 20, 'y is y0' );

ok( ! $config->a, 'a is undefined' );
ok( ! $config->b, 'b is undefined' );
ok( ! $config->c, 'c is undefined' );


#-----------------------------------------------------------------------
# test get() method
#-----------------------------------------------------------------------

package Wibble;

sub wobble {
    return 'wubble';
}

package main;

$config = $pkg->new({
    foo => {
        bar => {
            baz => [ 'wig', { wam => 'bam' } ],
        },
    },
    yip    => 'pee',
    hoo    => 'ray',
    wibble => bless({ }, 'Wibble'),
});
ok( $config, 'got config with nested data' );
is( $config->get('yip'), 'pee', 'yippee' );
is( $config->get('hoo'), 'ray', 'hooray' );
is( $config->get('foo.bar.baz.0'), 'wig', 'wig' );
is( $config->get('foo/bar/baz/1/wam'), 'bam', 'wam bam' );
is( $config->get('wibble', 'wobble'), 'wubble', 'wibble wobble' );


#-----------------------------------------------------------------------
# examples from docs
#-----------------------------------------------------------------------

$config = Badger::Config->new(
    user => {
        name => {
            given  => 'Arthur',
            family => 'Dent',
        },
        email => [
            'arthur@dent.org',
            'dent@heart-of-gold.com',
        ],
    },
    things => sub {
        return ['The Book', 'Towel', sub { return { babel => 'fish' } } ]
    },
);

is( $config->get('user', 'name', 'given'), 'Arthur', 'Arthur' );
is( $config->get('user.name.family'),      'Dent', 'Dent' );
is( $config->get('user/email/0'),          'arthur@dent.org', 'arthur@dent.org' );
is( $config->get('user email 1'),          'dent@heart-of-gold.com', 'dent@heart-of-gold.com' );
is( $config->get('things.2.babel'),        'fish', 'babel fish' );


# a trivial object class
package Example;
use base 'Badger::Base';
    
sub wibble {
    return 'wobble';
}
    
package main;
    
$config = Badger::Config->new(
    function => sub {
        return {
            object => Example->new(),
        }
    }
);
is( $config->get('function.object.wibble'), 'wobble', 'wobble' );

__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
