#============================================================= -*-perl-*-
#
# t/config/cache.t
#
# Test the Badger::Config::Directory module with a memory cache
#
# Copyright (C) 2008-2013 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;

use lib qw( ./lib ../lib ../../lib );
use Badger::Debug ':all';
use Badger::Test 
    tests => 4,
    debug => 'Badger::Cache',
    args  => \@ARGV;

use Badger::Cache;

my $cache  = Badger::Cache->new;

ok( $cache, 'created cache' );
$cache->set( 
    foo => {
        a => 10,
        b => [20,30,40],
    }
);

my $foo = $cache->get('foo');
ok( $foo, 'got foo' );
is( $foo->{ a }, 10, 'foo.a is 10' );
is( $foo->{ b }->[1], 30, 'foo.b.1 is 30' );

main->debug(
    "foo: ",
    main->dump_data($foo)
) if DEBUG;


__END__
my $pkg    = 'Badger::Config::Directory';
my $dir2   = Bin->dir('test_files/dir2');
my $config = $pkg->new( 
    directory => $dir2,
    file      => 'config',
    cache     => $cache,
    uri       => 'wibble:frusset',
);
ok( $config, "Created $pkg object" );

my $one_a = $config->get('one');
ok( $one_a, "got one: $one_a" );

my $one_b = $config->get('one');
ok( $one_b, "got one again: $one_b" );

is( $one_a, $one_b, "same reference" );
