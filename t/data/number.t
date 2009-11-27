#============================================================= -*-perl-*-
#
# t/data/number.t
#
# Test the Badger::Data::Type::Number module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ./lib ../lib ../../lib );

use Badger::Test 
    debug  => 'Badger::Data::Type::Number',
    args   => \@ARGV,
    tests  => 3;

use Badger::Debug ':debug :dump';
use constant 
    NUMBER => 'Badger::Data::Type::Number';

use Badger::Data::Type::Number;
pass('loaded Badger::Data::Type::Number');

my $Num = NUMBER->new;

my $n = 10;
ok( $Num->validate(\$n), "$n is a number" );

$n = 'plankton';
ok( ! $Num->try->validate(\$n), "$n is not a number" );