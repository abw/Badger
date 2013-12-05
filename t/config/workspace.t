#============================================================= -*-perl-*-
#
# t/config/workspace.t
#
# Test the Badger::Workspace module.
#
# Copyright (C) 2008-2013 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;

use lib qw( ./lib ../lib ../../lib t/config/lib );
use Badger::Debug ':all';
use Badger::Test 
    tests => 22,
    debug => 'Badger::Workspace Badger::Hub Badger::Cache Badger::Config::Directory',
    args  => \@ARGV;

use Badger::Utils 'Bin';
use Badger::Workspace;
my $pkg  = 'Badger::Workspace';
my $dir1 = Bin->dir('test_files/wspace1');
my $dir2 = Bin->dir('test_files/wspace2');
my $web1 = $dir1->dir('web');
my $web2 = $dir2->dir('web');

#-----------------------------------------------------------------------------
# Top level workspace
#-----------------------------------------------------------------------------

my $wspace = $pkg->new( directory => $dir1 );
ok( $wspace, "Created $wspace object" );
is( $wspace->uri, 'workspace:wspace1', 'workspace uri' );

my $webdir = $wspace->dir('web');
ok( $webdir, "Got webdir" );
is( $webdir, $web1, "webdir is $webdir" );

my $pages = $wspace->config->get('pages');
ok( $pages, "Got pages config data" );
main->debug(
    "Pages: ",
    main->dump_data($pages)
) if DEBUG;

my $wibble = $wspace->config('wibble');
ok( $wibble, "fetched wibble data" );

my $pouch = $wspace->config('wibble.item');
my $style = $wspace->config('wibble.wibbled');
is( $pouch, 'frusset pouch', "fetched wibble.item frusset pouch" );
is( $style, 'pleasantly', "You have pleasantly wibbled my frusset pouch" );

my $data = $wspace->config->data;
main->debug("config data: ", main->dump_data($data)) if DEBUG;

#-----------------------------------------------------------------------------
# Subspace
#-----------------------------------------------------------------------------

my $subspace = $wspace->subspace( directory => $dir2 );
ok( $subspace, "Created $subspace object" );
is( $subspace->uri, 'workspace:wspace2', 'subspace uri' );
is( $subspace->dir('web'), $web2, "subspace webdir is $web2" );

my $swibble = $subspace->config('wibble');
ok( $swibble, "subspace fetched wibble data" );

is( $swibble->{ item    }, 'frusset pouch', "subspace fetched wibble.item frusset pouch" );
is( $swibble->{ wibbled }, 'pleasantly', "subspace pleasantly wibbled my frusset pouch" );

my $again = $subspace->config('wibble');
ok( $again, "subspace fetched wibble data again" );

main->debug("config data: ", main->dump_data($subspace->config->data)) if DEBUG;


#-----------------------------------------------------------------------------
# components
#-----------------------------------------------------------------------------

my $comp_cfg = $subspace->config('components');
main->debug(
    "components config: ",
    main->dump_data($comp_cfg)
) if DEBUG;

is( $comp_cfg->{ flibble }, 'My::Flibble', 'flibble component config' );
is( $comp_cfg->{ wibble }, 'My::Wibble', 'wibble component config' );
is( $comp_cfg->{ tribble }, 'My::Tribble', 'tribble component config' );
is( $comp_cfg->{ flobble }->{ module }, 'My::Flobble', 'flobble component config' );
is( $comp_cfg->{ wobble }->{ module }, 'My::Wobble', 'wobble component config' );

# trouble component is excluded by inherit/exclude rule in workspace.yaml
ok( ! $comp_cfg->{ trouble }, 'no trouble' );


my $wobble = $subspace->component('wobble');
ok( $wobble, 'got a wobble component' );
is( $wobble->name, 'WOBBLE', 'wobble name' );

#-----------------------------------------------------------------------------
# comment
#-----------------------------------------------------------------------------
