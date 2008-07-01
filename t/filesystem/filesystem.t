#============================================================= -*-perl-*-
#
# t/filesystem/filesystem.t
#
# Test the Badger::Filesystem module.
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
use Badger::Filesystem qw( :types :dirs );
use Badger::Test 
    tests => 14,
    debug => 'Badger::Filesystem',
    args  => \@ARGV;

our $FS = 'Badger::Filesystem';

my $fs = $FS->new;
ok( $fs, 'created a new filesystem' );

is( $fs->rootdir, ROOTDIR, 'root is ' . ROOTDIR );
is( $fs->updir, UPDIR, 'updir is ' . UPDIR );
is( $fs->curdir, CURDIR, 'curdir is ' . CURDIR );
ok( ! $fs->virtual, 'filesystem is not virtual' );


#-----------------------------------------------------------------------
# get some files
#-----------------------------------------------------------------------

my $file1 = $fs->file('file.t');
ok( $file1, 'fetched first file' );

my $file2 = $fs->file('filesystem.t');
ok( $file2, 'fetched second file' );

# both should have references to the same $fs filesystem
is( $file1->filesystem, $file2->filesystem, 
    'filesystems are both ' . $file1->filesystem );

is( $file1->filesystem, $fs, 
    'matches our filesystem: ' . $fs );

#-----------------------------------------------------------------------
# test a virtual root directory
#-----------------------------------------------------------------------

$fs = $FS->new(
    root      => '/path/to/my/web/pages', 
    rootdir   => '/',
    separator => '/',
);
ok( $fs, 'created filesystem with virtual root' );

$file1 = $fs->file('foo', 'bar');
is( $file1->absolute, '/foo/bar', 'absolute foo bar in virtual root fs' );

$file1 = $fs->file('/foo/bar');
is( $file1->absolute, '/foo/bar', 'absolute /foo/bar in virtual root fs' );

is( $file1->definitive, '/path/to/my/web/pages/foo/bar', 'definitive path adds root' );

ok( $fs->virtual, 'filesystem is virtual' );
