#============================================================= -*-perl-*-
#
# t/storage/filesys.t
#
# Test filesystem storage.
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
use Badger::Filesystem;
use Badger::Storage::Filesystem::Store;
use Badger::Test skip => 'storage subsystem is experimental';

our $DEBUG = $Badger::Storage::Filesystem::Store::DEBUG = grep(/^-d/, @ARGV);
our $STORE = 'Badger::Storage::Filesystem::Store';
our $FS    = 'Badger::Filesystem';
our $TDIR  = -d 't' ? $FS->join_dir(qw(t storage)) : $FS->directory;
our $ROOT  = $FS->directory($TDIR);

print "test dir: $ROOT\n" if $DEBUG;

my $store = $STORE->new( directory => $ROOT->directory('tmp_store') );
ok( $store, 'created new filesystem store' );

my $badgers = $store->table('badgers');
ok( $badgers, 'got a badgers table' );

my $franky = $badgers->try( fetch_record => 'franky' );
if ($franky) {
    print "franky: $franky\n";
    ok($franky->delete, "got existing Franky Badger");
}
else {
    ok(1, "no existing Franky Badger");
}
    
$franky = $badgers->create_record( 
    franky => { name => 'Franky Badger' }
);
ok( $franky, 'created Franky Badger' );

$franky = $badgers->fetch_record('franky');
ok( $franky, 'fetched Franky Badger' );

#use Data::Dumper;
#print Dumper $franky;
#print "franky: $franky = ", $franky->name, "\n";
is( $franky->name, 'Franky Badger', 'got Franky Badger back out' );

ok( $franky->delete, 'deleted franky' );
__END__
