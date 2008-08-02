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
    tests => 11,
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

is( Path('/foo/bar')->parent, '/foo', 'path parent' );
is( Directory('/foo/bar/baz')->parent, '/foo/bar', 'dir parent' );
is( File('/foo/bar/baz/bam')->parent, '/foo/bar/baz', 'file parent' );

is( Path('/foo/bar/baz/bam')->parent, '/foo/bar/baz', 'path parent none' );
is( Path('/foo/bar/baz/bam')->parent(0), '/foo/bar/baz', 'path parent zero' );
is( Path('/foo/bar/baz/bam')->parent(1), '/foo/bar', 'path parent one' );
is( Path('/foo/bar/baz/bam')->parent(2), '/foo', 'path parent two' );
is( Path('/foo/bar/baz/bam')->parent(3), '/', 'path parent three' );
is( Path('/foo/bar/baz/bam')->parent(4), '/', 'path parent four' );
is( Path('/foo/bar/baz/bam')->parent(5), '/', 'path parent five' );

