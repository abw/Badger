#============================================================= -*-perl-*-
#
# t/misc/badger.t
#
# Test the front-end Badger module.
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
use Badger::Test
    tests => 4,
    debug => 'Badger',
    args  => \@ARGV;

use Badger
    Utils      => 'looks_like_number',
    Constants  => 'ARRAY HASH',
    Filesystem => 'FS',
    Codecs     => [codec => 'base64'];

ok(1, 'loaded Badger module');
ok( looks_like_number(23), 'looks_like_number imported from Badger::Utils' );
is( ref [ ], ARRAY, 'ARRAY imported from Badger::Constants' );

my $badger = Badger->new;
ok( $badger, 'created Badger object' );
