#============================================================= -*-perl-*-
#
# t/class/alias.t
#
# Test the Badger::Class 'alias' import hook.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( t/class/lib ../t/class/lib ./lib ../lib ../../lib );
use Badger::Test
    tests => 3,
    debug => 'Badger::Class',
    args  => \@ARGV;

use My::Aliased;

my $aliased = My::Aliased->new;
ok( $aliased, 'Created object with aliases' );
is( $aliased->init_msg, 'Hello World!', 'init method is aliased to init_this' );
is( $aliased->foo, 'this is bar', 'foo method is aliased to bar' );

