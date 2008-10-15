#============================================================= -*-perl-*-
#
# t/class/methods.t
#
# Test the Badger::Class::Methods module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( t/core/lib ../t/core/lib ./lib ../lib ../../lib );
use Badger::Test
    tests => 38,
    debug => 'Badger::Class::Methods',
    args  => \@ARGV;


#-----------------------------------------------------------------------
# test using Badger::Class::Methods directly
#-----------------------------------------------------------------------

package Badger::Test::Methods1;

use Badger::Class::Methods
    accessors => 'foo bar',
    mutators  => 'flic flac',
    get       => 'a',           # short aliases for above
    set       => 'b';

package main;

my $obj = bless { 
    foo  => 10, 
    bar  => 20, 
    flic => 30,
    a    => 31,
    b    => 32,
}, 'Badger::Test::Methods1';

is( $obj->foo, 10, 'foo accessor' );
is( $obj->bar, 20, 'bar accessor' );
is( $obj->bar(100), 20, 'bar accessor with arg' );
is( $obj->bar, 20, 'bar unchanged accessor' );
is( $obj->flic, 30, 'flic mutator' );
is( $obj->flic(40), 40, 'flic mutator with arg' );
is( $obj->flic, 40, 'flic updated' );
is( $obj->flac(50), 50, 'flac set' );
is( $obj->flac, 50, 'flac get' );
is( $obj->a, 31, 'a get' );
is( $obj->a(33), 31, 'a set' );
is( $obj->a, 31, 'a get again' );
is( $obj->b, 32, 'b get' );
is( $obj->b(33), 33, 'b set' );
is( $obj->b, 33, 'b get again' );


#-----------------------------------------------------------------------
# test using Badger::Class via delegation
#-----------------------------------------------------------------------

package Badger::Test::Methods2;

use Badger::Class
    accessors => 'wiz waz',
    mutators  => 'ding dong',
    get_methods => 'x',
    set_methods => 'y';

package main;

$obj = bless { 
    wiz  => 50, 
    waz  => 60, 
    ding => 70,
    x    => 101,
    y    => 202,
}, 'Badger::Test::Methods2';

is( $obj->wiz, '50', 'wiz accessor' );
is( $obj->waz, '60', 'waz accessor' );
is( $obj->waz(100), '60', 'waz accessor with arg' );
is( $obj->waz, '60', 'waz unchanged accessor' );
is( $obj->ding, '70', 'ding mutator' );
is( $obj->ding(80), '80', 'ding mutator with arg' );
is( $obj->ding, '80', 'ding updated' );
is( $obj->dong(90), '90', 'dong set' );
is( $obj->dong, '90', 'dong get' );
is( $obj->x, 101, 'x get' );
is( $obj->x(102), 101, 'x set' );
is( $obj->x, 101, 'x get again' );
is( $obj->y, 202, 'y get' );
is( $obj->y(203), 203, 'y set' );
is( $obj->y, 203, 'y get again' );


#-----------------------------------------------------------------------
# test generation of slot methods for list based objects
#-----------------------------------------------------------------------

package Badger::Test::Slots1;

use Badger::Class::Methods
    slots => 'size colour object';

sub new {
    my ($class, @stuff) = @_;
    bless \@stuff, $class;
}

package main;
my $bus = Badger::Test::Slots1->new(qw(big red bus));
ok( $bus, 'Created slot test object' );
is( $bus->size,   'big', 'big slot' );
is( $bus->colour, 'red', 'red slot' );
is( $bus->object, 'bus', 'bus slot' );


#-----------------------------------------------------------------------
# and again via Badger::Class
#-----------------------------------------------------------------------

package Badger::Test::Slots2;

use Badger::Class
    slots => 'subject, predicate, object';

sub new {
    my ($class, @stuff) = @_;
    bless \@stuff, $class;
}

package main;
my $sentence = Badger::Test::Slots2->new('the cat', 'sat on', 'the mat');
ok( $sentence, 'Created slot test object' );
is( $sentence->subject,   'the cat', 'subject slot' );
is( $sentence->predicate, 'sat on',  'predicate slot' );
is( $sentence->object,    'the mat', 'object slot' );




__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
