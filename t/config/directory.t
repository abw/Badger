#============================================================= -*-perl-*-
#
# t/config/directory.t
#
# Test the Badger::Config::Directory module.
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
    tests => 30,
    debug => 'Badger::Config Badger::Config::Directory',
    args  => \@ARGV;

use Badger::Utils 'Bin';
use Badger::Config::Directory;
my $pkg  = 'Badger::Config::Directory';
my $dir1 = Bin->dir('test_files/dir1');

my $config = $pkg->new( directory => $dir1 );
ok( $config, "Created $pkg object" );


#-----------------------------------------------------------------------------
# Simple configuration file
#-----------------------------------------------------------------------------

my $project = $config->get('project');
ok( $project, 'got project config' );
is( $project->{ name    }, 'Badger', 'got the project name' );
is( $project->{ version }, '123', 'got the project version' );
is( $config->get('project.author.name'), 'Andy Wardley', 'got the project.author.name' );

main->debug(
    "project: ",
    main->dump_data($project)
) if DEBUG;


#-----------------------------------------------------------------------------
# Nested configuration directory with no master config file
#-----------------------------------------------------------------------------

my $nested = $config->get('nested');
ok( $nested, 'got nested config' );
main->debug(
    "nested: ",
    main->dump_data($nested)
) if DEBUG;

is( $nested->{ one }->{ one_a }, 'One A', 'got nested.one.one_a' );
is( $nested->{ two }->{ three }->{ three_a }, 'Three A', 'got nested.two.three.three_a' );

my $widgets = $config->get('widgets');
ok( $widgets, 'got widgets config' );
main->debug(
    "widgets: ",
    main->dump_data($widgets)
) if DEBUG;

is( $widgets->{ foo }->{ name }, 'The foo widget', 'got the foo widget' );
is( $widgets->{ bar }->{ name }, 'The bar widget', 'got the bar widget' );

# The _scheme_.tree_type in widgets.yaml says that bam and mam should also
# be in $widgets
is( $widgets->{ bam }->{ name }, 'Bam Extra Widget', 'got the bam widget' );
is( $widgets->{ mam }->{ name }, 'Mam Extra Widget', 'got the mam widget' );

is( $widgets->{ flip }->{ name }, 'Flip', 'got the flip widget name' );
is( $config->get('widgets.flop.name'), 'Flop', 'got the flop widget name' );

#-----------------------------------------------------------------------------
# A URI tree where files in directories under the top level directories get 
# appropriate URIs, e.g. a 'baz' entry in 'foo/bar.yaml' becomes 'foo/bar/baz'
# in the master config hash.
#-----------------------------------------------------------------------------

my $nibbles = $config->get('nibbles');
main->debug(
    "nibbles: ",
    main->dump_data($nibbles)
) if DEBUG;

is( 
    $nibbles->{ crackers }, 
    'to go with cheese', 
    'got crackers from nibbles' 
);
is( 
    $config->get('nibbles.pickled_eggs'), 
    'a bit of variety', 
    'nibbles.picked_eggs' 
);

# "tree_type: uri" in _schema_ forces items in cheeses.yaml to appear
# as cheese/xxx

is( 
    $nibbles->{"cheese/cheddar"}, 
    'very tangy', 
    'cheese/cheddar' 
);

# As above, our selection of beers should be in drinks/beers

is( 
    $nibbles->{"drinks/beers/ales"}->[0], 
    'Tangle Foot', 
    'a lovely beer' 
);

# /cheese_knife is forced up a level to the root data hash and the 
# "uri_paths: relative" option removes the leading slash

is( 
    $nibbles->{ cheese_knife }, 
    'for cutting cheese', 
    'cheese_knife' 
);

# /bottle_opener is forced up two levels to the root data hash from drinks/beer
# As above, the "uri_paths: relative" option removes the leading slash

is( 
    $nibbles->{ bottle_opener }, 
    'to open beer', 
    'bottle_opener' 
);

#-----------------------------------------------------------------------------
# Join binder.  Like the URI binder, this squashes nested data harvested
# from files, sub-directories and so on, into the main hash of configuration
# data, using underscores (by default) instead of slashes
#-----------------------------------------------------------------------------

my $ents = $config->get('ents');
main->debug(
    "entertainments: ",
    main->dump_data($ents)
) if DEBUG;

is( 
    $ents->{ misc_I }, 
    'see', 
    'I see', 
);
is( 
    $ents->{ misc_trees }, 
    'of green', 
    'trees of green', 
);
is( 
    $ents->{ four_ten_volume }, 
    'This goes up to eleven', 
    'the volume goes up to eleven', 
);
is( 
    $ents->{ four_twenty_music }, 
    'Pink Floyd', 
    'four twenty music is Pink Floyd', 
);

#-----------------------------------------------------------------------------
# Another join binder but this time with a custom joint of '.'
#-----------------------------------------------------------------------------

my $urls = $config->get('urls');
main->debug(
    "urls: ",
    main->dump_data($urls)
) if DEBUG;


#-----------------------------------------------------------------------------
# This also makes it useful for checking that we can defeat the default 
# behaviour of get() to split dotted items.
#-----------------------------------------------------------------------------

is( 
    $urls->{ home }, 
    '/index.html', 
    'urls.home', 
);

is( 
    $urls->{'foo.about'}, 
    '/about_us.html', 
    'urls.foo.about', 
);

is( 
    $config->get(['urls', 'foo.about']), 
    '/about_us.html', 
    "get(['urls', 'foo.about'])", 
);

is( 
    $config->get(['urls', 'foo.user', 'login']), 
    '/auth/login', 
    "get(['urls', 'foo.user', 'login'])", 
);

is( 
    $urls->{'foo.user'}->{'logout'}, 
    '/auth/logout', 
    'urls.foo.user.logout', 
);
