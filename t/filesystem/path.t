#============================================================= -*-perl-*-
#
# t/filesystem/path.t
#
# Test the Badger::Filesystem::Path module
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
use Badger::Filesystem ':types';
use Badger::Filesystem::Path;
use Badger::Test 
    tests => 40,
    debug => 'Badger::Filesystem::Path',
    args  => \@ARGV;

our $PATH  = 'Badger::Filesystem::Path';
our $FS    =  $PATH->filesystem;
our $CWD   = $FS->cwd;
my ($path, $sub);

$path = $PATH->new('foo');
ok( $path, 'created a new file: foo' );
ok( $path->is_relative, 'foo is relative' );
ok( ! $path->is_absolute, 'foo is not absolute' );
is( $path->absolute, $FS->join_dir($CWD, 'foo'), 'foo absolute is ' . $path->absolute );

if ($FS->rootdir eq '/' && $FS->separator eq '/') {
    $path = $PATH->new('/foo');
    ok( $path, 'created a new file: /foo' );
    ok( ! $path->is_relative, '/foo is not relative' );
    ok( $path->is_absolute, '/foo is absolute' );
    is( $path->absolute, '/foo', '/foo is already absolute' );
    
    #-----------------------------------------------------------------------
    # test construction
    #-----------------------------------------------------------------------
    
    $path = $PATH->new('/foo/bar/baz');
    is( $path->relative('bam'), '/foo/bar/baz/bam', '/foo/bar/baz + bam' );
    is( $path->relative('/bam'), '/bam', '/foo/bar/baz + /bam' );
    is( $path->relative('../../wam'), '/foo/wam', '/foo/bar/baz + ../../wam' );
}
else {
    skip_some(7, 'Non-standard file separators')
}

#-----------------------------------------------------------------------
# base()
#-----------------------------------------------------------------------

is( Path('/foo/bar')->base, '/foo/bar', 'path base' );
is( Directory('/foo/bar')->base, '/foo/bar', 'dir base' );
is( File('/foo/bar')->base, '/foo', 'file base' );


#-----------------------------------------------------------------------
# parent()
#-----------------------------------------------------------------------

# absolute
is( Path('/foo/bar')->parent, '/foo', 'absolute path parent' );
is( Directory('/foo/bar/baz')->parent, '/foo/bar', 'absolute dir parent' );
is( File('/foo/bar/baz/bam')->parent, '/foo/bar/baz', 'absolute file parent' );
is( Path('/foo/bar/baz/bam')->parent, '/foo/bar/baz', 'absolute path parent' );
is( Path('/foo/bar/baz/bam')->parent(0), '/foo/bar/baz', 'absolute path parent zero' );
is( Path('/foo/bar/baz/bam')->parent(1), '/foo/bar', 'absolute path parent one' );
is( Path('/foo/bar/baz/bam')->parent(2), '/foo', 'absolute path parent two' );
is( Path('/foo/bar/baz/bam')->parent(3), '/', 'absolute path parent three' );
is( Path('/foo/bar/baz/bam')->parent(4), '/', 'absolute path parent four' );
is( Path('/foo/bar/baz/bam')->parent(5), '/', 'absolute path parent five' );

# relative
my $cwd = $FS->dir;
is( Path('foo/bar')->parent, 'foo', 'relative path parent' );
is( Path('foo/bar/')->parent, 'foo', 'relative path trailing slash parent' );
is( Directory('foo/bar/baz')->parent, 'foo/bar', 'relative dir parent' );
is( File('foo/bar/baz/bam')->parent, 'foo/bar/baz', 'relative file parent' );
is( Path('foo/bar/baz/bam')->parent, 'foo/bar/baz', 'relative path parent' );
is( Path('foo/bar/baz/bam')->parent(0), 'foo/bar/baz', 'relative path parent zero' );
is( Path('foo/bar/baz/bam')->parent(1), 'foo/bar', 'relative path parent one' );
is( Path('foo/bar/baz/bam')->parent(2), 'foo', 'relative path parent two' );
is( Path('foo/bar/baz/bam')->parent(3), $cwd, "relative path parent three is $cwd" );
is( Path('foo/bar/baz/bam')->parent(4), $cwd->parent, 'relative path parent four is ' . $cwd->parent );
is( Path('foo/bar/baz/bam')->parent(5), $cwd->parent(1), 'relative path parent five is ' . $cwd->parent(1) );


#-----------------------------------------------------------------------
# ext() / extension()
#-----------------------------------------------------------------------

is( Path('foo.txt')->ext, 'txt', 'ext' );
is( Path('foo/bar.baz.html')->extension, 'html', 'extension' );

#-----------------------------------------------------------------------
# metadata
#-----------------------------------------------------------------------

$path = Path('/foo/bar');
ok( $path->meta( title => 'An Example' ), 'set metadata' );
is( $path->meta('title'), 'An Example', 'get metadata with name' );
is( $path->meta->{ title }, 'An Example', 'get metadata from hash' );

