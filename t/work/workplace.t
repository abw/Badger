#============================================================= -*-perl-*-
#
# t/work/workplace.t
#
# Test the Badger::Workplace module.
#
# Copyright (C) 2008-2014 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib => ' ../../lib',
    Utils => 'Bin';


use Badger::Test 
    tests => 7,
    debug => 'Badger::Workplace',
    args  => \@ARGV;

use Badger::Debug ':all';
use Badger::Workplace;
use constant WORKPLACE => 'Badger::Workplace';


my $workplace = WORKPLACE->new(
    root => Bin->dir( test_files => 'workplace1' ),
);

ok( $workplace, 'created workplace' );
is( $workplace->urn, 'workplace1', 'workplace URN is workplace1' );
is( $workplace->uri, 'workplace1', 'workplace URI is workplace1' );
is( $workplace->uri('foo'), 'workplace1/foo', 'resolved uri' );


my $hello = $workplace->file('hello.txt');

ok( $hello, 'got hello.txt file' );
ok( $hello->exists, 'hello.txt file exists' );

my $txt = $hello->text;
chomp $txt;
is( $txt, 'Hello World!', 'got file text' );

