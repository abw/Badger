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
use Badger::Filesystem qw( :types :dirs );
use Badger::Test 
    tests => 28,
    debug => 'Badger::Filesystem',
    args  => \@ARGV;

our $FS = 'Badger::Filesystem';


#-----------------------------------------------------------------------
# test Path(), File() and Directory()
#-----------------------------------------------------------------------

my $path = Path('/foo/bar');
ok( $path, 'created path using constructor sub' );

my $file = File('/foo/bar');
ok( $file, 'created file using constructor sub' );

my $dir = Dir('/foo/bar');
ok( $dir, 'created dir using constructor sub' );

$dir = Directory('/foo/bar');
ok( $dir, 'created directory using constructor sub' );


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
# basic constructor test
#-----------------------------------------------------------------------

my $fs = $FS->new;
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

