#============================================================= -*-perl-*-
#
# t/filesystem/visitor
#
# Test the Badger::Filesystem::Visitor module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ./lib ../lib ../../lib );
use strict;
use warnings;
use File::Spec;
use Badger::Filesystem 'FS';
use Badger::Test 
    tests => 5,
    debug => 'Badger::Filesystem::Visitor',
    args  => \@ARGV;

our $here = -d 't' ? FS->dir(qw(t filesystem)) : FS->dir;
our $tdir = $here->dir('testfiles');
$tdir->must_exist;

my $visitor = $tdir->visit( 
    recurse => 1, 
    dirs    => 0, 
    files   => 'foo'
);
ok( $visitor, 'got visitor' );
is( ref $visitor, 'Badger::Filesystem::Visitor', 'isa visitor object' );
my @foos = $visitor->collect;
is( scalar @foos, 3, 'got 3 foo files' );

@foos = $tdir->visit( 
    recurse => 1, 
    dirs    => 0, 
    files   => ['foo', 'bar'],
)->collect;
is( scalar @foos, 5, 'got 5 foo and bar files' );

@foos = $tdir->visit( 
    dirs        => 0, 
    files       => qr/foo|bar/,
    in_dirs     => 1,
    not_in_dirs => '.svn',
)->collect;
is( scalar @foos, 5, 'got 5 foo or bar files via regex' );

