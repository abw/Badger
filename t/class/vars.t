#============================================================= -*-perl-*-
#
# t/class/vars.t
#
# Test the Badger::Class::Vars module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( t/class/lib ../t/class/lib ./lib ../lib ../../lib );

use Badger::Test
    tests => 31,
    debug => 'Badger::Class::Vars',
    args  => \@ARGV;


#-----------------------------------------------------------------------
# My::Vars1 uses Badger::Class::Vars directly and defines vars using
# a single string:
#   use Badger::Class::Vars '$FOO @BAR %BAZ';
#-----------------------------------------------------------------------

use My::Vars1;

is( $My::Vars1::FOO, 'ten', '$FOO is defined in My::Vars1' );
is( join(', ', @My::Vars1::BAR), '10, 20, 30', '@BAR is defined in My::Vars1' );
is( join(', ', sort keys %My::Vars1::BAZ), 'x, y', '%BAZ is defined in My::Vars1' );


#-----------------------------------------------------------------------
# My::Vars2 uses Badger::Class::Vars directly and defines vars using
# a list of named params:
#   use Badger::Class::Vars 
#       '$FOO' => 'eleven',
#       '@BAR' => (11, 21, 31),
#       '%BAZ' => (a => 101, b => 202);
#-----------------------------------------------------------------------

use My::Vars2;

is( $My::Vars2::FOO, 'eleven', '$FOO is defined in My::Vars2' );
is( join(', ', @My::Vars2::BAR), '11, 21, 31', '@BAR is defined in My::Vars2' );
is( join(', ', sort keys %My::Vars2::BAZ), 'a, b', '%BAZ is defined in My::Vars2' );


#-----------------------------------------------------------------------
# My::Vars3 is like My::Vars2 but uses a hash ref:
#   use Badger::Class::Vars {
#       '$FOO' => 'twelve',
#       '@BAR' => [12, 22, 32],
#       '%BAZ' => {c => 310, d => 420},
#   };
#-----------------------------------------------------------------------

use My::Vars3;

is( $My::Vars3::FOO, 'twelve', '$FOO is defined in My::Vars3' );
is( join(', ', @My::Vars3::BAR), '12, 22, 32', '@BAR is defined in My::Vars3' );
is( join(', ', sort keys %My::Vars3::BAZ), 'c, d', '%BAZ is defined in My::Vars3' );


#-----------------------------------------------------------------------
# My::Vars4 defines vars using a list ref: 
#    use Badger::Class::Vars ['$FOO', '@BAR', '%BAZ'];
#-----------------------------------------------------------------------

use My::Vars4;

is( $My::Vars4::FOO, 'thirteen', '$FOO is defined in My::Vars4' );
is( join(', ', @My::Vars4::BAR), '13, 23, 33', '@BAR is defined in My::Vars4' );
is( join(', ', sort keys %My::Vars4::BAZ), 'e, f', '%BAZ is defined in My::Vars4' );


#-----------------------------------------------------------------------
# My::Vars5 defines vars using Badger::Class
#   use Badger::Class
#       vars => '$FOO @BAR %BAZ';
#-----------------------------------------------------------------------

use My::Vars5;

is( $My::Vars5::FOO, 'fourteen', '$FOO is defined in My::Vars5' );
is( join(', ', @My::Vars5::BAR), '14, 24, 34', '@BAR is defined in My::Vars5' );
is( join(', ', sort keys %My::Vars5::BAZ), 'g, h', '%BAZ is defined in My::Vars5' );


#-----------------------------------------------------------------------
# My::Vars6 defines vars using Badger::Class and a hash ref
#   use Badger::Class
#       vars => {
#           '$FOO' => 'fifteen',
#           '@BAR' => [15, 25, 35],
#           '%BAZ' => {i => 310, j => 420},
#       };
#-----------------------------------------------------------------------

use My::Vars6;

is( $My::Vars6::FOO, 'fifteen', '$FOO is defined in My::Vars6' );
is( join(', ', @My::Vars6::BAR), '15, 25, 35', '@BAR is defined in My::Vars6' );
is( join(', ', sort keys %My::Vars6::BAZ), 'i, j', '%BAZ is defined in My::Vars6' );


#-----------------------------------------------------------------------
# My::Vars7 defines vars using Badger::Class and a hash ref which tests
# all the various variable types.
#   use Badger::Class
#       vars => {
#           X      => 1,
#           Y      => [2, 3],
#           Z      => { a => 99 },
#           HAI    => sub { 'Hello ' . (shift || 'World') },
#           '$FOO' => 25,
#           '$BAR' => [11, 21, 31],
#           '$BAZ' => { wam => 'bam' },
#           '$BAI' => sub { 'Goodbye ' . (shift || 'World') },
#           '@WIZ' => [100, 200, 300],
#           '@WAZ' => 99,
#           '%WOZ' => { ping => 'pong' },
#       };
#-----------------------------------------------------------------------

use My::Vars7;

is( $My::Vars7::X, 1, 'vars X is 1' );
is( join(',', @$My::Vars7::Y), '2,3', 'vars Y is [2,3]' );
is( $My::Vars7::Z->{ a }, 99, 'vars Z is { a => 99 }' );
is( $My::Vars7::HAI->(), 'Hello World', 'vars HAI is sub' );
is( $My::Vars7::HAI->('Badger'), 'Hello Badger', 'vars HAI is sub with arg' );

is( $My::Vars7::FOO, 25, 'vars $FOO is 25' );
is( join(',', @$My::Vars7::BAR), '11,21,31', 'vars $BAR is [11,21,31]' );
is( $My::Vars7::BAZ->{ wam }, 'bam', 'vars $BAZ is { wam => "bam" }' );
is( $My::Vars7::BAI->(), 'Goodbye World', 'vars BAI is sub' );
is( $My::Vars7::BAI->('Badger'), 'Goodbye Badger', 'vars BAI is sub with arg' );

is( join(',', @My::Vars7::WIZ), '100,200,300', 'vars @WIZ is (100, 200, 300)' );
is( join(',', @My::Vars7::WAZ), '99', 'vars @WAZ is (99)' );
is( join(',', map { "$_ => $My::Vars7::WOZ{$_}" } keys %My::Vars7::WOZ), 'ping => pong', 'vars %WOZ is (ping => "pong")' );

