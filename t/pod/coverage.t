#============================================================= -*-perl-*-
#
# t/pod/coverage.t
#
# Use Test::Pod::Coverage (if available) to test the coverage of the 
# POD documentation.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2008-2009 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ./lib ../lib ../../lib );
use Badger::Test 
    args   => \@ARGV,
#   if_env => 'RELEASE_TESTING AUTOMATED_TESTING'
    if_env => 'RELEASE_TESTING';                    # 

eval "use Test::Pod::Coverage 1.00";
skip_all "Test::Pod::Coverage 1.00 required for testing POD coverage" if $@;

all_pod_coverage_ok({
    trustme => [ qr/init/, qr/export/, qr/^EXPORT_/, 
                 qr/HOOKS/, qr/ISA/, qr/^TMP_/, qr/^OLD_/],
});
