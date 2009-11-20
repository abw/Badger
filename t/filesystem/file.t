#============================================================= -*-perl-*-
#
# t/filesystem/file.t
#
# Test the Badger::Filesystem::File module.
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
use Badger::Timestamp 'TIMESTAMP';
use Badger::Filesystem 'FS File';
use Badger::Filesystem::File '@STAT_FIELDS';
use Badger::Filesystem::Directory;
use Badger::Test 
    tests => 60,
    debug => 'Badger::Filesystem::File Badger::Filesystem::Path Badger::Filesystem',
    args  => \@ARGV;

our $FILE  = 'Badger::Filesystem::File';
our $FS    = 'Badger::Filesystem';
our $cwd   = $FS->cwd;
our @tdir  = -d 't' ? qw( t filesystem ) : ($FS->curdir);
our $TDIR  = -d 't' ? FS->dir(qw(t filesystem)) : FS->directory;


#-----------------------------------------------------------------------
# basic file inspection
#-----------------------------------------------------------------------

my $file = $FILE->new('file.t');
ok( $file, 'created a new file' );
is( $file->name, 'file.t', 'got file name' );
ok( ! $file->volume, 'got (no) file volume' );
ok( ! $file->dir, 'got (no) file directory' );
ok( ! $file->is_absolute, 'file is not absolute' );

$file = $FILE->new([@tdir, 'file.t']);
ok( $file->exists, 'file exists' );

my @stat = (stat($file->path), -r _, -w _, -x _, -o _);
foreach my $m (@STAT_FIELDS) {
    is( $file->$m, $stat[0], "file $m is " . shift(@stat) );
}

my $expect = $FS->dir($cwd, @tdir, 'file.t');
is( $file->absolute, $expect, "absolute path is $expect" );

ok( $FILE->new(path => '/example/file.foo')->is_absolute, 'file is absolute' );
ok( $FILE->new(name => 'file.foo', directory => '/example')->is_absolute, 'directory file is absolute' );
ok( $FILE->new(name => 'file.foo', dir => '/example')->is_absolute, 'dir file is absolute' );

is( $FILE->new(name => 'file.t')->name,     'file.t', 'got file using name param' );
is( $FILE->new(path => 'file.t')->name,     'file.t', 'got file using path param' );
is( $FILE->new({ name => 'file.t' })->name, 'file.t', 'got file using name param hash' );
is( $FILE->new({ path => 'file.t' })->name, 'file.t', 'got file using path param hash' );


#-----------------------------------------------------------------------
# basename() - most of this is covered in t/filesystem/path.t
# The only additional thing we need to check is that we get only the 
# name of the file, not the whole path
#-----------------------------------------------------------------------

is( File('foo/bar.baz.html')->basename, 'bar.baz', 'multi-dotted basename' );


#-----------------------------------------------------------------------
# timestamps
#-----------------------------------------------------------------------

my $ts = $file->created;
is( ref($ts), TIMESTAMP, 'created_on() returned a Badger::Timestamp' );

$ts = $file->accessed;
is( ref($ts), TIMESTAMP, 'accessed_on() returned a Badger::Timestamp' );

$ts = $file->modified;
is( ref($ts), TIMESTAMP, 'modified_on() returned a Badger::Timestamp' );


#-----------------------------------------------------------------------
# create a file, delete it, touch it
#-----------------------------------------------------------------------

my $file3 = $TDIR->file('testfiles', 'newfile');
ok( $file3, 'got newfile' );
if ($file3->exists) {
    ok( $file3->delete, 'deleted file' );
}
else {
    pass('no existing file');
}
ok( ! $file3->exists, 'newfile does not exist' );
ok( $file3->create, 'created file' );
ok( $file3->exists, 'newfile now exists' );
ok( $file3->print("Hello World!\n"), 'printed to newfile' );
is( $file3->text, "Hello World!\n", 'read text from newfile' );
ok( $file3->touch, 'touched newfile' );


#-----------------------------------------------------------------------
# copy and move files
#-----------------------------------------------------------------------

my $file4 = $TDIR->file('testfiles', 'copyfile');
ok( $file4, 'got copyfile' );
if ($file4->exists) {
    ok( $file4->delete, 'deleted copy file' );
}
else {
    pass('no existing copy file');
}
ok( ! $file4->exists, 'copyfile does not exist' );
ok( $file3->copy($file4), 'copied file' );
ok( $file4->exists, 'copyfile now exists' );


my $file5 = $TDIR->file('testfiles', 'movefile');
ok( $file5, 'got movefile' );
if ($file5->exists) {
    ok( $file5->delete, 'deleted move file' );
}
else {
    pass('no existing move file');
}
ok( ! $file5->exists, 'movefile does not exist' );
ok( $file4->move($file5), 'moved file' );
ok( $file5->exists, 'moved now exists' );
ok( ! $file4->exists, 'copyfile no longer exists' );


#-----------------------------------------------------------------------
# copy with mkdir and mode parameters
#-----------------------------------------------------------------------

my $file6 = $TDIR->file('testfiles', 'forest', 'badger');

ok( 
    $file5->copy($file6, mkdir => 1, dir_mode => 0770, file_mode => 0660),
    'copied file with mkdir'
);
ok( $file6->exists, 'file6 exists' );


#-----------------------------------------------------------------------
# copy from a filehandle
#-----------------------------------------------------------------------

my $file7 = $TDIR->file('testfiles', 'forest', 'ferret');

ok( 
    $file7->copy_from($file5->open),
    'copied file from filehandle'
);
ok( $file7->exists, 'copied file created' );

my $dir = $file6->parent;
$file5->delete;
$file6->delete;
$file7->delete;
$dir->delete;


#-----------------------------------------------------------------------
# create a file with specific permissions
#-----------------------------------------------------------------------

umask(0002);

my $file8 = $TDIR->file('testfiles', 'group_write');
my $fh8   = $file8->open("w", 0664);
$fh8->print("this is a test file");
$fh8->close;
ok( $file8->writeable, 'file is writable' );
ok( $file8->permissions & 0020, 'file is group writable' );
$file8->delete;

__END__
test_file('file.t');
test_file('example/file.t');
test_file('../x/y/../z/../../floop/./././../file.t');
test_file('/tmp/foo/file.t');

test_dir('example');
test_dir('example/foo');
test_dir('../example/foo');
test_dir('/tmp/example/foo');
test_dir('../../../tmp/../example/x/../y/../foo');

sub test_file {
    test_path($FILE->new(@_));
}

sub test_dir {
    test_path($DIR->new(@_));
}

sub test_path {
    my $path = shift;
    my $cwd = $DIR->cwd;
    print "\n";
    print "path: $path\n";
    print "is absolute? ", $path->is_absolute ? 'yes' : 'no', "\n";
    print "is file? ", $path->is_file ? 'yes' : 'no', "\n";
    print "is dir? ", $path->is_dir ? 'yes' : 'no', "\n";
    print "is directory? ", $path->is_directory ? 'yes' : 'no', "\n";
    print "directory: ", $path->directory, "\n";
    print "absolute: ", $path->absolute, "\n";
    print "parent: ", $path->parent, "\n";
    print "collapse: ", $path->collapse, "\n";
    print "from home: ", $path->relative('/Users/abw'), "\n";
    print "exists: ", $path->exists ? 'yes' : 'no', "\n";
    if ($path->exists) {
        print "owner: ", $path->owner ? 'yes' : 'no', "\n";
        print "readable: ", $path->readable ? 'yes' : 'no', "\n";
        print "writeable: ", $path->writeable ? 'yes' : 'no', "\n";
        print "executable: ", $path->executable ? 'yes' : 'no', "\n";
    }
    print "above here: ", $path->above($cwd) ? 'yes' : 'no', "\n";
    print "below here: ", $path->below($cwd) ? 'yes' : 'no', "\n";
    print "below /Users/abw: ", $path->below('/Users/abw') ? 'yes' : 'no', "\n";
    print "below /tmp: ", $path->below('/tmp') ? 'yes' : 'no', "\n";
    print "path: $path\n";
}
    
