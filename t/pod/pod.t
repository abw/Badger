#============================================================= -*-perl-*-
#
# t/pod/pod.t
#
# Test the Badger::Pod module.
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
use Badger::Pod 'Pod POD';
use Badger::Filesystem 'FS';
use Badger::Debug ':dump';
use Badger::Test
    tests => 10,
    debug => 'Badger::Pod Badger::Pod::Document',
    args  => \@ARGV;
    
my $tfd  = 'testfiles';
my $dir  = -d 't' ? FS->dir('t', 'pod', $tfd) : FS->dir($tfd);
my ($pod, $text, $file);


#-----------------------------------------------------------------------
# basic test of the POD constant and Pod constructor function
#-----------------------------------------------------------------------

$pod = POD->document( text => '=head1 Hello World' );
ok( $pod, 'created POD document from text' );
is( $pod->text, '=head1 Hello World', 'got hello world text back' );

$pod = Pod( text => '=head1 Hello Badger' );
ok( $pod, 'created Pod document from text' );
is( $pod->text, '=head1 Hello Badger', 'got hello badger text back' );

$pod = Pod( text => \'=head1 Hello Monkey' );
ok( $pod, 'created Pod document from text reference' );
is( $pod->text, '=head1 Hello Monkey', 'got hello monkey text back' );


#-----------------------------------------------------------------------
# test it works with files
#-----------------------------------------------------------------------

# file path
$pod = Pod( file => $dir->file('blocks_lf.pod')->path );
ok( $pod, 'created Pod document from file path' );
like( $pod->text, qr/^This is not Pod.*?This is Pod/s, 'got file path text' );

# file object
$pod = Pod( file => $dir->file('blocks_lf.pod') );
ok( $pod, 'created Pod document from file object' );
like( $pod->text, qr/^This is not Pod.*?This is Pod/s, 'got file object text' );


