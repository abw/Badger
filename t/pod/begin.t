#============================================================= -*-perl-*-
#
# t/pod/begin.t
#
# Test Badger::Pod::* at parsing =begin ... =end blocks.
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
my $test_file = 'begin.pod';
my $dir       = -d 't' ? FS->dir('t', 'pod', $test_dir) : FS->dir($test_dir);
my $file      = $dir->file($test_file);
my @blocks    = Pod( file => $file )->code;
is( scalar @blocks, 1, 'one code blocks' );
like( $blocks[0], qr/This is a code block .*? This is not pod/, 'got begin code block' );
