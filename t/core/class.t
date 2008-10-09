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
use Badger::Test
    tests => 137,
    debug => 'Badger::Class Badger::Defaults',
    debug => 'Badger::Defaults',
    args  => \@ARGV;


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
our $TWO = '22 Acacia Avenue';

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
our $ONE = '2 Minutes to Midnight';

package main;

# base methods
my $alice = Alice->new();
ok( $alice, 'Alice is alive' );
is( $alice->class, 'Alice', "Alice's class is Alice" );
is( $alice->VERSION, 2.718, "Alice's version is 2.718" );
is( $Alice::VERSION, 2.718, "Alice's VERSION is 2.718" );

# derived methods
my $bob = Bob->new();
ok( $bob, 'Bob is alive' );
is( $bob->class, 'Bob', "Bob's class is Bob" );
is( $bob->class->parents->[0], 'Alice', "Bob's parent is Alice" );
is( join(', ', $bob->class->heritage), 'Bob, Alice', "Bob's heritage is Bob, Alice" );
is( join(', ', $bob->classes), 'Bob, Alice', "Bob's classes are Bob, Alice" );
is( $bob->VERSION, 3.142, "Bob has version of 3.142" );

# base vars
is( $alice->class->var('NAME'), 'Alice', 'Alice var $NAME' );
is( $alice->class->var('GIRLS_NAME'), 'Alice', 'Alice var $GIRLS_NAME' );

# derived vars
is( $bob->class->var('NAME'), 'Bob', 'Bob var $NAME' );
is( $bob->class->var('BOYS_NAME'), 'Bob', 'Bob var $BOYS_NAME' );

is( join(', ', $alice->class->any_var('NAME')), 'Alice', 'Alice any_var $NAME' );
is( join(', ', $bob->class->any_var('NAME')), 'Bob', 'Bob any_var $NAME' );

is( join(', ', $alice->class->any_var_in('ONE', 'TWO')), '22 Acacia Avenue', 'Alice is Charlotte' );
is( join(', ', $alice->class->any_var_in('ONE TWO')), '22 Acacia Avenue', 'She lives at 22 Acacia Avenue' );
is( join(', ', $alice->class->any_var_in(['ONE', 'TWO'])), '22 Acacia Avenue', "That's the place where we all go" );
is( join(', ', $bob->class->any_var_in('ONE', 'TWO')), '2 Minutes to Midnight', "Bob says it's 2 minutes to midnight" );
is( join(', ', $bob->class->any_var_in('ONE TWO')), '2 Minutes to Midnight', "The hand that threatens doom" );
is( join(', ', $bob->class->any_var_in(['ONE', 'TWO'])), '2 Minutes to Midnight', "Kill the unborn in the womb" );

is( join(', ', $alice->class->all_vars('NAME')), 'Alice', 'Alice all_vars $NAME' );
is( join(', ', $bob->class->all_vars('NAME')), 'Bob, Alice', 'Bob all_vars $NAME' );

# merged list var
is( join(', ', @{ $alice->class->list_vars('ALIASES') }), 'Ally, Ali', 'Alice ALIASES' );
is( join(', ', @{ $bob->class->list_vars('ALIASES') }), 'Robert, Rob, Ally, Ali', 'Bob ALIASES' );

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
is( $chas->VERSION, 2.718, 'Charlie inherits version from Alice' );

package David;
use Badger::Class 'class', base => 'Charlie';
class->version(42);
class->constant( volume => 11 );

package main;
my $dave = David->new();
ok( $dave, 'Created David' );
is( $dave->VERSION, 42, "David's version is at level 42" );
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

my $test = $THROWS;    # should be defined

package main;

is( $Chucker::THROWS,      'food',  "Initially food" );
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

class->messages( goes_up_to => 'This <1> goes up to <2>' );

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

is( $bot->class->id, 'class.bottom', 'bot id' );
is( $mid->class->id, 'class.middle', 'mid id' );
is( $top->class->id, 'class.top', 'top id' );

#-----------------------------------------------------------------------
# test codec/codecs
#-----------------------------------------------------------------------

package Test::Codec1;
use Badger::Test;
use Badger::Class codec => 'base64';

my $enc = encode('Hello World');
is( $enc, "SGVsbG8gV29ybGQ=\n", 'encoded base64' );

my $dec = decode($enc);
is( $dec, 'Hello World', 'decoded base64' );


#-----------------------------------------------------------------------
# test method() method
#-----------------------------------------------------------------------

package Test::Method1;
use Badger::Class 
    base   => 'Badger::Base',
    import => 'class';

sub init {
    my ($self, $config) = @_;
    $self->{ foo } = $config->{ foo };
    $self->{ bar } = $config->{ bar };
    return $self;
}

class->method( hello => sub { 'hello world' } );
class->methods( goodbye => sub { "see ya!" } );
class->get_methods('foo bar');
class->set_methods('wiz');

package main;

is( Test::Method1->hello, 'hello world', 'method() test' );
is( Test::Method1->goodbye, 'see ya!', 'methods() test' );
my $t1 = Test::Method1->new( foo => 'Hello', bar => 'World' );
is( $t1->foo, 'Hello', 'generated foo get method' );
is( $t1->bar, 'World', 'generated bar get method' );

is( $t1->wiz('waz'), 'waz', 'set wiz' );
is( $t1->wiz, 'waz', 'get wiz' );


#-----------------------------------------------------------------------
# and again via Badger::Class import hooks
#-----------------------------------------------------------------------

package Test::Method2;
use Badger::Class 
    base   => 'Badger::Base',
    import => 'class',
    get_methods => 'ding dong',
    set_methods => 'dang',
    methods     => {
        welcome  => sub { 'Hello World' },
        farewell => 'Goodbye cruel world',
    };

sub init {
    my ($self, $config) = @_;
    $self->{ ding } = $config->{ ding };
    $self->{ dong } = $config->{ dong };
    return $self;
}

package main;

is( Test::Method2->welcome, 'Hello World', 'welcome method' );
is( Test::Method2->farewell, 'Goodbye cruel world', 'farewell method' );
my $t2 = Test::Method2->new( ding => 'Wrong', dong => 'Number' );
is( $t2->ding, 'Wrong', 'generated ding get method' );
is( $t2->dong, 'Number', 'generated dong get method' );
is( $t2->dang('Ding-A-Ling'), 'Ding-A-Ling', 'set dang' );
is( $t2->dang, 'Ding-A-Ling', 'get dang' );


#-----------------------------------------------------------------------
# test generation of slot methods for list based objects
#-----------------------------------------------------------------------

package Badger::Test::Slots;
use Badger::Class 
    slots => 'size colour object';

sub new {
    my ($class, @stuff) = @_;
    bless \@stuff, $class;
}

package main;
my $bus = Badger::Test::Slots->new(qw(big red bus));
ok( $bus, 'Created slot test object' );
is( $bus->size,   'big', 'big slot' );
is( $bus->colour, 'red', 'red slot' );
is( $bus->object, 'bus', 'bus slot' );



#-----------------------------------------------------------------------
# test words
#-----------------------------------------------------------------------

package Test::Words1;
use Badger::Class words => 'Hubbins Tufnel Smalls';
use Badger::Test;

is( Hubbins, 'Hubbins', 'David St Hubbins' );
is( Tufnel, 'Tufnel', 'Nigel Tufnel' );
is( Smalls, 'Smalls', 'Derek Smalls' );


#-----------------------------------------------------------------------
# test class construction
#-----------------------------------------------------------------------

package Test::Amp::Construction;
use Badger::Class 'class';
use Badger::Test;

my $amp1 = class('Guitar::Amplifier')
    ->base('Badger::Base')
    ->constant( max_volume => 10 )
    ->method( about => sub { "This amp goes up to " . shift->max_volume } )
    ->instance;

is( $amp1->about, 'This amp goes up to 10', $amp1->about );

my $amp2 = class('Nigels::Guitar::Amplifier')
    ->base('Guitar::Amplifier')
    ->constant( max_volume => 11 )
    ->instance;

is( $amp2->about, 'This amp goes up to 11', $amp2->about );
    
my $method = $amp2->class->method('about');
ok( $method, 'got about() method' );
is( $method->($amp2), 'This amp goes up to 11', 'method reference call' );



#-----------------------------------------------------------------------
# test loaded()
#
# Like a river we will flow, on towards the sea we go, when all you do
# can only bring you sadness, out on the sea of madneeeeeeeessssss...
#-----------------------------------------------------------------------

# define this before
package Wasted::Years;
use base 'Badger::Base';

package main;
use Badger::Class 'class';

# both Wasted::Years and Heaven::Can::Wait should be deemed loaded by
# virtue of the fact that they define base classes which affects @ISA
ok( class('Wasted::Years')->loaded, 'Wasted Years is loaded' );
ok( ! class('Sea::Of::Madness')->loaded, 'Sea of Madness is not loaded' );
ok( class('Heaven::Can::Wait')->loaded, 'Heaven Can Wait is loaded' );

# define this after
package Heaven::Can::Wait;
use base 'Badger::Base';




#-----------------------------------------------------------------------
# subclass Badger::Class
#-----------------------------------------------------------------------

package Test::My::Class;

use My::Class
    version   => 11,
    import    => 'class',
    constants => 'black none',
    wibble    => 'This is mic number one',
    wobble    => "Isn't this a lot of fun?";
    
sub colour {
    black 
}

main::is( $VERSION, 11, 'inside version 11' );
main::is( ref class(), 'My::Class', 'class returns My::Class object' );

package main;
is( $Test::My::Class::VERSION, 11, 'outside version 11' );
is( Test::My::Class->colour, 'black', 'How much more black could this be?' );
is( Test::My::Class->none, 'none', 'None, none more black' );
is( Test::My::Class->wibble, 'wibble: This is mic number one', 'wibble hook worked' );
is( Test::My::Class->wobble, "wobble: Isn't this a lot of fun?", 'wobble hook worked' );


#-----------------------------------------------------------------------
# test filesystem hooks
#-----------------------------------------------------------------------

package Test::My::Filesystem;

use Badger::Class
    version    => 1,
    filesystem => 'FS VFS';

package main;

is( Test::My::Filesystem->FS, 'Badger::Filesystem', 'FS loaded' );
is( Test::My::Filesystem->VFS, 'Badger::Filesystem::Virtual', 'VFS loaded' );


#-----------------------------------------------------------------------
# test load() and maybe_load()
#-----------------------------------------------------------------------

is( class('No::Such::Module')->maybe_load, 0, 'cannot load No::Such::Module' );

#$Badger::Class::DEBUG = 1;
ok( ! eval { class('My::BadModule')->maybe_load }, 'maybe_load threw error' );
like( $@, qr/^Can't locate object method/, "Can't locate object method error" );



#-----------------------------------------------------------------------
# test overload
#-----------------------------------------------------------------------

package Badger::Test::Overload;

use Badger::Class
    base      => 'Badger::Base',
    constants => 'TRUE',
    accessors => 'text',
    overload  => {
        '""'     => \&text,
        bool     => sub { 1 },
        fallback => 1,
    };

sub init {
    my ($self, $config) = @_;
    $self->{ text } = $config->{ text };
    return $self;
}

package main;

my $text = Badger::Test::Overload->new( text => 'Hello World' );
is( $text, 'Hello World', 'overloaded text method' );
$text = Badger::Test::Overload->new( text => '' );
ok( $text, 'boolean overload true' );

#-----------------------------------------------------------------------
# test as_text
#-----------------------------------------------------------------------

package Badger::Test::AsText;

use Badger::Class
    base      => 'Badger::Base',
    constants => 'TRUE',
    accessors => 'text',
    as_text   => 'text';

sub init {
    my ($self, $config) = @_;
    $self->{ text } = $config->{ text };
    return $self;
}

package main;

$text = Badger::Test::AsText->new( text => 'Hello Badger' );
is( $text, 'Hello Badger', 'as_text method' );
$text = Badger::Test::AsText->new( text => '0' );
ok( ! $text, 'no boolean overload' );

#-----------------------------------------------------------------------
# test is_true
#-----------------------------------------------------------------------

package Badger::Test::AsBool;

use Badger::Class
    base      => 'Badger::Base',
    accessors => 'text',
    as_text   => 'text',
    is_true   => 1;

sub init {
    my ($self, $config) = @_;
    $self->{ text } = $config->{ text };
    return $self;
}

package main;

$text = Badger::Test::AsBool->new( text => 'Hello Moose' );
is( $text, 'Hello Moose', 'is true as_text method' );
$text = Badger::Test::AsBool->new( text => '0' );
ok( $text, 'is true boolean overload' );


#-----------------------------------------------------------------------
# test defaults
#-----------------------------------------------------------------------

no warnings 'once';
$My::Defaults::FOO = 100;
$My::Defaults::BAR = 0;
use warnings 'once';

require My::Defaults;

is( My::Defaults->foo, 100, 'foo defaulted to 100' );
is( My::Defaults->bar, 0, 'bar defaulted to 0' );
is( My::Defaults->baz, 30, 'bar defaulted to 30' );
is( My::Defaults->defaults, "BAR => 20, BAZ => 30, FOO => 10, wam => bam, wig => wam", '$DEFAULTS set' );

my $defaults = My::Defaults->new;
ok( $defaults, 'created defaults object' );
is( $defaults->foo, 100, 'object foo defaulted to 100' );
is( $defaults->bar, 0, 'object bar defaulted to 0' );
is( $defaults->baz, 30, 'object bar defaulted to 30' );

$defaults = My::Defaults->new( FOO => 99, wig => 'syrup' );
ok( $defaults, 'created customised defaults object' );
is( $defaults->foo, 99, 'object foo set to 99' );
is( $defaults->bar, 0, 'object bar defaulted to 0' );
is( $defaults->wig, 'syrup', 'object wig set to syrup' );


__END__
#-----------------------------------------------------------------------
# test CLASS
#-----------------------------------------------------------------------

package Test::Badger::Amp;
use Badger::Class 
    constant => { max_volume => 10 };

sub volume { shift->max_volume }

package Test::Badger::Amp::Louder;
use Badger::Class 
    base     => 'Test::Badger::Amp',
    constant => { max_volume => 11 };
    

package main;
is( Test::Badger::Amp->volume,         10, 'This amp goes up to 10' );
is( Test::Badger::Amp::Louder->volume, 11, 'This amp goes up to 11' );

__END__



__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
