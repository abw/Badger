#============================================================= -*-perl-*-
#
# t/pod/paras.t
#
# Badger::Pod::* paragraph tests.
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
    skip  => 'not working',
    tests => 14,
    debug => 'Badger::Pod Badger::Pod::Document',
    args  => \@ARGV;
    
my $test_dir  = 'testfiles';
my $test_file = 'paras.pod';
my $dir       = -d 't' ? FS->dir('t', 'pod', $test_dir) : FS->dir($test_dir);
my $file      = $dir->file($test_file);
my $pod       = Pod( file => $file );
my @lines     = (1, 3, 5, 8);

my @blocks    = $pod->blocks;
is( scalar @blocks, 1, 'just one block' );

my $block     = $blocks[0];
is( $block->type, 'pod', 'got a pod block' );

my @paras     = $block->body;
is( scalar(@paras), 4, 'got 4 paras' );


#-----------------------------------------------------------------------
# check each of the pod paragraphs is what we expect
#-----------------------------------------------------------------------

foreach my $n (0..$#paras) {
    is( $paras[$n]->line, $lines[$n], "para $n is at line $lines[$n]" );
    print STDERR "item $n is ", ref($paras[$n]), " text: ", $paras[$n]->text, "\n" if $DEBUG;
}
is( $paras[0]->text, '=pod', 'matched pod command' );
is( $paras[1]->text, 'This is a pod paragraph.', 'matched para 1' );
is( $paras[2]->text, "This is another pod paragraph\nthat extends onto two lines.", 'matched para 2' );
like( $paras[3]->text, qr/^This paragraph contains some C<constant> text .*? more .*? even more .*? wraps across .*? all for now/s, 'matched para 3' );

my $body = $paras[3]->body;
#print "body text: $paras[3]\n";
#print "body para: ", join('', @$body), "\n";

print "penul one: [", $paras[-2], "]\n";
print "last one: [", $paras[-1], "]\n";

#-----------------------------------------------------------------------
# try pod_blocks() and code_blocks() methods
#-----------------------------------------------------------------------

@blocks = $pod->pod;
is( scalar(@blocks), 1, 'one pod blocks' );

@blocks = $pod->code;
is( scalar(@blocks), 0, 'no code blocks' );

@paras = $pod->paragraph;
is( scalar(@paras), 3, 'got three paras' );

