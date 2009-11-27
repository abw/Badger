#============================================================= -*-perl-*-
#
# t/data/text.t
#
# Test the Badger::Data::Type::Text module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ./lib ../lib ../../lib );

use Badger::Test 
    debug  => 'Badger::Data::Type::Text',
    args   => \@ARGV,
    tests  => 3;

use Badger::Debug ':debug :dump';
use constant 
    TEXT => 'Badger::Data::Type::Text';

use Badger::Data::Type::Text;
pass('loaded Badger::Data::Type::Text');

my $Text = TEXT->new;
ok( $Text, 'created text' );

my $facets = $Text->facets;
ok( $facets, 'fetched facets' );

#main->debug("facets: ", main->dump_data($facets));
