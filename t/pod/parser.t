#============================================================= -*-perl-*-
#
# t/pod/parser.t
#
# Test the Badger::Pod::Parser module.
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
use Badger::Pod 'Parser';
use Badger::Filesystem 'FS';
use Badger::Debug ':dump';
use Badger::Test
    tests => 2,
    debug => 'Badger::Pod Badger::Pod::Parser',
    args  => \@ARGV;
    
my $test_dir  = 'testfiles';
my $test_file = 'parser.pod';
my $dir       = -d 't' ? FS->dir('t', 'pod', $test_dir) : FS->dir($test_dir);
my $file      = $dir->file($test_file);
my $parser    = Parser->new( merge_verbatim => -1 );
ok( $parser, 'created parser' );
ok( $parser->parse($file->text), "parsed document without error");