#============================================================= -*-perl-*-
#
# t/filesystem/directory.t
#
# Test the Badger::Filesystem::Directory module.
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
use Badger::Filesystem::Directory;
use Badger::Filesystem::Virtual;
use Badger::Test 
    tests => 59,
    debug => 'Badger::Filesystem::Directory',
    args  => \@ARGV;

our $DIR   = 'Badger::Filesystem::Directory';
our $FS    = 'Badger::Filesystem';
our $TDIR  = -d 't' ? $FS->join_dir(qw(t filesystem)) : $FS->directory;

# ugly hack to grok file separator on local filesystem
my $PATHSEP  = File::Spec->catdir(('badger') x 2);
$PATHSEP =~ s/badger//g;

# convert unix-like paths into local equivalent
sub lp($) {
    my $path = shift;
    $path =~ s|/|$PATHSEP|g;
    $path;
}

my $dir = $DIR->new('example');

ok( $dir, 'created a new directory' );
is( $dir->name, 'example', 'got example name' );
ok( ! $dir->volume, 'got (no) file volume' );
ok( ! $dir->dir, 'got (no) file directory' );
#print "dir: ", $dir->dir, "\n";

is( $DIR->new(name => 'example')->name,
    'example', 'got dir using name param' );

is ( $DIR->new(path => 'example')->name,
    'example', 'got dir using path param' );

is( $DIR->new({ name => 'example' })->name,
    'example', 'got dir using name param hash' );

is ( $DIR->new({ path => 'example' })->name,
    'example', 'got dir using path param hash' );


$dir = $DIR->new('/foo/bar/baz');
is( $dir, lp '/foo/bar/baz', 'foo/bar/baz path');
is( $dir->dir, lp '/foo/bar/', 'foo/bar dir');
is( $dir->name, 'baz', 'baz file' );
is( $dir->canonical, lp '/foo/bar/baz/', 'baz slashed' );

$dir = $DIR->new('/foo/bar/baz/');
is( $dir, lp '/foo/bar/baz', 'foo/bar/baz path with trailing slash');
is( $dir->dir, lp '/foo/bar/', 'foo/bar dir with trailing slash');
is( $dir->name, 'baz', 'baz file with trailing slash' );

#-----------------------------------------------------------------------
# test the up() method (alias for parent())
#-----------------------------------------------------------------------

$dir = $DIR->new('/path/to/file/number/one');
is( $dir, lp '/path/to/file/number/one', 'full path' );
is( $dir->up, lp '/path/to/file/number', 'path up one' );
is( $dir->up->up, lp '/path/to/file', 'path up two' );
is( $dir->up(1), lp '/path/to/file', 'path up, skip one' );
is( $dir->up(2), lp '/path/to', 'path up, skip two' );
is( $dir->up(3), lp '/path', 'path up, skip three' );
is( $dir->up(4), lp '/', 'path up, skip four' );
is( $dir->up(42), lp '/', 'path up, skip fourty two' );

is( $dir->directory('two'), lp '/path/to/file/number/one/two', 
    'relative path down' );
is( $dir->directory('../three'), lp '/path/to/file/number/three', 
    'relative path up' );
is( $dir->directory('../../four'), lp '/path/to/file/four', 
    'relative path up up' );
is( $dir->directory('/five'), lp '/five', 
    'absolute path on relative path' );

is( $dir->file('two.txt'), lp '/path/to/file/number/one/two.txt', 
    'relative file down' );
is( $dir->directory('../three.pm'), lp '/path/to/file/number/three.pm', 
    'relative file up' );
is( $dir->directory('../../four.pl'), lp '/path/to/file/four.pl', 
    'relative file up up' );
is( $dir->directory('/five'), lp '/five', 
    'absolute file on relative path' );


#-----------------------------------------------------------------------
# test open
#-----------------------------------------------------------------------

my $cwd = Badger::Filesystem->directory($TDIR);
my @files = $cwd->read;
my $n = @files;
ok( $n > 3, 'got some test files in this directory' );

@files = $cwd->read(1);     # all files
my $m = @files;
ok( $m > 3, 'got some test files in this directory with extras' );
ok( $m - $n > 1, 'got more files with extras enabled' );

my @kids = $cwd->children;
ok( scalar(@kids), 'got some kids' );

foreach my $kid (@kids) {
    printf(" * %-12s  %-20s   %s\n", $kid->type, $kid->name, $kid->path) if $DEBUG;
}

#print "got ", scalar(@files), " files:\n  ", join("\n  ", @files), "\n";


#-----------------------------------------------------------------------
# now try with a virtual filesystem
#-----------------------------------------------------------------------

my $vfs = Badger::Filesystem::Virtual->new( root => $cwd );
my $root = $vfs->dir('/');
@kids = $root->children;
ok( scalar(@kids), 'got some kids' );

foreach my $kid (@kids) {
    printf(" * %-4s %s\n", $kid->type, $kid->path) if $DEBUG;
}

my $testdir = $vfs->dir('testfiles');
ok( $testdir->exists, 'testfiles exists' );
@kids = $testdir->children;
ok( scalar(@kids), 'found some files in testfiles' );
my $first = shift(@kids);
ok( $first->exists, 'first testfile exists' );

my $callsigns = $testdir->file('callsigns');

my @lines = $callsigns->read;
print "read lines: \n  - ", join("  - ", @lines), "\n" if $DEBUG;
is( scalar(@lines), 26, 'read 26 lines from test file' );
is( $lines[0], "Alpha\n", 'read first line' );

my $text = $callsigns->read;
is( length($text), 164, 'read 164 characters from file' );
like( $text, qr/^Alpha.*?Zulu\s*/s, 'Alpha-Zula' );

#-----------------------------------------------------------------------
# try to write a file
#-----------------------------------------------------------------------

my $newfile = $testdir->file('dirtest1');
ok( $newfile->write("this file was generated by the directory.t test script\n"),
    'created new file in test dir' );

$newfile = $testdir->file('dirtest2');
my $handle = $newfile->write;
ok( $handle, 'got write handle' );
ok( $handle->print("this file was also generated by directory.t\n"), 'printed line via write handle' );
$handle->close;
is( $newfile->text, "this file was also generated by directory.t\n", 'written text matches' );

ok( $newfile->append("this line was appended afterward\n"), 'appended another line' );

$text = $newfile->text;
like( $text, qr/^this file was also.*this line was appended/s, 'checked appended text' );


#-----------------------------------------------------------------------
# create/delete directory
#-----------------------------------------------------------------------

my $newdir = $testdir->dir('newdir1');

# clean up from previous test that might have aborted
if ($newdir->exists) {
    ok( $newdir->delete, "cleanup deleting $newdir" );
    ok( ! $newdir->exists, "cleanup deleted $newdir" );
}
else {
    pass( "If you go down to the woods today..." );
    pass( "...be sure to forage for nuts and berries" );
}

ok( $newdir->create, "creating $newdir" );
ok( $newdir->exists, "created $newdir" );
ok( $newdir->must_exist, "$newdir must exist" );
ok( $newdir->delete, "deleting $newdir" );
ok( ! $newdir->exists, "deleted $newdir" );
ok( $newdir->must_exist(1), "$newdir must exist, create if not" );
ok( $newdir->exists, "$newdir does exist" );
ok( $newdir->delete, "final cleanup of $newdir" );

