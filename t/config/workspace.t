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

use lib qw( ./lib ../lib ../../lib );
use Badger::Debug ':all';
use Badger::Test 
    tests => 1,
    debug => 'Badger::Workspace Badger::Config::Directory',
    args  => \@ARGV;

use Badger::Utils 'Bin';
use Badger::Workspace;
my $pkg  = 'Badger::Workspace';
my $dir1 = Bin->dir('test_files/wspace1');

my $wspace = $pkg->new( directory => $dir1 );
ok( $wspace, "Created $wspace object" );

my $pages = $wspace->config->get('pages');
ok( $pages, "Got pages config data" );
main->debug(
    "Pages: ",
    main->dump_data($pages)
) if DEBUG;

#-----------------------------------------------------------------------------
# You have pleasantly wibbled my frusset pouch
#-----------------------------------------------------------------------------

my $wibble = $wspace->config('wibble');
ok( $wibble, "fetched wibble data" );

my $pouch = $wspace->config('wibble.item');
my $style = $wspace->config('wibble.wibbled');
is( $pouch, 'frusset pouch', "fetched wibble.item frusset pouch" );
is( $style, 'pleasantly', "You have pleasantly wibbled my frusset pouch" );

