#============================================================= -*-perl-*-
#
# t/pod/blocks.t
#
# Test the Badger::Pod::Blocks module which splits a Pod document into 
# code blocks and Pod sections.
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
    tests => 52,
    debug => 'Badger::Pod::Blocks',
    args  => \@ARGV;
    
my $tfd    = 'testfiles';
my $dir    = -d 't' ? FS->dir('t', 'pod', $tfd) : FS->dir($tfd);
my $file   = "blocks_\n.pod";     # let Perl insert platform-specific ending
   $file   =~ s/\012/lf/g;        # then translate it to letters: cr lf crlf
   $file   =~ s/\015/cr/g;
my $pod    = $dir->file($file);
my @blocks = Badger::Pod::Blocks->parse($pod->text)->blocks;
my @lines  = (1, 3, 8, 11, 16, 19, 24, 27, 32);
my @expect = (
    "This is not Pod\n\n", 
    "=pod\n\nThis is Pod\n\n=cut\n", 
    "\nBack to non-Pod\n\n", 
     "=pod   \n\nBack to Pod (BTW, there are three spaces after '=pod' above and '=cut' below)\n\n=cut   \n",
    "\nBack to non-Pod once more\n\n", 
    "=pod with some extra text which is ignored\n\nIn Pod again\n\n=cut with some other text which is also ignored\n",
    "\nOut of Pod\n\n", 
    "=pod\n\n=cutting should not be recognised as =cut\n\n=cut\n",
    "\nOut of Pod.  The End.\n", 
);

pass("parsing blocks in $file");

foreach my $n (0..$#expect) {
    my $ntype = $n % 2 ? 'pod' : 'code';
    is( $blocks[$n]->type, $ntype, "$file chunk $n is $ntype" );
    is( $blocks[$n]->line, $lines[$n], "$file chunk $n is at line " .$lines[$n] );
    is( $blocks[$n], $expect[$n], "$file block $n matches" );
}


#-----------------------------------------------------------------------
# test that a command block can appear first.
#-----------------------------------------------------------------------

$pod = Pod( text => "=head1 hello world\n\n" );
ok( $pod, 'got pod in first line' );
@blocks = $pod->blocks->all;
is( scalar(@blocks), 1, 'got one block' );
is( $blocks[0]->type, 'pod', 'got pod block' );
is( $blocks[0]->text, "=head1 hello world\n\n", 'got hello world block' );

$pod = Pod( text => "=head1 hello world\n\n=head1 hello badger" );
ok( $pod, 'got pod with a badger on the end' );
@blocks = $pod->blocks->all;
is( scalar(@blocks), 1, 'got one badgery block' );
is( $blocks[0]->type, 'pod', 'got badgery pod block' );
is( $blocks[0]->text, "=head1 hello world\n\n=head1 hello badger", 'got hello badger block' );


#-----------------------------------------------------------------------
# test that a command block can terminate at EOF without any newlines
#-----------------------------------------------------------------------

$pod = Pod( text => "=head1 hello world" );
ok( $pod, 'got pod in single line' );
@blocks = $pod->blocks->all;
is( scalar(@blocks), 1, 'got one block in single line' );
is( $blocks[0]->type, 'pod', 'got pod block in single line' );
is( $blocks[0]->text, "=head1 hello world", 'got hello world single line block' );


#-----------------------------------------------------------------------
# test that pod blocks must have a blank line before and after
#-----------------------------------------------------------------------

$pod = Pod( text => "some code\n=head1 hello world\nmore code" );
ok( $pod, 'got pod code without blank lines' );
@blocks = $pod->blocks->all;
is( scalar(@blocks), 1, 'got one block in code without blank lines' );
is( $blocks[0]->type, 'code', 'got code block without blank lines' );
is( $blocks[0]->text, "some code\n=head1 hello world\nmore code", 'got code block without blank lines' );


#-----------------------------------------------------------------------
# test that pod blocks must have a blank line before
#-----------------------------------------------------------------------

$pod = Pod( text => "some code\n=head1 hello world\n\nmore code" );
ok( $pod, 'got pod code for blank line before' );
@blocks = $pod->blocks->all;
is( scalar(@blocks), 1, 'got one blocks for blank line before' );
is( $blocks[0]->type, 'code', 'got code block without blank lines' );
is( $blocks[0]->text, "some code\n=head1 hello world\n\nmore code", 'got code block without blank lines' );


#-----------------------------------------------------------------------
# test we can start a pod cmd in the first character 
#-----------------------------------------------------------------------

$pod = Pod( text => "=begin test\n\nThis is in the begin block\n\n=end test" );
ok( $pod, 'I get bored thinking up test names' );
@blocks = $pod->blocks->all;
is( scalar(@blocks), 1, 'got one pod block, as if anyone cares' );
is( $blocks[0]->type, 'pod', 'yeah, it was a pod block' );
like( $blocks[0]->text, qr/^=begin test.*?=end test$/s, 'begin to end test' );


