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
    tests  => 8;

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

my $type = TEXT->new( 
    facets => [
        min_length => 3,
        max_length => 6,
    ]
);

my $good  = 'hello';
my $short = 'hi';
my $long  = 'greetings';

ok( $type->validate(\$good), 'good string is good' );

ok( ! $type->try->validate(\$short), 'short string is not good' );
is( $type->reason->info, 
    'Text should be at least 3 characters long (got 2)', 
    'short string is too short' 
);

ok( ! $type->try->validate(\$long), 'long string is not good' );
is( $type->reason->info, 
    'Text should be at most 6 characters long (got 9)', 
    'long string is too long' 
);

