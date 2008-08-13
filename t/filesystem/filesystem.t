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
use File::Spec;
use Badger::Filesystem qw( FS VFS :types :dirs );
use Badger::Test 
    tests => 36,
    debug => 'Badger::Filesystem',
    args  => \@ARGV;

our $TDIR = -d 't' ? FS->join_dir(qw(t filesystem)) : FS->directory;


#-----------------------------------------------------------------------
# test Path(), File() and Directory()
#-----------------------------------------------------------------------

my $path = Path('/foo/bar');
ok( $path, 'created path using constructor sub' );
is( $path, '/foo/bar', 'matched path' );
is( Path('foo', 'bar'), File::Spec->catdir('foo', 'bar'), 'path with separates' );

my $file = File('/foo/bar');
ok( $file, 'created file using constructor sub' );
is( File('foo', 'bar'), File::Spec->catdir('foo', 'bar'), 'file with separates' );

my $dir = Dir('/foo/bar');
ok( $dir, 'created dir using constructor sub' );
is( Dir('foo', 'bar'), File::Spec->catdir('foo', 'bar'), 'dir with separates' );

$dir = Directory('/foo/bar');
ok( $dir, 'created directory using constructor sub' );
is( Directory('foo', 'bar'), File::Spec->catdir('foo', 'bar'), 'directory with separates' );


#-----------------------------------------------------------------------
# should also work without arguments as class name providers
#-----------------------------------------------------------------------

$path = Path->new('/foo/bar');
ok( $path, 'created path using constructor class' );

$file = File->new('/foo/bar');
ok( $file, 'created file using constructor class' );

$dir = Dir->new('/foo/bar');
ok( $dir, 'created dir using constructor class' );

$dir = Directory->new('/foo/bar');
ok( $dir, 'created directory using constructor class' );


#-----------------------------------------------------------------------
# and also via the FS alias for Badger::Filesystem
#-----------------------------------------------------------------------

$path = FS->path('/foo/bar');
ok( $path, 'created path using FS class' );

$file = FS->file('/foo/bar');
ok( $file, 'created file using FS class' );

$dir = FS->dir('/foo/bar');
ok( $dir, 'created dir using FS class' );

$dir = FS->directory->new('/foo/bar');
ok( $dir, 'created directory using FS class' );


#-----------------------------------------------------------------------
# we should also have a VFS reference defined and the module loaded
#-----------------------------------------------------------------------

is( VFS, 'Badger::Filesystem::Virtual', 'VFS is defined' );
ok( VFS->VERSION, 'VFS version is ' . VFS->VERSION );


#-----------------------------------------------------------------------
# check we can get root directory
#-----------------------------------------------------------------------

my $root = FS->root;
my $sub = $root->dir('foo', 'bar');
is( $root, File::Spec->rootdir, 'root dir' );
is( $sub, File::Spec->catfile('', 'foo', 'bar'), 'root dir relative' );


#-----------------------------------------------------------------------
# basic constructor test
#-----------------------------------------------------------------------

my $fs = FS->new;
ok( $fs, 'created a new filesystem' );

is( $fs->rootdir, ROOTDIR, 'root is ' . ROOTDIR );
is( $fs->updir, UPDIR, 'updir is ' . UPDIR );
is( $fs->curdir, CURDIR, 'curdir is ' . CURDIR );
ok( ! $fs->virtual, 'filesystem is not virtual' );


#-----------------------------------------------------------------------
# absolute and relative paths
#-----------------------------------------------------------------------

my $cwd = $fs->cwd;

my $abs = $fs->absolute( File::Spec->catdir('wam', 'bam'));
is( $abs, File::Spec->catdir($cwd, 'wam', 'bam'), "absolute: $abs" );
ok( $fs->is_absolute($abs), 'path is absolute' );

$abs = $fs->absolute(['wam', 'bam']);
is( $abs, File::Spec->catdir($cwd, 'wam', 'bam'), "absolute: $abs" );
ok( $fs->is_absolute($abs), 'path is absolute' );

my $rel = $fs->relative($abs);
is( $rel, File::Spec->catfile('wam', 'bam'), "relative: $rel" );
ok( $fs->is_relative($rel), 'path is relative' );


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

