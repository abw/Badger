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
use Badger::Test 
    tests => 39,
    debug => 'Badger::Filesystem::X Badger::Filesystem::Virtual',
    args  => \@ARGV;
use Badger::Filesystem 'FS';
use Badger::Filesystem::Virtual 'VFS';

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
# figure out where the t/filesystem/testfiles directory, depending on 
# where this script is being run from.
#-----------------------------------------------------------------------

our $here = -d 't' 
    ? FS->directory(qw(t filesystem))
    : FS->Cwd;
our $tfdir = $here->dir('testfiles');

$tfdir->must_exist;


#-----------------------------------------------------------------------
# creating a VFS with no explicit root directory should use the real 
# root directory, pretty much like a regular Badger::Filesystem
#-----------------------------------------------------------------------

my $fs = VFS->new;
ok( $fs, 'created a new virtual filesystem with default root' );
my $dir = $fs->dir($tfdir->absolute);
ok( $fs->dir($tfdir->absolute)->must_exist, 'got testfiles dir via default vfs' );


#-----------------------------------------------------------------------
# OK, so now let's try a VFS with our four virtual root directories
# The first, vdir_one, has just a 'foo' file.  The second, vdir_two, 
# has 'foo' and 'bar'.  The third, vdir_three, has 'foo', 'bar' and 'baz'.
# We should be returned foo from the first, bar from the second and baz
# from the third.  The fourth directory has a 'wibble' file and 'wobble'
# dir which we'll use later...
#-----------------------------------------------------------------------

my $vfs = VFS->new( 
    root => [ map { $tfdir->dir("vdir_$_") } qw( one two three four ) ]
);
ok( $vfs, 'created a new virtual filesystem with three roots' );

my $foo = $vfs->file('foo');
ok( $foo->exists, 'got foo' );
is( $foo->text, "This is foo in vdir_one\n", 'got foo from vdir_one' );

my $bar = $vfs->file('bar');
ok( $bar->exists, 'got bar' );
is( $bar->text, "This is bar in vdir_two\n", 'got bar from vdir_two' );

my $baz = $vfs->file('baz');
ok( $baz->exists, 'got baz' );
is( $baz->text, "This is baz in vdir_three\n", 'got baz from vdir_three' );


#-----------------------------------------------------------------------
# writing to a file should only happen in the first directory
#-----------------------------------------------------------------------

my $bam = $vfs->file('bam');
if ($bam->exists) {
    ok($bam->delete, 'deleted existing bam file');
}
else {
    pass('no existing bam file');
}

my $message = 'The random number is ' . int(rand(1000));
ok( $bam->write($message), 'wrote message to bam' );
ok( $bam->exists, 'bam exists' );
is( $bam->text, $message, "Read content: " . $message );

# check file exists in vdir_one using the *real* fs
my $bam_check = $tfdir->file( vdir_one => 'bam' );
ok( $bam_check->exists, 'independently checked bam exists' );
is( $bam_check->text, $message, "independently checked text: " . $message );

# delete it here and make sure VFS can't find it any more
ok( $bam_check->delete, 'deleted bam' );
ok( ! $bam_check->exists, 'bam no longer exists' );
ok( ! $bam->exists, 'VFS bam agrees' );


#-----------------------------------------------------------------------
# check we get a composite directory index
#-----------------------------------------------------------------------

is( join(', ', sort grep { ! /^\./ } $vfs->dir('/')->read), 'bar, baz, foo, wibble, wobble',
    'got composite index' );

my @kids = $vfs->dir('/')->children;
foreach my $kid (@kids) {
    next if $kid =~ /\.svn/;
    ok( $kid->exists, "$kid exists" );
}


#-----------------------------------------------------------------------
# try dynamic root generators
#-----------------------------------------------------------------------

sub gen1 {
    return [ map { $tfdir->dir("vdir_$_") } qw( one two ) ];
}

sub gen2 {
    return [ map { $tfdir->dir("vdir_$_") } qw( three four ) ];
}

my $paths = [\&gen1, [\&gen2]];
    
$vfs = VFS->new( root => $paths );
ok( $vfs, 'created a new virtual filesystem with root generator' );

is( $vfs->file('foo')->text, "This is foo in vdir_one\n", 'got foo from dynamic vdir_one' );
is( $vfs->file('bar')->text, "This is bar in vdir_two\n", 'got bar from dynamic vdir_two' );
is( $vfs->file('baz')->text, "This is baz in vdir_three\n", 'got baz from dynamic vdir_three' );

# changing the path shouldn't make any difference because we didn't set the
# dynamic flag.
@$paths = [\&gen2, \&gen1];
is( $vfs->file('foo')->text, "This is foo in vdir_one\n", 'got foo from dynamic vdir_one' );

unshift(@$paths, $tfdir->dir('vdir_two'));
is( $vfs->file('foo')->text, "This is foo in vdir_one\n", 'got foo from dynamic vdir_one again' );

$paths = [\&gen1, \&gen2];

$vfs = VFS->new( root => $paths, dynamic => 1 );
ok( $vfs, 'created a new dynamic virtual filesystem with root generator' );
is( $vfs->file('foo')->text, "This is foo in vdir_one\n", 'got foo from dynamic vdir_one yet again' );

# now that the dynamic flag is set, we can change the path
@$paths = [\&gen2, \&gen1];
is( $vfs->file('foo')->text, "This is foo in vdir_three\n", 'got foo from dynamic vdir_three' );

unshift(@$paths, $tfdir->dir('vdir_two'));
is( $vfs->file('foo')->text, "This is foo in vdir_two\n", 'got foo from dynamic vdir_two' );




#-----------------------------------------------------------------------
# test a purely virtual file system - there's no real directories 
# behind this (unless you happen to have a directory on your system
# matching /path/to/my/web/pages but I suspect that's unlikely!)
#-----------------------------------------------------------------------

$vfs = VFS->new(
    root => '/path/to/my/web/pages', 
);
ok( $vfs, 'created filesystem with virtual root' );

my $file1 = $vfs->file('foo', 'bar');
is( $file1->absolute, lp '/foo/bar', 'absolute foo bar in virtual root fs' );

$file1 = $vfs->file('/foo/bar');
is( $file1->absolute, lp '/foo/bar', 'absolute /foo/bar in virtual root fs' );
is( $file1->definitive, lp '/path/to/my/web/pages/foo/bar', 'definitive path adds root' );
ok( $vfs->virtual, 'filesystem is virtual' );

