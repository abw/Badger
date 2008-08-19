#============================================================= -*-perl-*-
#
# t/pod/nodes.t
#
# Test the Badger::Pod::Nodes factory module.
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
use Badger::Test
    tests => 11,
    debug => 'Badger::Pod::Nodes Badger::Factory Badger::Class',
    args  => \@ARGV;
    
my $nodes = Nodes;
ok( $nodes, 'got nodes class' );

# named parameters
my $code  = $nodes->node( code => text => 'example' );
ok( $code, 'got code node' );
is( ref $code, 'Badger::Pod::Node::Code', 'checked code node class' );
is( $code->nodes, $nodes->prototype, 'node has nodes ref' );
ok( $code->code, 'code is code' );
ok( ! $code->pod, 'code is not pod' );
ok( ! $code->paragraph, 'code is not paragraph' );

# list parameters
my $list = $nodes->node( list => 'a', 'b', 'c' );
ok( $list, 'created list node' );
is( $list->shift, 'a', 'shifted first item off list node' );
is( $list->first, 'b', 'got first item in list node' );
is( $list->last, 'c', 'got last item in list node' );

