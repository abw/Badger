#============================================================= -*-perl-*-
#
# t/storage/storages.t
#
# Test the Badger::Storages module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ./lib ../lib ../../lib );
use Badger::Filesystem 'Bin';
use Badger::Storages 'Storage';
use Badger::Test 
    tests => 33,
    debug => 'Badger::Storages',
    args  => \@ARGV;

our $tmp_dir = Bin->dir('tmp_store');
our $input   = {
    message => 'Hello World',
};
our ($storage, $output, $filename, $outfile);


#-----------------------------------------------------------------------
# full blown ($type, \%args) usage
#-----------------------------------------------------------------------

$filename = 'fs1';
$storage  = Badger::Storages->storage( 
    filesystem => {
        path  => $tmp_dir,
        codec => 'tt',
    }
);

ok( $storage, 'got filesystem storage module' );
ok( $storage->store($filename, $input), "stored data in $filename" );

$output = $storage->fetch($filename);
ok( $output, "fetched data from $filename" );
is( $output->{ message }, $input->{ message }, "message matched in $filename" );

$outfile = $tmp_dir->file($filename);
ok( $outfile->exists, "file exists: $filename" );
like( $outfile->text, qr/message='Hello World'/, 'encoded with TT codec' );

ok( $outfile->delete, "deleted file: $filename" );


#-----------------------------------------------------------------------
# simplified ($type, $path) usage
#-----------------------------------------------------------------------

$filename = 'fs2';
$storage = Badger::Storages->storage( 
    filesystem => $tmp_dir,
);

ok( $storage, 'got filesystem storage module with path' );
ok( $storage->store($filename, $input), "stored data in $filename" );

$output = $storage->fetch($filename);
ok( $output, "fetched data from $filename" );
is( $output->{ message }, $input->{ message }, "message matched in $filename" );

$outfile = $tmp_dir->file($filename);
ok( $outfile->exists, "file exists: $filename" );
ok( $outfile->delete, "deleted file: $filename" );


#-----------------------------------------------------------------------
# uri style ($type:$path) usage
#-----------------------------------------------------------------------

$filename = 'fs3';
$storage = Badger::Storages->storage("file:$tmp_dir");

ok( $storage, 'got filesystem storage module with uri' );
ok( $storage->store($filename, $input), "stored data in $filename" );

$output = $storage->fetch($filename);
ok( $output, "fetched data from $filename" );
is( $output->{ message }, $input->{ message }, "message matched in $filename" );

$outfile = $tmp_dir->file($filename);
ok( $outfile->exists, "file exists: $filename" );
ok( $outfile->delete, "deleted file: $filename" );


#-----------------------------------------------------------------------
# check Storage() subroutine
#-----------------------------------------------------------------------

$storage = Storage( file => $tmp_dir );
ok( $storage, 'got storage from Storage() function' );
is( ref $storage, 'Badger::Storage::Filesystem', 'got filesystem storage' );

$storage = Storage( file => { path => $tmp_dir, codec => 'tt' } );
ok( $storage, 'got storage with custom codec from Storage() function' );
is( ref $storage, 'Badger::Storage::Filesystem', 'got custom codec filesystem storage' );

$filename = 'fs4';
ok( $storage->store($filename, $input), "stored data in $filename" );

$output = $storage->fetch($filename);
ok( $output, "fetched data from $filename" );
is( $output->{ message }, $input->{ message }, "message matched in $filename" );

$outfile = $tmp_dir->file($filename);
ok( $outfile->exists, "file exists: $filename" );
like( $outfile->text, qr/message='Hello World'/, "file encoding using TT" );
ok( $outfile->delete, "deleted file: $filename" );


#-----------------------------------------------------------------------
# check missing resource error
#-----------------------------------------------------------------------

ok( ! $storage->fetch('no_such_file'), 'did not find no_such_file' );
is( $storage->reason, 'File not found: no_such_file' );

ok( ! $storage->delete('no_such_file'), 'did not delete no_such_file' );
is( $storage->reason, 'File not found: no_such_file', 'no found error message' );
