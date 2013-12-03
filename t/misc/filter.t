#============================================================= -*-perl-*-
#
# t/misc/filter.t
#
# Test the Badger::Filter module.
#
# Copyright (C) 2013 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Debug ':all';
use Badger::Test 
    tests => 6,
    debug => 'Badger::Filter',
    args  => \@ARGV;

# behold the Ron Swanson picnic filter!

use Badger::Filter 'Filter';
my $pkg  = 'Badger::Filter';
my $flt1 = $pkg->new(
    include => [
        qw(meat cheese ham eggs),
        qr/beer|wine/,
        sub { $_[0] eq 'soda' },
    ],
    exclude => [
        'root beer',
        qr/alcohol-free|salad|diet/,
        sub {
            shift =~ /ferret/;
        }
    ]
);
ok( $flt1, 'created first filter' );

my @things = (
    qw( meat neat cheese peas ham eggs beer wine soda stoat monkey ferret ),
    'root beer',
    'alcohol-free beer',
    'alcohol-free wine',
    'diet soda',
    'green salad',
    'green eggs',
    'diet salad',
    'diet meat',
    'more beer',
);

my @in = $flt1->accept(@things);
my $in = join(', ', @in);
is( 
    $in, 
    'meat, cheese, ham, eggs, beer, wine, soda, more beer', 
    'matched in items'
);

my @out = $flt1->reject(@things);
my $out = join(', ', @out);
is( 
    $out, 
    'neat, peas, stoat, monkey, ferret, root beer, alcohol-free beer, alcohol-free wine, diet soda, green salad, green eggs, diet salad, diet meat', 
    'matched out items'
);

#-----------------------------------------------------------------------------
# Test Filter() sub
#-----------------------------------------------------------------------------

my $flt2 = Filter( include => qr/beer/ );
my $suds = join(', ', $flt2->accept(@things));
is( 
    $suds, 
    'beer, root beer, alcohol-free beer, more beer', 
    'matched beer items'
);

#-----------------------------------------------------------------------------
# Test simple accept option
#-----------------------------------------------------------------------------

my $all = Filter( accept => 'all' );

is (
    join(', ', $all->accept(qw( a b c d ))),
    'a, b, c, d',
    'accept all',
);

my $none = Filter( accept => 'none' );
is (
    join(', ', $none->accept(qw( a b c d ))),
    '',
    'accept none',
);



