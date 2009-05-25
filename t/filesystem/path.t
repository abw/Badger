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
use File::Spec;
use Badger::Filesystem ':types';
use Badger::Filesystem::Path;
use Badger::Test 
    tests => 48,
    debug => 'Badger::Filesystem::Path',
    args  => \@ARGV;

our $PATH  = 'Badger::Filesystem::Path';
our $FS    =  $PATH->filesystem;
our $CWD   = $FS->cwd;
my ($path, $sub);

# ugly hack to grok file separator on local filesystem
my $PATHSEP  = File::Spec->catdir(('badger') x 2);
$PATHSEP =~ s/badger//g;

# convert unix-like paths into local equivalent
sub lp($) {
    my $path = shift;
    $path =~ s|/|$PATHSEP|g;
    $path;
}

$path = $PATH->new('foo');
ok( $path, 'created a new file: foo' );
ok( $path->is_relative, 'foo is relative' );
ok( ! $path->is_absolute, 'foo is not absolute' );
is( $path->absolute, $FS->join_dir($CWD, 'foo'), 'foo absolute is ' . $path->absolute );

if (1) { # && $FS->rootdir eq '/' && $FS->separator eq '/') {
    $path = $PATH->new('/foo');
    ok( $path, 'created a new file: /foo' );
    ok( ! $path->is_relative, '/foo is not relative' );
    ok( $path->is_absolute, '/foo is absolute' );
    is( $path->absolute, lp '/foo', '/foo is already absolute' );
    
    #-----------------------------------------------------------------------
    # test construction
    #-----------------------------------------------------------------------
    
    $path = $PATH->new('/foo/bar/baz');
    is( $path->relative('bam'), lp '/foo/bar/baz/bam', '/foo/bar/baz + bam' );
    is( $path->relative('/bam'), lp '/bam', '/foo/bar/baz + /bam' );
    is( $path->relative('../../wam'), lp '/foo/wam', '/foo/bar/baz + ../../wam' );
}
else {
    skip_some(7, 'Non-standard file separators')
}

#-----------------------------------------------------------------------
# base()
#-----------------------------------------------------------------------

is( Path('/foo/bar')->base, lp '/foo/bar', 'path base' );
is( Directory('/foo/bar')->base, lp '/foo/bar', 'dir base' );
is( File('/foo/bar')->base, lp '/foo', 'file base' );


#-----------------------------------------------------------------------
# parent()
#-----------------------------------------------------------------------

# absolute
is( Path('/foo/bar')->parent, lp '/foo', 'absolute path parent' );
is( Directory('/foo/bar/baz')->parent, lp '/foo/bar', 'absolute dir parent' );
is( File('/foo/bar/baz/bam')->parent, lp '/foo/bar/baz', 'absolute file parent' );
is( Path('/foo/bar/baz/bam')->parent, lp '/foo/bar/baz', 'absolute path parent' );
is( Path('/foo/bar/baz/bam')->parent(0), lp '/foo/bar/baz', 'absolute path parent zero' );
is( Path('/foo/bar/baz/bam')->parent(1), lp '/foo/bar', 'absolute path parent one' );
is( Path('/foo/bar/baz/bam')->parent(2), lp '/foo', 'absolute path parent two' );
is( Path('/foo/bar/baz/bam')->parent(3), lp '/', 'absolute path parent three' );
is( Path('/foo/bar/baz/bam')->parent(4), lp '/', 'absolute path parent four' );
is( Path('/foo/bar/baz/bam')->parent(5), lp '/', 'absolute path parent five' );

# relative
my $cwd = $FS->dir;
is( Path('foo/bar')->parent, 'foo', 'relative path parent' );
is( Path('foo/bar/')->parent, 'foo', 'relative path trailing slash parent' );
is( Directory('foo/bar/baz')->parent, lp 'foo/bar', 'relative dir parent' );
is( File('foo/bar/baz/bam')->parent, lp 'foo/bar/baz', 'relative file parent' );
is( Path('foo/bar/baz/bam')->parent, lp 'foo/bar/baz', 'relative path parent' );
is( Path('foo/bar/baz/bam')->parent(0), lp 'foo/bar/baz', 'relative path parent zero' );
is( Path('foo/bar/baz/bam')->parent(1), lp 'foo/bar', 'relative path parent one' );
is( Path('foo/bar/baz/bam')->parent(2), 'foo', 'relative path parent two' );
is( Path('foo/bar/baz/bam')->parent(3), $cwd, "relative path parent three is $cwd" );
is( Path('foo/bar/baz/bam')->parent(4), $cwd->parent, 'relative path parent four is ' . $cwd->parent );
is( Path('foo/bar/baz/bam')->parent(5), $cwd->parent(1), 'relative path parent five is ' . $cwd->parent(1) );


#-----------------------------------------------------------------------
# canonical
#-----------------------------------------------------------------------

my $abs = Cwd->dir('foo/bar')->absolute;
my $can = $abs . '/';

is( Path('foo/bar')->canonical, lp $abs, 'canonical foo/bar' );
is( Path('/foo/bar')->canonical, lp '/foo/bar', 'canonical /foo/bar' );
is( Path('/foo/bar/')->canonical, lp '/foo/bar', 'canonical /foo/bar/' );
is( Dir('foo/bar')->canonical, lp $can, 'canonical dir foo/bar' );
is( Dir('/foo/bar')->canonical, lp '/foo/bar/', 'canonical dir /foo/bar' );
is( Dir('/foo/bar/')->canonical, lp '/foo/bar/', 'canonical dir /foo/bar/' );


#-----------------------------------------------------------------------
# ext() / extension() / basename() / base_name()
#-----------------------------------------------------------------------

is( Path('foo.txt')->ext, 'txt', 'ext' );
is( Path('foo/bar.baz.html')->extension, 'html', 'extension' );
is( Path('foo.txt')->basename, 'foo', 'basename' );
is( Path('foo.txt')->base_name, 'foo', 'base_name' );

# See additional test in t/fileystem/file.t.  Note that this doesn't work
# with base class Path objects because they have no 'name' defined - just 
# the full 'path'. So basename() on foo/bar.baz.html returns foo/bar.baz
# That's OK, though, because we never use the base class Path object directly
# is( File('foo/bar.baz.html')->basename, 'bar.baz', 'multi-dotted basename' );


#-----------------------------------------------------------------------
# metadata
#-----------------------------------------------------------------------

$path = Path('/foo/bar');
ok( $path->meta( title => 'An Example' ), 'set metadata' );
is( $path->meta('title'), 'An Example', 'get metadata with name' );
is( $path->meta->{ title }, 'An Example', 'get metadata from hash' );

