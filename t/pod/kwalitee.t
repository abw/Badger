#============================================================= -*-perl-*-
#
# t/pod/quality.t
#
# Use Test::Pod (if available) to validate the POD documentation.
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
    if_env => 'RELEASE_TESTING AUTOMATED_TESTING';

eval "use Test::Pod 1.00";
skip_all "Test::Pod 1.00 required for testing POD" if $@;
all_pod_files_ok();

