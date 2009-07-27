#============================================================= -*-perl-*-
#
# t/utils.t
#
# Test the Badger::Utils module.
#
# Written by Andy Wardley <abw@wardley.org>.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;

use lib qw( t/core/lib ./lib ../lib ../../lib );
use Badger::Utils 'UTILS blessed xprintf reftype textlike plural';
use Badger::Debug;
use Badger::Test 
    tests => 45,
    debug => 'Badger::Utils',
    args  => \@ARGV;

is( UTILS, 'Badger::Utils', 'got UTILS defined' );
ok( blessed bless([], 'Wibble'), 'got blessed' );


#-----------------------------------------------------------------------
# test is_object()
#-----------------------------------------------------------------------

package My::Base;
use base 'Badger::Base';

package My::Sub;
use base 'My::Base';

package main;
use Badger::Utils 'is_object';

my $obj = My::Sub->new;
ok(   is_object( 'My::Sub'   => $obj ), 'object is a My::Sub' );
ok(   is_object( 'My::Base'  => $obj ), 'object is a My::Base' );
ok( ! is_object( 'My::Other' => $obj ), 'object is not My::Other' );


#-----------------------------------------------------------------------
# test params() and self_params()
#-----------------------------------------------------------------------

use Badger::Utils 'params';

my $hash = {
    a => 10,
    b => 20,
};
is( params($hash), $hash, 'params returns hash ref' );
is( params(%$hash)->{ a }, 10, 'params merged named param list' );


package Selfish;

use Badger::Class
    base    => 'Badger::Base',
    as_text => 'text',                  # for testing textlike()
    utils   => 'self_params';

sub test1 {
    my ($self, $params) = self_params(@_);
    return ($self, $params);
}

sub text {                              # for testing textlike()
    return 'Hello World';
}

package main;
my $selfish = Selfish->new();
my ($s, $p) = $selfish->test1($hash);
is( $s, $selfish, 'self_params returns self' );
is( $p, $hash, 'self_params returns params' );
($s, $p) = $selfish->test1(%$hash);
is( $s, $selfish, 'self_params returns self again' );
is( $p->{a}, 10, 'self_params returns params again' );


#-----------------------------------------------------------------------
# test textlike
#-----------------------------------------------------------------------

ok( textlike 'hello', 'string is textlike' );
ok( textlike $selfish, 'selfish object is textlike' );
ok( ! textlike $obj, 'object is not textlike' );
ok( ! textlike [10], 'list is not textlike' );
ok( ! textlike sub { 'foo' }, 'sub is not textlike' );


#-----------------------------------------------------------------------
# test xprintf()
#-----------------------------------------------------------------------

is( xprintf('The %s sat on the %s', 'cat', 'mat'),
    'The cat sat on the mat', 'xprintf s s' );

is( xprintf('The %1$s sat on the %2$s', 'cat', 'mat'),
    'The cat sat on the mat', 'xprintf 1 2' );

is( xprintf('The %2$s sat on the %1$s', 'cat', 'mat'),
    'The mat sat on the cat', 'xprintf 2 1' );

is( xprintf('The <2> sat on the <1>', 'cat', 'mat'),
    'The mat sat on the cat', 'xprintf <2> <1>' );

is( xprintf('The <1:s> sat on the <2:s>', 'cat', 'mat'),
    'The cat sat on the mat', 'xprintf <1:s> <2:s>' );

is( xprintf('The <1:5s> sat on the <2:5s>', 'cat', 'mat'),
    'The   cat sat on the   mat', 'xprintf <1:5s> <2:5s>' );

is( xprintf('The <1:-5s> sat on the <2:-5s>', 'cat', 'mat'),
    'The cat   sat on the mat  ', 'xprintf <1:-5s> <2:-5s>' );

is( xprintf('<1> is <2:4.3f>', pi => 3.1415926),
    'pi is 3.142', 'pi is 3.142' );

is( xprintf('<1> is <2:4.3f>', e => 2.71828),
    'e is 2.718', 'pi is 2.718' );



#-----------------------------------------------------------------------
# test we can import utility functions from Scalar::Util, List::Util,
# List::MoreUtils and Hash::Util.
#-----------------------------------------------------------------------

use Badger::Utils 'reftype looks_like_number numlike first max lock_hash';

my $object = bless [ ], 'Badger::Test::Object';
is( reftype $object, 'ARRAY', 'reftype imported' );

ok( looks_like_number 23, 'looks_like_number imported' );
ok( numlike 42, 'numlike imported' );

my @items = (10, 22, 33, 42);
my $first = first { $_ > 25 } @items;
is( $first, 33, 'list first imported' );

my $max = max 2.718, 3.14, 1.618;
is( $max, 3.14, 'list max imported' );

my %hash = (x => 10);
lock_hash(%hash);
ok( ! eval { $hash{x} = 20 }, 'could not modify read-only hash' );
like( $@, qr/Modification of a read-only value attempted/, 'got read-only error' );


#-----------------------------------------------------------------------
# Import from Badger::Timestamp
#-----------------------------------------------------------------------

use Badger::Utils 'Timestamp Now';

my $ts = Now;
is( ref $ts, 'Badger::Timestamp', 'Now is a Badger::Timestamp' );

$ts = Timestamp('2009/05/25 11:31:00');
is( ref $ts, 'Badger::Timestamp', 'Timestamp returned a Badger::Timestamp' );
is( $ts->year, 2009, 'got timestamp year' );
is( $ts->month, '05', 'got timestamp month' );
is( $ts->day, 25, 'got timestamp day' );


#-----------------------------------------------------------------------
# Import from Badger::Logic
#-----------------------------------------------------------------------

use Badger::Utils 'Logic';

my $logic = Logic('cheese and biscuits');
ok( blessed $logic && $logic->isa('Badger::Logic'), 'Logic returned a Badger::Logic object' );



#-----------------------------------------------------------------------
# test plural()
#-----------------------------------------------------------------------

is( plural('gateway'), 'gateways', 'pluralised gateway/gateways' );
is( plural('fairy'), 'fairies', 'pluralised fairy/fairies' );


#-----------------------------------------------------------------------
# test random_name()
#-----------------------------------------------------------------------

use Badger::Utils 'random_name';

is( length random_name(), $Badger::Utils::RANDOM_NAME_LENGTH, 
    "default random_name() length is $Badger::Utils::RANDOM_NAME_LENGTH" );
is( length random_name(16), 16, 'random_name(16) length is 16');
is( length random_name(32), 32, 'random_name(16) length is 32');
is( length random_name(48), 48, 'random_name(16) length is 48');
is( length random_name(64), 64, 'random_name(16) length is 64');


__END__

# Hmmm... I didn't realise that List::MoreUtils wasn't a core Perl module.

use Badger::Utils 'any all';
    
my $any = any { $_ % 11 == 0 } @items;      # divisible by 11
ok( $any, 'any list imported' );

my $all = all { $_ % 11 == 0 } @items;      # divisible by 11
ok( ! $all, 'all list imported' );

my $true = true { $_ % 11 == 0 } @items;    # divisible by 11
is( $true, 2, 'true list imported' );


__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

