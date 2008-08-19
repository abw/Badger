#============================================================= -*-perl-*-
#
# t/pod/list.t
#
# Test the Badger::Pod::Node::list module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2008 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Pod 'Nodes';
use Badger::Utils 'reftype';
use Badger::Test
    tests => 22,
    debug => 'Badger::Pod::Node::List',
    args  => \@ARGV;
    
my $nodes = Nodes->new;
ok( $nodes, 'got nodes object' );

my $list  = $nodes->node('list');
ok( $list, 'got list node' );

# simple push/pop/shift/unshift ops
ok( $list->push('one'), 'pushed one onto list' );
ok( $list->unshift('two'), 'unshifted two onto list' );
is( $list->pop, 'one', 'popped one onto list' );
is( $list->shift, 'two', 'shifted two off list' );

# test constructor with arguments
$list = $nodes->node( list => 10, 20, 30 );
is( join('/', @$list), '10/20/30', 'list constructor' );

# each() returns unblessed list ref in scalar context
my $items = $list->each;
is( ref $items, 'ARRAY', 'got list ref back from each()' );
is( scalar(@$items), 3, 'got 3 items in list ref' );

# or list of items in list context
my @items = $list->each;
is( scalar(@items), 3, 'got 3 items in list' );

# or a list/list ref of results of calling a sub ref for each item
@items = $list->each( sub { shift() + 1 } );
is( scalar(@items), 3, 'got 3 items in each map in list context' );
is( join('/', @items), '11/21/31', 'each mapped plus one' );

$items = $list->each( sub { shift() + 2 } );
is( scalar(@$items), 3, 'got 3 items in each map in scalar context' );
is( join('/', @$items), '12/22/32', 'each mapped plus two' );

# or we can call a method on objects
$list = $nodes->node('list');
$list->push( $nodes->node( pod  => text => 'Hello World' ) );
$list->push( $nodes->node( code => text => 'Hello Badger' ) );
is( $list->size, 2, 'list has 2 nodes' );
@items = $list->each('text');
is( scalar(@items), 2, 'got 2 items in list' );
is( join('. ', @items), 'Hello World. Hello Badger', 'each text' );


#-----------------------------------------------------------------------
# create a custom object with an extra method that takes args for testing
#-----------------------------------------------------------------------

package Badger::Test::Node;

use Badger::Class
    version => 0.01,
    debug   => 0,
    base    => 'Badger::Pod::Node';

sub bracket {
    my ($self, $l, $r) = @_;
    return $l . $self->text . $r;
}

package main;

# register node with nodes factory
$nodes->nodes( test => 'Badger::Test::Node' );

my $test1 = $nodes->node( test => text => 'This is a test' );
ok( $test1, 'created test object node' );
is( ref $test1, 'Badger::Test::Node', 'got new test node' );

$list = $nodes->node('list');
$list->push( $test1 );
$list->push( $nodes->node( test => text => 'This is not a test' ) );
is( $list->size, 2, 'list has 2 object nodes' );

# call text() method on each item
@items = $list->each('text');
is( join('. ', @items), 
    'This is a test. This is not a test', 
    'test object text' );

# call bracket('<', '>') method on each item
@items = $list->each( bracket => '<', '>' );
is( join('. ', @items),
    '<This is a test>. <This is not a test>', 
    'test object bracket' 
);



