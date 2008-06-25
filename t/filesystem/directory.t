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
use Test::More tests => 16;

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
