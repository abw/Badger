#============================================================= -*-perl-*-
#
# t/app/app.t
#
# Test the Badger::App module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ./lib ../lib ../../lib );
use Badger::Test 
    tests => 2,
    debug => 'Badger::App',
    args  => \@ARGV;

use Badger::App;
use constant APP => 'Badger::App';

pass( 'Loaded ' . APP );

my $app = APP->new;
ok( $app, 'created an app object' );

