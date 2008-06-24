#============================================================= -*-perl-*-
#
# t/core/class.t
#
# Test the Badger::Class module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( t/core/lib ../t/core/lib ./lib ../lib ../../lib );
use Badger::Class;
use Test::More tests  => 72;

our $DEBUG= $Badger::Class::DEBUG = grep(/^-d/, @ARGV);


#-----------------------------------------------------------------------
# test simple inheritance
#-----------------------------------------------------------------------

package Alice;
use Badger::Class 
    version => 2.718,
    import  => qw( class classes );

main::is( $VERSION, 2.718, 'Alice defines $VERSION as 2.718' );
our $NAME = 'Alice';
our $GIRLS_NAME = 'Alice';
our $ALIASES = ['Ally', 'Ali'];
our $FRIENDS = {
    sue => 'Susan',
};

sub new {
    my ($class, %self) = @_;
    bless \%self, $class;
}

package Bob;
use Badger::Class
    base    => 'Alice',
    version => 3.142;

our $NAME = 'Bob';
our $BOYS_NAME = 'Bob';
our $ALIASES = ['Robert', 'Rob'];
our $FRIENDS = {
    jim => 'Jim',
};

package main;

# base methods
my $alice = Alice->new();
ok( $alice, 'Alice is alive' );
is( $alice->class, 'Alice', "Alice's class is Alice" );
is( $alice->version, 2.718, "Alice's version is 2.718" );
is( $Alice::VERSION, 2.718, "Alice's VERSION is 2.718" );

# derived methods
my $bob = Bob->new();
ok( $bob, 'Bob is alive' );
is( $bob->class, 'Bob', "Bob's class is Bob" );
is( $bob->class->parents->[0], 'Alice', "Bob's parent is Alice" );
is( join(', ', $bob->class->heritage), 'Bob, Alice', "Bob's heritage is Bob, Alice" );
is( join(', ', $bob->classes), 'Bob, Alice', "Bob's classes are Bob, Alice" );
is( $bob->version, 3.142, "Bob has version of 3.142" );

# base vars
is( $alice->class->var('NAME'), 'Alice', 'Alice var $NAME' );
is( $alice->class->var('GIRLS_NAME'), 'Alice', 'Alice var $GIRLS_NAME' );

# derived vars
is( $bob->class->var('NAME'), 'Bob', 'Bob var $NAME' );
is( $bob->class->var('BOYS_NAME'), 'Bob', 'Bob var $BOYS_NAME' );

is( join(', ', $alice->class->all_vars('NAME')), 'Alice', 'Alice vars $NAME' );
is( join(', ', $bob->class->all_vars('NAME')), 'Bob, Alice', 'Bob vars $NAME' );

# merged list var
is( join(', ', @{ $alice->class->list_vars('ALIASES') }), 'Ally, Ali', 'Alice ALIASES' );
is( join(', ', @{ $bob->class->list_vars('ALIASES') }), 'Ally, Ali, Robert, Rob', 'Bob ALIASES' );

# merged hash var
my $friends = $alice->class->hash_vars('FRIENDS');
is( join(', ', keys %$friends), 'sue', 'Alice FRIENDS with sue' );
is( join(', ', values %$friends), 'Susan', 'Alice FRIENDS with Susan' );

$friends = $bob->class->hash_vars('FRIENDS');
is( join(', ', sort keys %$friends), 'jim, sue', 'Bob FRIENDS with jim and sue' );
is( join(', ', sort values %$friends), 'Jim, Susan', 'Bob FRIENDS with Jim and Susan' );


#-----------------------------------------------------------------------
# test inheritance via the base() method
#-----------------------------------------------------------------------

package Charlie;
use Badger::Class 
    import  => 'class';

class->base('Alice');

package main;
my $chas = Charlie->new();
ok( $chas, 'Created Charlie' );
is( $chas->version, 2.718, 'Charlie inherits version from Alice' );

package David;
use Badger::Class 'class', base => 'Charlie';
class->version(42);
class->constant( volume => 11 );

package main;
my $dave = David->new();
ok( $dave, 'Created David' );
is( $dave->version, 42, "David's version is at level 42" );
is( $dave->volume, 11, "David's volume goes up to 11" );  # should be Nigel!


#-----------------------------------------------------------------------
# test a crazy inheritance model
#-----------------------------------------------------------------------

package Ten;   use Badger::Class version => 1;
package Nine;  use Badger::Class version => 1;
package Eight; use Badger::Class version => 1, base => 'Nine';
package Seven; use Badger::Class version => 1, base => 'Eight Ten';
package Six;   use Badger::Class version => 1, base => 'Seven';
package Five;  use Badger::Class version => 1, base => 'Eight';
package Four;  use Badger::Class version => 1;
package Three; use Badger::Class version => 1, base => 'Four';
package Two;   use Badger::Class version => 1, base => 'Three Five';
package One;   use Badger::Class version => 1, base => 'Two Six', import => 'classes';

sub new {
    my ($class, %self) = @_;
    bless \%self, $class;
}

package main;

my $one = One->new();
ok( $one, 'Created One object' );
is( join(', ', $one->classes), 
    'One, Two, Three, Four, Five, Six, Seven, Eight, Nine, Ten',
    'Got heritage classes for One' );


#-----------------------------------------------------------------------
# test regular class/classes import
#-----------------------------------------------------------------------

package Frank;
use Badger::Class qw( class classes );

main::is( class, 'Frank', 'class is Frank' );

package main;
ok( 1, 'Created Frank' );
is ( Frank->class, 'Frank', "Frank's class is Frank" );


#-----------------------------------------------------------------------
# test loading constants from T::Constants
#-----------------------------------------------------------------------

package Constantine;
use Badger::Class constants => 'HASH';
*is = \&main::is;
is( HASH, HASH, 'HASH is defined' );


#-----------------------------------------------------------------------
# test constant generation
#-----------------------------------------------------------------------

package Harry;
use Badger::Class 
    base     => 'Alice',
    constant => {
        pi => 3.14,
        e  => 2.718,
    },
    import => 'class';
    
class->constant( phi => 1.618 );

*is = \&main::is;
is( pi, 3.14, 'In Harry, pi is a constant' );
is( e, 2.718, 'In Harry, e is a constant' );
is( phi(), 1.618, 'In Harry, phi is a constant' );

package main;
my $haz = Harry->new;
ok( $haz, 'Created Harry' );
is( $haz->pi, 3.14, "Harry's pi is a constant" );
is( $haz->e, 2.718, "Harry's e is a constant" );
is( $haz->phi, 1.618, "Harry's phi is a constant" );


#-----------------------------------------------------------------------
# test debug option
#-----------------------------------------------------------------------

package Danny;
use Badger::Class
    base    => 'Alice',
    debug   => 0;

main::is( $DEBUG, 0, 'Danny debugging is off' );

package main;
is( Danny->debugging,    0,  'Danny is not debugging' );
is( $Danny::DEBUG,       0,  'Danny $DEBUG is 0' );
is( Danny->debugging(1), 1,  'Danny is now debugging' );
is( $Danny::DEBUG,       1,  'Danny $DEBUG is 1' );
is( Danny->debugging,    1,  'Danny is still debugging' );


#-----------------------------------------------------------------------
# debug => $n should not overwrite an existing $DEBUG value;
#-----------------------------------------------------------------------

package Donny;
use Badger::Class
    base    => 'Alice',
    debug   => 0;

main::is( $DEBUG, 0, 'Donny debugging is off' );

package main;
is( Donny->debugging(1), 1, 'Donny is now debugging' );
is( Donny->debugging,    1, 'Donny is debugging' );
is( $Donny::DEBUG,       1, 'Donny $DEBUG is 1' );
is( Donny->debugging(0), 0, 'Donny is not debugging' );
is( $Donny::DEBUG,       0, 'Donny $DEBUG is 0' );
is( Donny->debugging,    0, 'Donny is still not debugging' );


#-----------------------------------------------------------------------
# test throws option
#-----------------------------------------------------------------------

package Chucker;
use Badger::Class
    base    => 'Alice Badger::Base',
    debug   => 0,
    throws  => 'food';

package main;
is( Chucker->throws,       'food',  'Chucker throws food' );
is( $Chucker::THROWS,      'food',  "It's very bad behaviour" );
is( Chucker->throws('egg'), 'egg',  'Chucky Egg' );
is( $Chucker::THROWS,       'egg',  'Now that was a great game' );
is( Chucker->throws,        'egg',  'So was Manic Miner' );

#-----------------------------------------------------------------------
# test messages option
#-----------------------------------------------------------------------

package Nigel;
use Badger::Class
    base     => 'Alice Badger::Base',
    debug    => 0,
    import   => 'class',
    messages => {
        one_louder  => "Well, it's %s louder",
        do_you_wear => "Do you wear %0?",
    };

class->messages( goes_up_to => 'This %0 goes up to %1' );

package main;
my $nigel = Nigel->new;
is( $nigel->message( one_louder => 'one' ), 
    "Well, it's one louder", "It's One louder"
);
is( $nigel->message( goes_up_to => amp => 'eleven' ), 
    "This amp goes up to eleven", 'Goes up to eleven' 
);


#-----------------------------------------------------------------------
# test classes get autoloaded
#-----------------------------------------------------------------------

use Class::Top;
my $top = Class::Top->new;
my $mid = Class::Middle->new;
my $bot = Class::Bottom->new;

if ($DEBUG) {
    print "HERITAGE: ", join(', ', $top->class->heritage), "\n";
    print "Top ISA: ", join(', ', @Class::Top::ISA), "\n";
    print "Middle ISA: ", join(', ', @Class::Middle::ISA), "\n";
    print "Bottom ISA: ", join(', ', @Class::Bottom::ISA), "\n";
}

is( $bot->bottom, 'on the bottom', 'bot is on the bottom' );
is( $mid->bottom, 'on the bottom', 'mid is on the bottom' );
is( $top->bottom, 'on the bottom', 'top is on the bottom' );
is( $mid->middle, 'in the middle', 'mid is in the middle' );
is( $top->middle, 'in the middle', 'top is in the middle' );
is( $top->top, 'on the top', 'op on the top' );

is( $bot->id, 'class.bottom', 'bot id' );
is( $mid->id, 'class.middle', 'mid id' );
is( $top->id, 'class.top', 'top id' );

#-----------------------------------------------------------------------
# test codec/codecs
#-----------------------------------------------------------------------

package Test::Codec1;
use Test::More;
use Badger::Class codec => 'base64';

my $enc = encode('Hello World');
is( $enc, "SGVsbG8gV29ybGQ=\n", 'encoded base64' );

my $dec = decode($enc);
is( $dec, 'Hello World', 'decoded base64' );

__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
