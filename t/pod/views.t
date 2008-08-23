#============================================================= -*-perl-*-
#
# t/pod/views.t
#
# Test the Badger::Pod::Views factory module.
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
use Badger::Pod 'Views';
use Badger::Test
    tests => 5,
    debug => 'Badger::Pod::Views Badger::Factory',
    args  => \@ARGV;
    
my $views = Views;

ok( $views, 'got views class' );
ok( $views->can('view'),  'viewss can do view()' );
ok( $views->can('views'), 'viewss can do views()' );

my $html = $views->view('HTML');
ok( $html, 'got view' );
is( ref $html, 'Badger::Pod::View::HTML', 'got HTML view' );

