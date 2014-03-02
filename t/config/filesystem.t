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
    tests => 26,
    debug => 'Badger::Config::Filesystem',
    args  => \@ARGV;

use Badger::Debug ':all';
use Badger::Config::Filesystem;

my $pkg = 'Badger::Config::Filesystem';

my $config = $pkg->new(
    root  => Bin->dir( test_files => 'config1' ),
    data  => { x => 10, y => 20 }, 
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
ok( $pages, "got pages" ); #. main->dump_data($pages) );

is( $pages->{ about }->{ name }, 'About Us', 'got "about" page' );
is( $pages->{"auth/login"}->{ name }, 'Login', 'got "auth/login" page' );
is( $pages->{"register"}->{ name }, 'Register', 'got "register" page' );

#-----------------------------------------------------------------------
# examples from docs
#-----------------------------------------------------------------------

is( $config->get('user', 'name', 'given'), 'Arthur', 'Arthur' );
is( $config->get('user.name.family'),      'Dent', 'Dent' );
is( $config->get(['user', 'email', '0']),     'arthur@dent.org', 'arthur@dent.org' );
is( $config->get([qw(user email 1)]),      'dent@heart-of-gold.com', 'dent@heart-of-gold.com' );
is( $config->get('things.2.babel'),        'fish', 'babel fish' );


#-----------------------------------------------------------------------------
# Second example with master config file containing schemas
#-----------------------------------------------------------------------------

my $config2 = $pkg->new(
    root    => Bin->dir( test_files => 'config2' ),
    file    => 'config',
    data    => { p => 11, q => 13 },
#   items   => 'pages',
    schemas => {
        urls => {
            tree_type => 'uri',
            uri_paths => 'absolute',
        }
    },
);

ok( $config2, 'Created second config object' );

# The first two are defined in the 'data' above when the object is created
is( $config2->p, 11, 'p is 11' );
is( $config2->q, 13, 'q is 13' );

# The next two are defined in the master config.yaml file
is( $config2->r, 17, 'r is 17' );
is( $config2->s, 19, 's is 19' );

my $pages2 = $config2->pages;
main->debug("got pages: ", main->dump_data($pages)) if DEBUG;

is( $pages2->{'/doge'}->{ name }, 'Wow!', 'Wow!' );
is( $pages2->{'/doge'}->{ title }, 'Such Metadata', 'Such Metadata' );

is( $pages2->{'/more/biscuits'}->{ name }, 'More Biscuits', 'More Biscuits' );
is( $pages2->{'/more/cheese'  }->{ name }, 'More Cheese',   'More Cheese'   );

