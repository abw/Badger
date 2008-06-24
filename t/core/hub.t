#============================================================= -*-perl-*-
#
# t/core/hub.t
#
# Test the Badger::Hub.pm module.  Run with -d option for debugging.
#
# Copyright (C) 2006 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;

use lib qw( core/lib t/core/lib ./lib ../lib ../../lib );
use Badger::Hub;
use Test::More tests => 6;

$Badger::Hub::DEBUG = grep(/^-d$/, @ARGV);

my $pkg = 'Badger::Hub';

#------------------------------------------------------------------------
# test class methods
#------------------------------------------------------------------------

my $p1 = $pkg->prototype();
my $p2 = $pkg->prototype();
is( $p1, $p2, 'Hub prototype is a singleton' );
is( $p1, $Badger::Hub::PROTOTYPE, 'Hub prototype is cache in package' );

$pkg->destroy();

ok( ! defined $Badger::Hub::PROTOTYPE, 'Hub prototype destroyed' );


#-----------------------------------------------------------------------
# check we get methods failing
#-----------------------------------------------------------------------

eval { $pkg->nothing };
like( $@, qr/Invalid method 'nothing'/, 'invalid method' );


#-----------------------------------------------------------------------
# subclass to define some components
#-----------------------------------------------------------------------

package My::Hub;
use base 'Badger::Hub';

our $COMPONENTS = {
    widget => 'My::Widget',
};

package main;
my $hub = My::Hub->new;
my $widget = $hub->widget;
ok( $widget, 'got widget' );
is( ref $widget, 'My::Widget', 'got My::Widget' );



__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
