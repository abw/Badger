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
use Badger::Utils 'UTILS blessed xprintf';
use Badger::Debug;
use Badger::Test 
    tests => 20,
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
use base 'Badger::Base';
use Badger::Utils 'self_params';

sub test1 {
    my ($self, $params) = self_params(@_);
    return ($self, $params);
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


    


__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

