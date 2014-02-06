#============================================================= -*-perl-*-
#
# t/config/filesystem.t
#
# Test the Badger::Config::Filesystem module.
#
# Copyright (C) 2008-2014 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ../../lib );
use Badger::Filesystem 'Bin';

use Badger::Test 
    tests => 17,
    debug => 'Badger::Config::Filesystem',
    args  => \@ARGV;

use Badger::Debug ':all';
use Badger::Config::Filesystem;

my $pkg = 'Badger::Config::Filesystem';

my $config = $pkg->new(
    root => Bin->dir( test_files => 'cfgfs' ),
    data => { x => 10, y => 20 }, 
    items => 'a b c',
);

is( $config->x, 10, 'x is 10' );
is( $config->y, 20, 'y is y0' );

eval { $config->z };
like( $@, qr/Invalid method 'z' called on Badger::Config/, 'bad method' );

ok( ! $config->a, 'a is undefined' );
ok( ! $config->b, 'b is undefined' );
ok( ! $config->c, 'c is undefined' );

my $site = $config->get('site');
ok( $site, "got site" ); # . main->dump_data($site) );

my $name = $config->get('site.name');
is( $name, "example", "got name: $name" );

my $pages = $config->get('pages');
ok( $pages, "got pages" . main->dump_data($pages) );

is( $pages->{ about }->{ name }, 'About Us', 'got "about" page' );
is( $pages->{"auth/login"}->{ name }, 'Login', 'got "auth/login" page' );
is( $pages->{"/register"}->{ name }, 'Register', 'got "/register" page' );

#-----------------------------------------------------------------------
# examples from docs
#-----------------------------------------------------------------------

is( $config->get('user', 'name', 'given'), 'Arthur', 'Arthur' );
is( $config->get('user.name.family'),      'Dent', 'Dent' );
is( $config->get(['user', 'email', '0']),     'arthur@dent.org', 'arthur@dent.org' );
is( $config->get([qw(user email 1)]),      'dent@heart-of-gold.com', 'dent@heart-of-gold.com' );
is( $config->get('things.2.babel'),        'fish', 'babel fish' );

