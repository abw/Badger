#============================================================= -*-perl-*-
#
# t/docs/docs.t
#
# Test the Badger::Docs module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2008 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Filesystem 'FS';
use Badger::Debug ':dump';
use Badger::Docs;
use Badger::Test
    tests => 3,
    debug => 'Badger::Docs Badger::Base',
    args  => \@ARGV;
    
my $dir = -d 't' ? FS->dir('t', 'docs') : FS->dir;
my $lib = $dir->parent(1)->dir('lib')->must_exist;
ok( $lib, "got library directory: $lib" );

my $docs = Badger::Docs->new( 
    root     => $lib, 
    uri_base => '/docs',
    verbose  => $DEBUG,
    dry_run  => 1,
);
ok( $docs, 'created Badger::Docs object' );

my $visitor = $docs->visit;
ok( $visitor, 'visited documentation tree' );

exit() unless $DEBUG;
print "\n\nINDEX:\n", main->dump_data($visitor->index);
#print main->dump_data($visitor->sections), "\n\n";
print "\n\nCONTENT:\n", main->dump_data($visitor->content);

#print $visitor->dump($pages);

#use Data::Dumper;
#print Dumper($pages);



#my @files = $docs->collect;
#ok( scalar @files > 20, 'got > 20 files in docs' );
#print "files:\n  - ", join("\n  - ", @files), "\n";
#$docs->compose;
