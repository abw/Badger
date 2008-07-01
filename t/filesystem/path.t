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

SKIP: {
    skip('Non-standard file separators', 7)
        unless $FS->rootdir eq '/' && $FS->separator eq '/';

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
    