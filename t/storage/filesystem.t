#============================================================= -*-perl-*-
#
# t/storage/filesystem.t
#
# Test the Badger::Storage::Filesystem module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ./lib ../lib ../../lib );
use Badger::Filesystem 'Bin';
use Badger::Test 
    tests => 32,
    debug => 'Badger::Storage::Filesystem',
    args  => \@ARGV;

use Badger::Storage::Filesystem;
use Badger::Codecs;

our $tmp_dir = Bin->dir('tmp_store');
our $storage = Badger::Storage::Filesystem->new(
    path => $tmp_dir
);
our $foo = {
    name    => 'foo',
    pi      => 3.14,
    message => "Hello World!",
};
our $bar = {
    e => 2.718,
};
our $bam = {
    e  => 2.718,
    pi => 3.142,
};
our $baz = {
    foo => $foo,
    bar => $bar,
};

#-----------------------------------------------------------------------
# test basic store/fetch
#-----------------------------------------------------------------------

ok( $storage, 'got filesystem storage object' );
ok( $storage->store( foo => $foo ), 'stored foo data' );

my $data = $storage->fetch('foo');
ok( $data, 'fetched foo data' );

is( $data->{ name    }, $foo->{ name    }, "name: $foo->{ name }" );
is( $data->{ pi      }, $foo->{ pi      }, "pi: $foo->{ pi }" );
is( $data->{ message }, $foo->{ message }, "message: $foo->{ message }" );

ok( $tmp_dir->file('foo')->exists, 'foo file exists' );

#-----------------------------------------------------------------------
# try it with a difference codec
#-----------------------------------------------------------------------

$storage = Badger::Storage::Filesystem->new(
    path  => $tmp_dir,
    codec => 'tt',
);

ok( $storage, 'got filesystem storage object with TT codec' );
ok( $storage->store( bar => $bar ), 'stored bar data' );

$data = $storage->fetch('bar');
ok( $data, 'fetched bar data' );

is( $data->{ e }, $bar->{ e }, "e: $bar->{ e }" );

my $bar_file = $tmp_dir->file('bar');
ok( $bar_file->exists, 'bar file exists' );

my $tt = $bar_file->text;
like( $tt, qr/e=$bar->{ e }/, "TT contains e: $bar->{ e }" );


#-----------------------------------------------------------------------
# test we can pass a codec object
#-----------------------------------------------------------------------

my $codec = Badger::Codecs->codec( tt => { assign => ':', comma => ',' } );

$storage = Badger::Storage::Filesystem->new(
    path  => $tmp_dir,
    codec => $codec,
);

ok( $storage, 'got filesystem storage object with custom TT codec' );
ok( $storage->store( bam => $bam ), 'stored bam data' );

$data = $storage->fetch('bam');
ok( $data, 'fetched bam data' );
is( $data->{ e }, $bam->{ e }, "bam e: $bam->{ e }" );
is( $data->{ pi }, $bam->{ pi }, "bam pi: $bam->{ pi }" );

my $bam_file = $tmp_dir->file('bam');
ok( $bam_file->exists, 'bam file exists' );

$tt = $bam_file->text;
like( $tt, qr/e:$bam->{e},pi:$bam->{pi}/, "TT contains e: $bam->{e} and pi: $bam->{pi}" );


#-----------------------------------------------------------------------
# test create() method which should generate id automagically
#-----------------------------------------------------------------------

my $id = $storage->create( $baz );
ok( $id, "got generated id: $id" );

$data = $storage->fetch($id);
ok( $data, 'fetched data using generated id' );
is( $data->{ foo }->{ pi }, $foo->{ pi }, "pi: $foo->{ pi }" );
is( $data->{ bar }->{ e  }, $bar->{ e  }, "e: $bar->{ e }" );


#-----------------------------------------------------------------------
# test delete() works
#-----------------------------------------------------------------------

ok( $storage->delete('foo'), 'deleted foo' );
ok( ! $tmp_dir->file('foo')->exists, 'foo file no longer exists' );

ok( $storage->delete('bar'), 'deleted bar' );
ok( ! $tmp_dir->file('bar')->exists, 'bar file no longer exists' );

ok( $storage->delete('bam'), 'deleted bam' );
ok( ! $tmp_dir->file('bam')->exists, 'bam file no longer exists' );

ok( $storage->delete($id), "deleted $id" );
ok( ! $tmp_dir->file($id)->exists, "generated file no longer exists" );

