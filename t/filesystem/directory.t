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
use Badger::Filesystem::Directory;
use Test::More tests => 30;

our $DEBUG = $Badger::Filesystem::Directory::DEBUG = grep(/^-d/, @ARGV);
our $DIR = 'Badger::Filesystem::Directory';

my $dir = $DIR->new('example');

ok( $dir, 'created a new directory' );
is( $dir->name, 'example', 'got example name' );
ok( ! $dir->volume, 'got (no) file volume' );
ok( ! $dir->dir, 'got (no) file directory' );

is( $DIR->new(name => 'example')->name,
    'example', 'got dir using name param' );

is ( $DIR->new(path => 'example')->name,
    'example', 'got dir using path param' );

is( $DIR->new({ name => 'example' })->name,
    'example', 'got dir using name param hash' );

is ( $DIR->new({ path => 'example' })->name,
    'example', 'got dir using path param hash' );


$dir = $DIR->new('/foo/bar/baz');
is( $dir, '/foo/bar/baz', 'foo/bar/baz path');
is( $dir->dir, '/foo/bar/', 'foo/bar dir');
is( $dir->name, 'baz', 'baz file' );

$dir = $DIR->new('/foo/bar/baz/');
is( $dir, '/foo/bar/baz', 'foo/bar/baz path with trailing slash');
is( $dir->dir, '/foo/bar/', 'foo/bar dir with trailing slash');
is( $dir->name, 'baz', 'baz file with trailing slash' );

#-----------------------------------------------------------------------
# test the up() method (alias for parent())
#-----------------------------------------------------------------------

$dir = $DIR->new('/path/to/file/number/one');
is( $dir, '/path/to/file/number/one', 'full path' );
is( $dir->up, '/path/to/file/number', 'path up one' );
is( $dir->up->up, '/path/to/file', 'path up two' );
is( $dir->up(1), '/path/to/file', 'path up, skip one' );
is( $dir->up(2), '/path/to', 'path up, skip two' );
is( $dir->up(3), '/path', 'path up, skip three' );
is( $dir->up(4), '/', 'path up, skip four' );
is( $dir->up(42), '/', 'path up, skip fourty two' );

is( $dir->directory('two'), '/path/to/file/number/one/two', 
    'relative path down' );
is( $dir->directory('../three'), '/path/to/file/number/three', 
    'relative path up' );
is( $dir->directory('../../four'), '/path/to/file/four', 
    'relative path up up' );
is( $dir->directory('/five'), '/five', 
    'absolute path on relative path' );

is( $dir->file('two.txt'), '/path/to/file/number/one/two.txt', 
    'relative file down' );
is( $dir->directory('../three.pm'), '/path/to/file/number/three.pm', 
    'relative file up' );
is( $dir->directory('../../four.pl'), '/path/to/file/four.pl', 
    'relative file up up' );
is( $dir->directory('/five'), '/five', 
    'absolute file on relative path' );

