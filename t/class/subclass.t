#============================================================= -*-perl-*-
#
# t/class/subclass.t
#
# Test the My::Class subclass of Badger::Class.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Run with -h option for help.  
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( t/class/lib ../t/class/lib ./lib ../lib ../../lib );

use Badger::Test
    debug => 'My::Class',           # run with -d option for debugging
    args  => \@ARGV,
    tests => 7;

package Badger::Test::SubClass1;

use My::Class
    fields => 'x y z';

package main;

my $obj = Badger::Test::SubClass1->new( x => 1, y => 2, z => 3 );
ok( $obj, 'created new object' );

is( $obj->x, 1, 'x is 1' );
is( $obj->y, 2, 'x is 2' );
is( $obj->z, 3, 'x is 3' );

$obj->x(10);
$obj->y(20);
$obj->z(30);

is( $obj->x, 10, 'x is 10' );
is( $obj->y, 20, 'x is 20' );
is( $obj->z, 30, 'x is 30' );

1;
