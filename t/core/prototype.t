#============================================================= -*-perl-*-
#
# t/core/prototype.t
#
# Test the Badger::Prototype module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;

use lib qw( ./lib ../lib ../../lib );
use Badger::Test 
    tests => 17,
    debug => 'Badger::Prototype',
    args  => \@ARGV;


#------------------------------------------------------------------------
# define a subclass
#------------------------------------------------------------------------

package Badger::Example::One;
use base 'Badger::Prototype';

sub init { 
    my ($self, $config) = @_;
    $self->{ name } = $config->{ name } || 'anonymous';
    return $self;
}

sub name {
    my $self = shift;
    $self = $self->prototype() unless ref $self;
  
    if (@_) {
        return ($self->{ name } = shift);
    }
    else {
        return $self->{ name };
    }
}

# try out a slightly more compact idiom 
sub alias {
    my $self = ref $_[0] ? shift : shift->prototype();
    return $self->{ name };
}

# and another
sub pseudonym {
    shift->prototype->{ name };
}


#------------------------------------------------------------------------
# test name() class method
#------------------------------------------------------------------------

package main;
my $pkg = 'Badger::Example::One';

is( $pkg->name(), 'anonymous', 'class name() is anonymous' );


#------------------------------------------------------------------------
# test prototype() method returns same ref each time
#------------------------------------------------------------------------

my $p1 = $pkg->prototype();
my $p2 = $pkg->prototype();

is( $p1, $p2, 'prototype references are same' );
is( $p1->name(), 'anonymous', 'proto1 name is anonymous' );
is( $p2->name(), 'anonymous', 'proto2 name is anonymous' );

is( $p1->name('Larry'), 'Larry', 'set proto1 name to Larry' );
is( $p1->alias(), 'Larry', 'proto1 alias is Larry' );
is( $p1->pseudonym(), 'Larry', 'proto1 pseudonym is Larry' );

is( $p2->name(), 'Larry', 'proto2 name is Larry' );
is( $p2->alias(), 'Larry', 'proto2 alias is Larry' );
is( $p2->pseudonym(), 'Larry', 'proto2 pseudonym is Larry' );

is( $pkg->name(), 'Larry', 'proto2 pkg name is Larry' );
is( $pkg->alias(), 'Larry', 'proto2 pkg alias is Larry' );
is( $pkg->pseudonym(), 'Larry', 'proto2 pkg pseudonym is Larry' );


#------------------------------------------------------------------------
# test calling prototype() with args creates new prototype
#------------------------------------------------------------------------

my $p3 = $pkg->prototype( name => 'Damian' );
is( $p3->name(), 'Damian', 'proto3 name is Damian' );
is( $p2->name(), 'Larry', 'proto2 name is still Larry' );
isnt( $p2, $p3, 'Larry is not Damian' );


#------------------------------------------------------------------------
# test prototype() as object method
#------------------------------------------------------------------------

my $p4 = $p3->prototype();
is( $p4, $p3, 'object prototype method returns $self' );



__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

