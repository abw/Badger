#============================================================= -*-perl-*-
#
# t/core/debug.t
#
# Test the Badger::Debug module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;

use lib qw( ./lib ../lib ../../lib t/core/lib );
use Badger::Debug;
use Badger::Base;
use Badger::Test 
    debug => 'Badger::Debug',
    args  => \@ARGV,
    tests => 34;
    

#-----------------------------------------------------------------------
# tied object to catch output to STDERR
#-----------------------------------------------------------------------

package Badger::TieString;

sub TIEHANDLE {
    my ($class, $textref) = @_;
    bless $textref, $class;
}

sub PRINT {
    my $self = shift;
    $$self = join('', @_);
}


#-----------------------------------------------------------------------
#  simple test
#-----------------------------------------------------------------------

package main;

my $dbgmsg;
tie *STDERR, 'Badger::TieString', \$dbgmsg;

$SIG{__DIE__} = sub {
    no warnings;
    untie *STDERR;
};

my $obj = Badger::Base->new();

$obj->debug("Hello World\n");
like( $dbgmsg, qr/\[main \(Badger::Base\) line \d\d\] Hello World/, 'Hello World' );

$obj->debug('Hello ', "Badger\n");
like( $dbgmsg, qr/\[main \(Badger::Base\) line \d\d\] Hello Badger/, 'Hello Badger' );


#-----------------------------------------------------------------------
# subclass
#-----------------------------------------------------------------------

package Badger::Test::Debug1;
use Badger::Debug 'debugging debug';
our $DEBUG = 1;

sub new {
    bless { }, shift;
}

sub hello {
    my ($self, $name) = @_;
    $self->debug("Hello ", $name || 'World') if $DEBUG;
}

package main;
use strict;
use warnings;

pass('here');
$obj = Badger::Test::Debug1->new;
pass('there');
$obj->hello('Ferret');
pass('there');
like( $dbgmsg, qr/\[Badger::Test::Debug1 line \d\d\] Hello Ferret/, 'Hello Ferret' );

pass('there');

$dbgmsg = '';

is( $obj->debugging(0), 0, 'turned debugging off' );
is( $obj->debugging, 0, 'debugging is now turned off' );
$obj->hello('Stoat');
is( $dbgmsg, '', 'No stoats allowed' );


#-----------------------------------------------------------------------
# test $DEBUG variable
#-----------------------------------------------------------------------

package Badger::Test::Debug::Variable;

use Badger::Debug 'debugging', '$DEBUG' => 1;
use Badger::Test;
is( $Badger::Test::Debug::Variable::DEBUG, 1, 'set $DEBUG to 1' );

package main;
is( Badger::Test::Debug::Variable->debugging, 1, 'debugging for var is on' );
Badger::Test::Debug::Variable->debugging(0);
is( Badger::Test::Debug::Variable->debugging, 0, 'debugging for var is now off' );
is( $Badger::Test::Debug::Variable::DEBUG, 0, 'set $DEBUG to 0' );


#-----------------------------------------------------------------------
# test DEBUG constant
#-----------------------------------------------------------------------

package Badger::Test::Debug::Constant::One;

use My::Debugger1;
use Badger::Test;
is( My::Debugger1->wibble, 'normal wibble', 'DEBUG is off' );

# pretend we never loaded it so we can play again...
delete $INC{'My/Debugger1.pm'};

package Badger::Test::Debug::Constant::Two;

# setting $DEBUG variable before loading My::Debugger should make DEBUG
# be set true, so will enable debugging code in the module as it is 
# compiled.
$My::Debugger1::DEBUG = 1;
require My::Debugger1;

use Badger::Test;
is( My::Debugger1->wibble, 'debugging wibble', 'DEBUG is on' );


#-----------------------------------------------------------------------
# test default option
#-----------------------------------------------------------------------

package Badger::Test::Debug::Mixed1;

use My::Debugger2;

use Badger::Test;
is( My::Debugger2->wibble, 'normal wibble', 'wibble DEBUG is off' );
is( My::Debugger2->wobble, 'normal wobble', 'wobble $DEBUG is off' );
My::Debugger2->debugging(1);
is( My::Debugger2->wibble, 'normal wibble', 'wibble DEBUG is still off' );
is( My::Debugger2->wobble, 'debugging wobble', 'wobble $DEBUG is now on' );


# pretend we never loaded it so we can play again...
delete $INC{'My/Debugger2.pm'};

package Badger::Test::Debug::Mixed2;

# setting $DEBUG variable before loading My::Debugger should make DEBUG
# be set true, so will enable debugging code in the module as it is 
# compiled.
$My::Debugger2::DEBUG = 1;
require My::Debugger2;

use Badger::Test;
is( My::Debugger2->wibble, 'debugging wibble', 'wibble DEBUG is on' );
is( My::Debugger2->wobble, 'debugging wobble', 'wobble $DEBUG is on' );
My::Debugger2->debugging(0);
is( My::Debugger2->wibble, 'debugging wibble', 'wibble DEBUG is still on' );
is( My::Debugger2->wobble, 'normal wobble', 'wobble $DEBUG is now off' );

package main;

$dbgmsg = '';
My::Debugger2->hello;
is( $dbgmsg, "[My::Debugger2 line 23] Hello world\n", 'got debug message' );

#-----------------------------------------------------------------------
# test debug load option
#-----------------------------------------------------------------------

package Badger::Test::Debug::Mixed3;

use Badger::Debug 
    modules => 'My::Debugger3';
use My::Debugger3;

package main;

is( My::Debugger3->debug_static_status, 'on', 'debugger3 static debugging is on' );
is( My::Debugger3->debug_dynamic_status, 'on', 'debugger3 dynamic debugging is on' );

My::Debugger3->debugging(0);

is( My::Debugger3->debug_static_status, 'on', 'debugger3 static debugging is still on' );
is( My::Debugger3->debug_dynamic_status, 'off', 'debugger3 dynamic debugging is now off' );


#-----------------------------------------------------------------------
# changed Badger::Class to delegate debug to Badger::Debug
#-----------------------------------------------------------------------

ok( Badger::Debug->export('foo', '$DEBUG' => 1), 'exported from Badger::Debug' );


#-----------------------------------------------------------------------
# test debug_at();
#-----------------------------------------------------------------------

package Badger::Test::Debug::At;

use Badger::Debug ':debug';
use Badger::Class
    base  => 'Badger::Base',
    debug => 1;

package main;

my $at = Badger::Test::Debug::At->new;
is(
    $at->debug_at(
        { where => 'At the edge of time', line  => 420 }, 
        'Flying sideways'
    ),
    "[At the edge of time line 420] Flying sideways\n",
    'I can fly sideways through time'
);

#-----------------------------------------------------------------------
# change message format
#-----------------------------------------------------------------------

package Badger::Test::Debug::Format;

use Badger::Debug ':debug';
use Badger::Class
    base  => 'Badger::Base',
    debug => 1;

package main;
use Badger::Timestamp 'Now';

my $format = Badger::Test::Debug::Format->new;

{
    local $Badger::Debug::FORMAT = '<pkg> <class> <where> <line> <msg>';

    is( 
        $format->debug_at(
            { where => 'backside', line  => 540 }, 
            'method air'
        ),
        "main Badger::Test::Debug::Format backside 540 method air\n",
        'backside 540 method air'
    );
    is( 
        $format->debug_at(
            { where => 'frontside', format => '<where> <msg>' }, 
            'boardslide'
        ),
        "frontside boardslide\n",
        'frontside boardslide'
    );

    local $Badger::Debug::FORMAT = '<msg> on <date> at <time>';
    my $date = Now->date;
    like( 
        $format->debug('beep'),
        qr/beep on $date at \d\d/,
        'message format with date and time'
    );
}
