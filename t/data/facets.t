#============================================================= -*-perl-*-
#
# t/data/facets.t
#
# Test the Badger::Data::Facets module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ./lib ../lib ../../lib );

use Badger::Test 
    tests => 1,
    debug => 'Badger::Data::Type::Simple',
    args  => \@ARGV;

use Badger::Data::Facets;
use constant FACETS => 'Badger::Data::Facets';

pass('loaded Badger::Data::Facets');