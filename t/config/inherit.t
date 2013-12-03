#============================================================= -*-perl-*-
#
# t/config/inherit.t
#
# Test the Badger::Config::Directory module with a parent config object
# to inherit from.
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
    tests => 6,
    debug => 'Badger::Config Badger::Config::Directory',
    args  => \@ARGV;

use Badger::Utils 'Bin';
use Badger::Config::Directory;
use Cache::Memory;          # TODO: skip if not found...

my $cache  = Cache::Memory->new;
my $pkg    = 'Badger::Config::Directory';
my $dir2   = Bin->dir('test_files/dir2');
my $dir3   = Bin->dir('test_files/dir3');
my $parent = $pkg->new( 
    cache     => $cache,
    directory => $dir2,
    file      => 'config',
    uri       => 'config:parent',
);
ok( $parent, "Created parent $pkg object" );

my $child = $pkg->new( 
    cache     => $cache,
    directory => $dir3,
    file      => 'config',
    uri       => 'config:child',
    parent    => $parent,
);
ok( $child, "Created child $pkg object" );

my $one = $child->get('one');
ok( $one, 'got one' );

my $two = $child->get('two');
ok( ! $two, 'did NOT get two (correctly)' );

my $ten = $child->get('ten');
ok( $ten, 'got ten' );

my $three = $child->get('three');
ok( $three, 'got three' );
main->debug(
    main->dump_data($three)
) if DEBUG;
