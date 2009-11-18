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
    tests => 55,
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
    set       => 'b',
    hash      => 'users';

package main;

my $obj = bless { 
    foo   => 10, 
    bar   => 20, 
    flic  => 30,
    a     => 31,
    b     => 32,
    users => {
        tom => 'tom@example.com',
    },
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
is( $obj->users->{ tom }, 'tom@example.com', 'got users hash' );
is( $obj->users('tom'), 'tom@example.com', 'got users item' );

# add users via hash ref
$obj->users({ dick => 'richard@example.com' });
is( $obj->users('dick'), 'richard@example.com', 'dick added to users' );
is( $obj->users('tom'), 'tom@example.com', 'tom is still in users' );

# add users via named params
$obj->users( harry => 'harold@example.com' );
is( $obj->users('harry'), 'harold@example.com', 'harold added to users' );
is( $obj->users('dick'), 'richard@example.com', 'richard is still in users' );


#-----------------------------------------------------------------------
# test using Badger::Class via delegation
#-----------------------------------------------------------------------

package Badger::Test::Methods2;

use Badger::Class
    base        => 'Badger::Base',
    accessors   => 'wiz waz',
    mutators    => 'ding dong',
    get_methods => 'x',
    set_methods => 'y',
    init_method => 'configure',
    config      => 'x y wiz waz ding';

package main;

$obj = Badger::Test::Methods2->new(
    wiz  => 50, 
    waz  => 60, 
    ding => 70,
    x    => 101,
    y    => 202,
);

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


#-----------------------------------------------------------------------
# we should be able to create accessor/mutator code refs directly
#-----------------------------------------------------------------------

my $dummy = { pi => 3.14 };

my $access = Badger::Class::Methods->accessor('pi');
ok( $access, 'created accessor method' );
is( $access->($dummy), 3.14, 'accessor works' );

my $mutate = Badger::Class::Methods->mutator('pi');
ok( $mutate, 'created mutator method' );
is( $mutate->($dummy, 3.14159), 3.14159, 'mutator works' );
is( $access->($dummy), 3.14159, 'value updated' );



#-----------------------------------------------------------------------
# test the auto_can() method
#-----------------------------------------------------------------------

package Badger::Test::Autocan;

use Badger::Class
    base        => 'Badger::Base',
    auto_can    => 'test_method',
    accessors   => 'x y',
    config      => 'x=10 y=20',
    init_method => 'configure';

sub test_method {
    my ($self, $name) = @_;
    
    if ($name =~ /^test_/) {
        return sub {
            my $this = shift;
            return "You called $name(" . join(', ', @_) . ')';
        }
    }
}

package main;

use constant AUTOCAN => 'Badger::Test::Autocan';

my $xy = AUTOCAN->new;
ok( $xy, 'created auto_can object' );
is( $xy->x, 10, 'x is 10' );
is( $xy->y, 20, 'y is 20' );
is( $xy->test_foo(30), 'You called test_foo(30)', 'called test_foo()' );
ok( ! $xy->try->bad_foo(30), 'failed to call bad_foo()' );
like( $xy->reason->info, "Invalid method 'bad_foo' called on Badger::Test::Autocan", 'got error message' );


__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
