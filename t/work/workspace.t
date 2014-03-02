#============================================================= -*-perl-*-
#
# t/work/workspace.t
#
# Test the Badger::Workspace module.
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
    tests => 10,
    debug => 'Badger::Workspace',
    args  => \@ARGV;

use Badger::Debug ':all';
use Badger::Workspace;
use constant WORKSPACE => 'Badger::Workspace';

my $workspace = WORKSPACE->new(
    root => Bin->dir( test_files => 'workspace1' ),
);

ok( $workspace, 'created workspace' );
is( $workspace->config('example.foo'), 'The Foo Item', 'got example.foo from config' );
is( $workspace->config('example.bar'), 'The Bar Item', 'got example.bar from config' );
is( $workspace->config('name'), 'Test Workspace', 'got workspace name from config' );

my $goodbye = $workspace->file('goodbye.txt');
ok( $goodbye, 'got goodbye.txt file' );
ok( $goodbye->exists, 'goodbye.txt file exists' );

my $txt = $goodbye->text;
chomp $txt;
is( $txt, 'Goodbye World!', 'got file text' );

my $greetings = $workspace->config('greetings');
ok( $greetings, 'got greetings config' );
is( $greetings->{ hello }, 'Hello World!', 'got hello greeting' );
is( $workspace->config('greetings.hello'), 'Hello World!', 'got greetings.hello' );
