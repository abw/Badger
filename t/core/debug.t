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
    tests => 2,
    args  => \@ARGV;

my $obj = Badger::Base->new();
ok( $obj->debug("Hello World\n"), 'hello world' );
ok( $obj->debug('Hello ', "Badger\n"), 'hello badger' );
