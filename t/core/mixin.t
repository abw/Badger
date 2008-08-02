#============================================================= -*-perl-*-
#
# t/mixin.t
#
# Test the Badger::Mixin module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;

use lib qw( t/core/lib ../t/core/lib ./lib ../lib ../../lib );
use Badger::Mixin;
use Badger::Mixins;
use Badger::Test 
    tests  => 7, 
    debug  => 'Badger::Mixin Badger::Mixins',
    args   => \@ARGV;


#-----------------------------------------------------------------------
# define a class that mixes in another
#-----------------------------------------------------------------------

package Foo;

use Badger::Class
    base  => 'Badger::Base',
    mixin => 'My::Mixin::Foo';

package main;

is( Foo->wam, 'Wam!', 'wam' );
is( Foo->bam, 'Bam!', 'bam' );


#-----------------------------------------------------------------------
# now try with a Bar mixin that mixes in Badger::Mixin::Messages
#-----------------------------------------------------------------------

package Bar;

use Badger::Class
    base  => 'Badger::Base',
    mixin => 'My::Mixin::Bar';

package main;

is( Bar->message( hello => 'World' ), 'Hello World!', 'Hello World!' );


#-----------------------------------------------------------------------
# load module that mixes in other modules
#-----------------------------------------------------------------------

package Baz;

use Badger::Class
    base  => 'Badger::Base',
    mixin => 'My::Mixin::Baz';

package main;

is( Baz->wam, 'Wam!', 'wam' );
is( Baz->bam, 'Bam!', 'bam' );
is( Baz->message( hello => 'World' ), 'Hello World!', 'Hello World!' );
is( Baz->plop, 'Plop!', 'plop' );


__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
