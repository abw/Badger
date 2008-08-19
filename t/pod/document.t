#============================================================= -*-perl-*-
#
# t/pod/document.t
#
# Badger::Pod::Document tests.
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
use Badger::Pod 'Document';
use Badger::Test
    tests => 5,
    debug => 'Badger::Pod::Document Badger::Pod::Blocks Badger::Pod::Model',
    args  => \@ARGV;
    
my $doc = Document( text => <<EOF );
This is some code

=head1 This is a test document

This is some POD markup

=cut

More code here

=pod

More POD here.
EOF

ok( $doc, 'created Pod document' );


#-----------------------------------------------------------------------
# get Badger::Pod::Blocks
#-----------------------------------------------------------------------

my $blocks = $doc->blocks;
ok( $blocks, 'got document blocks' );
is( ref $blocks, 'Badger::Pod::Blocks', 'isa Badger::Pod::Blocks' );


#-----------------------------------------------------------------------
# get Badger::Pod::Model
#-----------------------------------------------------------------------

my $model = $doc->model;
ok( $model, 'got document model' );
is( ref $model, 'Badger::Pod::Model', 'isa Badger::Pod::Model' );
