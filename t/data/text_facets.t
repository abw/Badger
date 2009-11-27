#============================================================= -*-perl-*-
#
# t/data/text_facets.t
#
# Test the Badger::Data::Facets module for text facets.
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
    tests => 30,
    debug => 'Badger::Data::Facet::Text',
    args  => \@ARGV;

use Badger::Data::Facets;
use constant FACETS => 'Badger::Data::Facets';


#-----------------------------------------------------------------------
# length
#-----------------------------------------------------------------------

my $length = FACETS->facet( 'text.length' => 23 );
ok( $length, 'got text.length facet from number' );
is( $length->length, 23, 'got length facet with value 23' );

$length = FACETS->facet( text_length => { length => 6 } );
ok( $length, 'got text_length facet from hash ref' );
is( $length->length, 6, 'got length facet with value 6' );

my $text = 'abcdef';
ok( $length->validate(\$text), 'text is 6 characters long' );

$text = 'abcde';
ok( ! $length->try( validate => \$text ), 'text is only 5 characters long' );
is( $length->reason->type, 
    'data.facet.text.length',
    'got short text error message' 
);
is( $length->reason->info, 
    'Text should be 6 characters long (got 5)', 
    'got short text error message' 
);


#-----------------------------------------------------------------------
# min_length
#-----------------------------------------------------------------------

$length = FACETS->facet( 'text.min_length' => 3 );
ok( $length, 'got text.min_length facet' );

$length = FACETS->facet( text_min_length => 3 );
ok( $length, 'got text_min_length facet' );

$text = 'ab';
ok( ! $length->try( validate => \$text ), 'min length fail on 2 characters' );
is( $length->reason->info, 'Text should be at least 3 characters long (got 2)', 'min length text reason' );

$text = 'abc';
ok( $length->validate(\$text), 'min length on 3 characters' );

$text = 'abcdef';
ok( $length->validate(\$text), 'min length on 6 characters' );


#-----------------------------------------------------------------------
# max_length
#-----------------------------------------------------------------------

$length = FACETS->facet( 'text.max_length' => 3 );
ok( $length, 'got text.max_length facet' );

$length = FACETS->facet( text_max_length => { max_length => 3 } );
ok( $length, 'got text_max_length facet' );

$text = 'abcd';
ok( ! $length->try( validate => \$text ), 'max length fail on 4 characters' );
is( $length->reason->info, 'Text should be at most 3 characters long (got 4)', 'max length text reason' );

$text = 'abc';
ok( $length->validate(\$text), 'max length on 3 characters' );

$text = 'ab';
ok( $length->validate(\$text), 'max length on 2 characters' );


#-----------------------------------------------------------------------
# pattern
#-----------------------------------------------------------------------

my $pattern = FACETS->facet( 'text.pattern' => '^\w+$' );
ok( $pattern, 'got pattern facet' );

$text = 'Hello World!';
ok( ! $pattern->try( validate => \$text ), 'pattern fail on 2 words' );
is( $pattern->reason->info, 'Text does not match pattern: ^\w+$', 'pattern fail reason' );

$text = 'foo';
ok( $pattern->validate(\$text), 'pattern match on foo' );


#-----------------------------------------------------------------------
# whitespace
#-----------------------------------------------------------------------

my $fold = FACETS->facet( 'text.whitespace' => 'fold' );
ok( $fold, 'got whitespace folding facet' );

$text = "Hello\nWorld!";
ok( $fold->validate(\$text), 'called whitespace folding facet' );
is( $text, 'Hello World!', 'folded whitespace' );

my $collapse = FACETS->facet( 'text.whitespace' => 'collapse' );
ok( $collapse, 'got whitespace collapsing facet' );

$text = "   \n\nHello\n\n\nBadger!\n\n\  ";
ok( $collapse->validate(\$text), 'called whitespace collapsing facet' );
is( $text, 'Hello Badger!', 'collapsed whitespace' );



__END__


#-----------------------------------------------------------------------
# any
#-----------------------------------------------------------------------

my $any = FACETS->facet( any => ['foo', 'bar'] );
ok( $any, 'got any facet' );
ok( ! $any->try( validate => 'baz' ), 'any fail on baz' );
is( $any->reason->info, 'Text does not match any of the permitted values: baz', 'any fail reason' );
ok( $any->validate('foo'), 'any match on foo' );


