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
use Badger::Utils qw( UTILS blessed );
use Badger::Debug;
use Badger::Test 
    tests => 11,
    debug => 'Badger::Utils',
    args  => \@ARGV;

is( UTILS, 'Badger::Utils', 'got UTILS defined' );
ok( blessed bless([], 'Wibble'), 'got blessed' );


#-----------------------------------------------------------------------
# test xprintf()
#-----------------------------------------------------------------------

is( UTILS->xprintf('The %s sat on the %s', 'cat', 'mat'),
    'The cat sat on the mat', 'xprintf s s' );

is( UTILS->xprintf('The %1$s sat on the %2$s', 'cat', 'mat'),
    'The cat sat on the mat', 'xprintf 1 2' );

is( UTILS->xprintf('The %2$s sat on the %1$s', 'cat', 'mat'),
    'The mat sat on the cat', 'xprintf 2 1' );

is( UTILS->xprintf('The <2> sat on the <1>', 'cat', 'mat'),
    'The mat sat on the cat', 'xprintf <2> <1>' );

is( UTILS->xprintf('The <1:s> sat on the <2:s>', 'cat', 'mat'),
    'The cat sat on the mat', 'xprintf <1:s> <2:s>' );

is( UTILS->xprintf('The <1:5s> sat on the <2:5s>', 'cat', 'mat'),
    'The   cat sat on the   mat', 'xprintf <1:5s> <2:5s>' );

is( UTILS->xprintf('The <1:-5s> sat on the <2:-5s>', 'cat', 'mat'),
    'The cat   sat on the mat  ', 'xprintf <1:-5s> <2:-5s>' );

is( UTILS->xprintf('<1> is <2:4.3f>', pi => 3.1415926),
    'pi is 3.142', 'pi is 3.142' );

is( UTILS->xprintf('<1> is <2:4.3f>', e => 2.71828),
    'e is 2.718', 'pi is 2.718' );
    


__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

