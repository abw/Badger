#============================================================= -*-perl-*-
#
# t/filesystem/universal.t
#
# Test the Badger::Filesystem::Universal module.
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
use Badger::Filesystem 'FS UFS';
use Badger::Test 
    skip  => 'Still in development',
    tests => 59,
#    debug => 'Badger::Filesystem Badger::Filesystem::Universal Badger::Filesystem::FileSpec::Universal',
    debug => 'Badger::Filesystem::FileSpec::Universal',
    args  => \@ARGV;

#our $TDIR = -d 't' ? FS->join_dir(qw(t filesystem)) : FS->directory;

my $ufs = UFS->new;
my $uri;

#my $uri = $ufs->file('foo');
#is( $uri, 'foo', 'foo' );


#print "FS: ", $uri->filesystem, "\n";
#print "FS: ", $uri->filesystem->spec, "\n";


is( $ufs->path('foo', 'bar'), 'foo/bar', 'foo/bar' );
is( $ufs->path('foo/baz'), 'foo/baz', 'foo/baz' );
is( $ufs->path('/foo/bam'), '/foo/bam', 'foo/bam' );


$uri = $ufs->path('/foo/bar/baz');
is( $uri->parent, '/foo/bar', '/foo/bar/baz parent' );


#-----------------------------------------------------------------------
# volume(), dir(), name()
#-----------------------------------------------------------------------

$uri = $ufs->file('http://path/to/some_file');
ok( $uri, 'fetched url path from UFS' );
is( $uri->volume, 'http', 'url volume' );
is( $uri->dir, '/path/to', 'url directory' );
is( $uri->name, 'some_file', 'url name' );

my $file = $ufs->file('/path/to/some_file');
ok( $file, 'fetched file from UFS' );
is( $file->dir, '/path/to', 'file directory' );
is( $file->name, 'some_file', 'file name' );


#-----------------------------------------------------------------------
# is_absolute(), is_relative()
#-----------------------------------------------------------------------

ok( $ufs->is_absolute('/foo'), '/foo is absolute' );
ok( ! $ufs->is_absolute('foo'), 'foo is not absolute' );

ok( $ufs->is_relative('foo'), 'foo is relative' );
ok( ! $ufs->is_relative('/foo'), '/foo is not relative' );

#-----------------------------------------------------------------------
# merge paths
#-----------------------------------------------------------------------

__END__
is( $fs->merge_paths('/path/one', '/path/two'), lp '/path/one/path/two', 'merged abs paths' );
is( $fs->merge_paths('/path/one', 'path/two'), lp '/path/one/path/two', 'merged abs/rel paths' );
is( $fs->merge_paths('path/one', 'path/two'), lp 'path/one/path/two', 'merged rel/rel paths' );
