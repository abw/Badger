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
use Badger::Filesystem 'FS VFS :types :dirs cwd getcwd $Bin Bin';
use Badger::Test
    tests => 62,
    debug => 'Badger::Filesystem',
    args  => \@ARGV;

our $TDIR = -d 't' ? FS->join_dir(qw(t filesystem)) : FS->directory;

# ugly hack to grok file separator on local filesystem
my $PATHSEP  = File::Spec->catdir(('badger') x 2);
$PATHSEP =~ s/badger//g;

# convert unix-like paths into local equivalent
sub lp($) {
    my $path = shift;
    $path =~ s|/|$PATHSEP|g;
    $path;
}



#-----------------------------------------------------------------------
# test $Bin from FindBin, and Bin() as directory wrapper around it
#-----------------------------------------------------------------------

ok( $Bin, "\$Bin is set to $Bin" );
my $bin = Bin;
ok( $bin, "\$bin is set to $bin" );
is( ref $bin, 'Badger::Filesystem::Directory', '$bin is a directory object' );



#-----------------------------------------------------------------------
# test Path(), File() and Directory()
#-----------------------------------------------------------------------

my $rel = File::Spec->catdir('badger_test_p1', 'badger_test_p2');
my $abs = File::Spec->rel2abs($rel, File::Spec->rootdir);
my $path = Path('/badger_test_p1/badger_test_p2');
ok( $path, 'created path using constructor sub' );
is( $path, $abs, 'matched path' );
is( Path('badger_test_p1', 'badger_test_p2'), $rel, 'path with separates' );

my $file = File('/badger_test_p1/badger_test_p2');
is( $file, $abs, 'absolute file' );
is( File('badger_test_p1', 'badger_test_p2'), $rel, 'relative file with separates' );

my $dir = Dir('/badger_test_p1/badger_test_p2');
ok( $dir, 'created dir using constructor sub' );
is( $dir, $abs, 'absolute dir' );
is( Dir('badger_test_p1', 'badger_test_p2'),  $rel, 'relative dir with separates' );

$dir = Directory('/badger_test_p1/badger_test_p2');
ok( $dir, 'created directory using constructor sub' );
is( $dir, $abs, 'absolute directory' );
is( Directory('badger_test_p1', 'badger_test_p2'), $rel, 'relative directory with separates' );


#-----------------------------------------------------------------------
# should also work without arguments as class name providers
#-----------------------------------------------------------------------

$path = Path->new('/badger_test_p1/badger_test_p2');
ok( $path, 'created path using constructor class' );

$file = File->new('/badger_test_p1/badger_test_p2');
ok( $file, 'created file using constructor class' );

$dir = Dir->new('/badger_test_p1/badger_test_p2');
ok( $dir, 'created dir using constructor class' );

$dir = Directory->new('/badger_test_p1/badger_test_p2');
ok( $dir, 'created directory using constructor class' );


#-----------------------------------------------------------------------
# and also via the FS alias for Badger::Filesystem
#-----------------------------------------------------------------------

$path = FS->path('/badger_test_p1/badger_test_p2');
ok( $path, 'created path using FS class' );

$file = FS->file('/badger_test_p1/badger_test_p2');
ok( $file, 'created file using FS class' );

$dir = FS->dir('/badger_test_p1/badger_test_p2');
ok( $dir, 'created dir using FS class' );

$dir = FS->directory->new('/badger_test_p1/badger_test_p2');
ok( $dir, 'created directory using FS class' );


#-----------------------------------------------------------------------
# test temp_directory() and temp_file()
#-----------------------------------------------------------------------

my $tmp = FS->temp_directory;
ok( $tmp, "got temp_directory() $tmp" );

$tmp = FS->temp_directory('badger_test_p1', 'badger_test_p2');
ok( $tmp, "got temp_directory() $tmp" );
$tmp = $tmp->file('badger_test1.tmp');
ok( $tmp->write("Hello World\n"), "wrote text to $tmp" );
ok( $tmp->delete, 'deleted temporary file' );

$tmp = FS->temp_file('badger_test2.tmp');
ok( $tmp, "got temp_file() $tmp" );
ok( $tmp->write("Hello World\n"), 'wrote text to tmp file' );
ok( $tmp->delete, 'deleted temporary file' );


#-----------------------------------------------------------------------
# we should also have a VFS reference defined and the module loaded
#-----------------------------------------------------------------------

is( VFS, 'Badger::Filesystem::Virtual', 'VFS is defined' );
ok( VFS->VERSION, 'VFS version is ' . VFS->VERSION );


#-----------------------------------------------------------------------
# check we can get root directory
#-----------------------------------------------------------------------

my $root = FS->root;
my $sub = $root->dir('badger_test_p1', 'badger_test_p2');
is( $root, File::Spec->rootdir, 'root dir' );
is( $sub, File::Spec->catfile('', 'badger_test_p1', 'badger_test_p2'), 'root dir relative' );


#-----------------------------------------------------------------------
# basic constructor test
#-----------------------------------------------------------------------

my $fs = FS->new;
ok( $fs, 'created a new filesystem' );

is( $fs->rootdir, ROOTDIR, 'root is ' . ROOTDIR );
is( $fs->updir, UPDIR, 'updir is ' . UPDIR );
is( $fs->curdir, CURDIR, 'curdir is ' . CURDIR );
is( $fs->separator, $PATHSEP, 'separator is ' . $PATHSEP );
ok( ! $fs->virtual, 'filesystem is not virtual' );


#-----------------------------------------------------------------------
# absolute and relative paths
#-----------------------------------------------------------------------

my $cwd = $fs->cwd;

$abs = $fs->absolute( File::Spec->catdir('wam', 'bam'));
is( $abs, File::Spec->catdir($cwd, 'wam', 'bam'), "absolute: $abs" );
ok( $fs->is_absolute($abs), 'path is absolute' );

$abs = $fs->absolute(['wam', 'bam']);
is( $abs, File::Spec->catdir($cwd, 'wam', 'bam'), "absolute: $abs" );
ok( $fs->is_absolute($abs), 'path is absolute' );

$rel = $fs->relative($abs);
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
# current working directory
#-----------------------------------------------------------------------

ok( cwd, 'got CWD: ' . cwd );
ok( getcwd, 'got getcwd: ' . getcwd );
$cwd = Cwd;
ok( $cwd, 'got Cwd' );
is( ref $cwd, 'Badger::Filesystem::Directory', 'got Cwd directory object' );
is( $cwd, Cwd, 'getcwd matches one way' );
is( $cwd, cwd, 'cwd matches the other way' );
is( $cwd, $fs->cwd, 'fs->cwd matches in the other other way' );


#-----------------------------------------------------------------------
# merge paths
#-----------------------------------------------------------------------

is( $fs->merge_paths('/path/one', '/path/two'), lp '/path/one/path/two', 'merged abs paths' );
is( $fs->merge_paths('/path/one', 'path/two'), lp '/path/one/path/two', 'merged abs/rel paths' );
is( $fs->merge_paths('path/one', 'path/two'), lp 'path/one/path/two', 'merged rel/rel paths' );

#-----------------------------------------------------------------------
# definitive* should not be applied multiple times when creating file
#-----------------------------------------------------------------------

package DFS;

use Badger::Class base => 'Badger::Filesystem';

sub definitive_write {
  my $self = shift;
  my $candidate = $self->SUPER::definitive_write(@_);
  return "$candidate-X";
}

{
  no warnings;             # avoid warnings about names used only once
  *definitive = \&definitive_write;
  *definitive_read = \&definitive_write;
}

package main;

my $dfs = DFS->new;
my $filename = 'foo-create.txt';
$path = "testfiles/$filename";
$abs = $dfs->absolute($path);
my $def = $dfs->definitive_write($path);
is($def, "$abs-X", 'definitive_write');
$file1 = $dfs->file($path);
ok($file1, "fetched $path");
is($file1->name, $filename, "file object has non-definitive name");
ok($file1->create, "call create on $path");
unless (ok(-e $def, "definitive file $path-X exists")) {
  my @files = grep { /$filename/ } FS->directory('testfiles')->files;
  fail("Instead found @files") if @files;
}

$filename = 'foo-touch.txt';
$path = "testfiles/$filename";
$abs = $dfs->absolute($path);
$def = $dfs->definitive_write($path);
is($def, "$abs-X", 'definitive_write');
$file1 = $dfs->file($path);
ok($file1, "fetched $path");
is($file1->name, $filename, "file object has non-definitive name");
ok($file1->touch, "call touch on $path");
unless (ok(-e $def, "definitive file $path-X exists")) {
  my @files = grep { /$filename/ } FS->directory('testfiles')->files;
  fail("Instead found @files") if @files;
}

$filename = 'foo-open.txt';
$path = "testfiles/$filename";
$abs = $dfs->absolute($path);
$def = $dfs->definitive_write($path);
is($def, "$abs-X", 'definitive_write');
$file1 = $dfs->file($path);
ok($file1, "fetched $path");
is($file1->name, $filename, "file object has non-definitive name");
my $fh = $file1->open('w');
ok($fh, "call open (for write) on $path");
$fh->close;
unless (ok(-e $def, "definitive file $path-X exists")) {
  my @files = grep { /$filename/ } FS->directory('testfiles')->files;
  fail("Instead found @files") if @files;
}
