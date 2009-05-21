#============================================================= -*-perl-*-
#
# t/misc/moose.t
#
# Tests to show Badger plays nicely with Moose.
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
    debug => 'Badger',
    args  => \@ARGV;

BEGIN {
    eval "use Moose ()";
    skip_all("You don't have Moose installed, shame on you!") if $@;
    plan(6);
}

package Badger::Test::Moose::One;
use Moose;
use Badger::Class
    version   => 1.23,
    debug     => 0,
    accessors => 'bar',
    mutators  => 'baz',
    import    => 'class',
    words     => 'HELLO WORLD';

extends 'Badger::Base';
has foo => (is => 'rw');
our $BAZ = 3.14;

sub init {
    my ($self, $config) = @_;
    for (qw( foo bar baz )) {
        $self->{ $_ } = $config->{ $_ }
            || $self->class->any_var(uc $_);
    }
    return $self;
}
    
package main;

my $one = Badger::Test::Moose::One->new( foo => 10, bar => 20 );
ok( $one, 'created first object' );
is( $one->foo, 10, 'foo is 10' );
is( $one->bar, 20, 'bar is 10' );
is( $one->baz, 3.14, 'baz is 3.14' );
is( $one->baz(30), 30, 'set baz to 30' );
is( $one->baz, 30, 'baz is 30' );
