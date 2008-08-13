#============================================================= -*-perl-*-
#
# t/debug.t
#
# Test the Badger::Debug module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;

use lib qw( ./lib ../lib ../../lib );
use Badger::Debug;
use Badger::Base;
use Badger::Test 
    tests => 4,
    args  => \@ARGV;


#-----------------------------------------------------------------------
# tied object to catch output to STDERR
#-----------------------------------------------------------------------

package Badger::TieString;

sub TIEHANDLE {
    my ($class, $textref) = @_;
    bless $textref, $class;
}
sub PRINT {
    my $self = shift;
    $$self .= join('', @_);
}

package main;

my $dbgmsg;
tie *STDERR, 'Badger::TieString', \$dbgmsg;

my $obj = Badger::Base->new();

ok( $obj->debug("Hello World\n"), 'hello world' );
like( $dbgmsg, qr/\[Badger::Base \(main\) line \d\d\] Hello World/, 'got debug message 1' );

$dbgmsg = '';

ok( $obj->debug('Hello ', "Badger\n"), 'hello badger' );
like( $dbgmsg, qr/\[Badger::Base \(main\) line \d\d\] Hello Badger/, 'got debug message 2' );


