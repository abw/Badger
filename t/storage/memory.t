#============================================================= -*-perl-*-
#
# t/storage/memory.t
#
# Test the Badger::Storage::Memory module.
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
    tests => 47,
    debug => 'Badger::Storage::Memory',
    args  => \@ARGV;

use Badger::Storage::Memory;

our $storage = Badger::Storage::Memory->new;
ok( $storage, 'created memory storage' );

our $foo = {
    e => 2.718,
};
our $bar = {
    e  => 2.718,
    pi => 3.142,
};

#-----------------------------------------------------------------------
# test basic create/fetch/store/delete
#-----------------------------------------------------------------------

my ($id, $data);
    
$id = $storage->create($foo);
ok( $id, "created record with id: $id" );

$data = $storage->fetch($id);
ok( $data, "fetched data" );
is( $data->{ e }, 2.718, 'e is defined' );
ok( ! defined $data->{ pi }, 'pi is not defined' );

ok( $storage->store( $id => $bar ), 'stored bam data' );

$data = $storage->fetch($id);

ok( $data, 'fetched modified data' );
is( $data->{ e }, 2.718, 'e is still defined' );
is( $data->{ pi }, 3.142, 'pi is now also defined' );

ok( $storage->delete($id), 'deleted record' );
ok( ! defined $storage->fetch($id), 'can no longer fetch data' );


#-----------------------------------------------------------------------
# test aliases - Cache::Cache et al: set(), get(), remove()
#-----------------------------------------------------------------------

$storage->set($id => $foo);
ok( $id, "CC: set(): $id" );
$data = $storage->get($id);
ok( $data, 'CC: get()' );
is( $data->{ e }, 2.718, 'CC: e is defined' );
ok( ! defined $data->{ pi }, 'CC: pi is not defined' );
ok( $storage->set( $id => $bar ), 'CC: set()' );
$data = $storage->get($id);
is( $data->{ e }, 2.718, 'CC: e is still defined' );
is( $data->{ pi }, 3.142, 'CC: pi is now also defined' );
ok( $storage->remove($id), 'CC: remove()' );
ok( ! defined $storage->fetch($id), 'CC: can no longer fetch data' );


#-----------------------------------------------------------------------
# test aliases - CRUD
#-----------------------------------------------------------------------

$id = $storage->create($foo);
ok( $id, "CRUD create(): $id" );
$data = $storage->retrieve($id);
ok( $data, 'CRUD: retrieve()' );
is( $data->{ e }, 2.718, 'CRUD: e is defined' );
ok( ! defined $data->{ pi }, 'CRUD: pi is not defined' );
ok( $storage->update( $id => $bar ), 'CRUD: update()' );
$data = $storage->fetch($id);
is( $data->{ e }, 2.718, 'CRUD: e is still defined' );
is( $data->{ pi }, 3.142, 'CRUD: pi is now also defined' );
ok( $storage->delete($id), 'CRUD: delete()' );
ok( ! defined $storage->fetch($id), 'CRUD: can no longer fetch data' );

#-----------------------------------------------------------------------
# test aliases - REST
#-----------------------------------------------------------------------

$id = $storage->post($foo);
ok( $id, "REST post(): $id" );
$data = $storage->get($id);
ok( $data, 'REST: get()' );
is( $data->{ e }, 2.718, 'REST: e is defined' );
ok( ! defined $data->{ pi }, 'REST: pi is not defined' );
ok( $storage->put( $id => $bar ), 'REST: put()' );
$data = $storage->get($id);
is( $data->{ e }, 2.718, 'REST: e is still defined' );
is( $data->{ pi }, 3.142, 'REST: pi is now also defined' );
ok( $storage->delete($id), 'REST: delete()' );
ok( ! defined $storage->fetch($id), 'REST: can no longer fetch data' );


#-----------------------------------------------------------------------
# test aliases - file IO
#-----------------------------------------------------------------------

$id = $storage->create($foo);
ok( $id, "IO create(): $id" );
$data = $storage->read($id);
ok( $data, 'IO: read()' );
is( $data->{ e }, 2.718, 'IO: e is defined' );
ok( ! defined $data->{ pi }, 'IO: pi is not defined' );
ok( $storage->write( $id => $bar ), 'IO: put()' );
$data = $storage->read($id);
is( $data->{ e }, 2.718, 'IO: e is still defined' );
is( $data->{ pi }, 3.142, 'IO: pi is now also defined' );
ok( $storage->remove($id), 'IO: remove()' );
ok( ! defined $storage->fetch($id), 'IO: can no longer fetch data' );

