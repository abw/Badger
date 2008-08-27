#============================================================= -*-perl-*-
#
# t/pod/quantity.t
#
# Use Test::Pod::Coverage (if available) to test the coverage of the 
# POD documentation.
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
use lib qw( ./lib ../lib ../../lib ./blib/lib ../../blib/lib );
use Test::More;
eval "use Test::Pod::Coverage 1.00";
plan skip_all => "Test::Pod::Coverage 1.00 required for testing POD coverage" if $@;

all_pod_coverage_ok({
    trustme => [qr/init/, qr/export/, qr/^EXPORT_/, qr/HOOKS/, qr/ISA/],
});
