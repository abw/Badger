#============================================================= -*-perl-*-
#
# t/pod/code.t
#
# Test Badger::Pod::* at parsing code blocks.
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
use Badger::Pod 'Pod';
use Badger::Filesystem 'FS';
use Badger::Debug ':dump';
use Badger::Test
    tests => 3,
    debug => 'Badger::Pod Badger::Pod::Document',
    args  => \@ARGV;
    
my $test_dir  = 'testfiles';
my $test_file = 'code.pod';
my $dir       = -d 't' ? FS->dir('t', 'pod', $test_dir) : FS->dir($test_dir);
my $file      = $dir->file($test_file);
my @blocks    = Pod( file => $file )->blocks->code;
is( scalar @blocks, 2, 'two code blocks' );
is( $blocks[0], "This is the first code block\n\n", 'got first code block' );
is( $blocks[1], "\nThis is the second code block\n", 'got second code block' );
