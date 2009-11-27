#============================================================= -*-perl-*-
#
# t/data/list_facets.t
#
# Test the Badger::Data::Facets module for list facets.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ./lib ../lib ../../lib );

#use Badger::Debug
#    modules => 'Badger::Factory';
    
use Badger::Test 
    tests => 20,
    debug => 'Badger::Data::Facet::List',
    args  => \@ARGV;

use Badger::Data::Facets;
use constant FACETS => 'Badger::Data::Facets';


#-----------------------------------------------------------------------
# size
#-----------------------------------------------------------------------

my $size = FACETS->facet( 'list.size' => 23 );
ok( $size, 'got size facet from number' );
is( $size->size, 23, 'got size facet with value 23' );

$size = FACETS->facet( 'list.size' => { size => 6 } );
ok( $size, 'got size facet from hash ref' );
is( $size->size, 6, 'got size facet with value 6' );

ok( $size->validate([1..6]), 'list is 6 element long' );
ok( ! $size->try( validate => [1..5] ), 'list is only 5 elements long' );
is( $size->reason->type, 
    'data.facet.list.size',
    'got short size error message' 
);
is( $size->reason->info, 
    'List should have 6 elements (got 5)', 
    'got short list error message' 
);


#-----------------------------------------------------------------------
# min_size
#-----------------------------------------------------------------------

$size = FACETS->facet( 'list.min_size' => 3 );
ok( $size, 'got list.min_size facet' );

$size = FACETS->facet( list_min_size => { min_size => 3 } );
ok( $size, 'got list_min_size facet' );

ok( ! $size->try( validate => [1] ), 'min size fail on 1 list element' );
is( $size->reason->info, 'List should have at least 3 elements (got 1)', 'min size list reason' );
ok( $size->validate([10,20,30]), 'min size on 3 list elements' );
ok( $size->validate([11,21,31,41,51,61]), 'min size on 6 list elements' );



#-----------------------------------------------------------------------
# max_size
#-----------------------------------------------------------------------

$size = FACETS->facet( 'list.max_size' => 3 );
ok( $size, 'got list.max_size facet' );

$size = FACETS->facet( list_max_size => { max_size => 3 } );
ok( $size, 'got list_max_size facet' );

ok( ! $size->try( validate => [1,2,3,4] ), 'max size fail on 4 list elements' );
is( $size->reason->info, 'List should have at most 3 elements (got 4)', 'max size list reason' );
ok( $size->validate([10,20,30]), 'max size on 3 list elements' );
ok( $size->validate([11,21]), 'max size on 2 list elements' );



__END__
#-----------------------------------------------------------------------
# pattern
#-----------------------------------------------------------------------

my $pattern = FACETS->facet( pattern => '^\w+$' );
ok( $pattern, 'got pattern facet' );
ok( ! $pattern->try( validate => 'Hello World!' ), 'pattern fail on 2 words' );
is( $pattern->reason->info, 'Text does not match pattern: ^\w+$', 'pattern fail reason' );
ok( $pattern->validate('foo'), 'pattern match on foo' );


#-----------------------------------------------------------------------
# any
#-----------------------------------------------------------------------

my $any = FACETS->facet( any => ['foo', 'bar'] );
ok( $any, 'got any facet' );
ok( ! $any->try( validate => 'baz' ), 'any fail on baz' );
is( $any->reason->info, 'Text does not match any of the permitted values: baz', 'any fail reason' );
ok( $any->validate('foo'), 'any match on foo' );


#-----------------------------------------------------------------------
# whitespace
#-----------------------------------------------------------------------

my $fold = FACETS->facet( whitespace => 'fold' );
ok( $fold, 'got whitespace folding facet' );
my $text = $fold->validate("Hello\nWorld!");
is( $text, 'Hello World!', 'folded whitespace' );

my $collapse = FACETS->facet( whitespace => 'collapse' );
ok( $collapse, 'got whitespace collapsing facet' );
$text = $collapse->validate("   \n\nHello\n\n\nBadger!\n\n\  ");
is( $text, 'Hello Badger!', 'collapsed whitespace' );

