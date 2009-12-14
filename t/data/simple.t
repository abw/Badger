#============================================================= -*-perl-*-
#
# t/data/simple.t
#
# Test the Badger::Data::Type::Simple module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ./lib ../lib ../../lib );

use Badger::Test 
    debug  => 'Badger::Data::Type::Simple',
    args   => \@ARGV,
    tests  => 1;

use Badger::Data::Type::Simple;
pass('loaded Badger::Data::Type::Simple');

use constant SIMPLE => 'Badger::Data::Type::Simple';

