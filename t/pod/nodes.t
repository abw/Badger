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
    tests => 3,
    debug => 'Badger::Pod::Nodes Badger::Factory Badger::Class',
    args  => \@ARGV;
    
my $nodes = Nodes;
ok( $nodes, 'got nodes class' );

my $code  = $nodes->node( code => text => 'example' );
ok( $code, 'got code node' );
is( ref $code, 'Badger::Pod::Node::Code', 'checked code node class' );
