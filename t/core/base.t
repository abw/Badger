#============================================================= -*-perl-*-
#
# t/base.t
#
# Test the Badger::Base module.  Run with -d for debugging info, 
# and/or -c for colour output.
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
use Badger::Base;
use Badger::Test 
    tests => 107,
    debug => 'Badger::Exporter',
    args  => \@ARGV;

my ($pkg, $obj);


#-----------------------------------------------------------------------
# Special cases for testing the id() method.
#-----------------------------------------------------------------------

use Badger;
is( Badger->class->id, 'badger', 'Badger id' );
is( Badger::Base->class->id, 'base', 'Badger::Base id' );


#------------------------------------------------------------------------
# basic test of constructor
#------------------------------------------------------------------------

# instantiate a base class object and test error reporting/returning
$pkg = 'Badger::Base';
$obj = $pkg->new() || die $pkg->error();
ok( $obj, 'created a base class object' );
is( $obj->class->id, 'base', 'base type' );


#------------------------------------------------------------------------
# test the error() method
#------------------------------------------------------------------------

eval { $obj->error('barf') };
ok( $@, 'set object error' );
is( $@->type(), 'base', 'got exception type' );
is( $@->info(), 'barf', 'got exception info' );
ok( $obj->error() eq 'barf', 'got object error' );


#------------------------------------------------------------------------
# test the warn() method
#------------------------------------------------------------------------

my $warning;
$SIG{__WARN__} = sub {
    $warning = shift;
};
$obj->warn("Strange things are afoot at the Circle-K\n");
is( $warning, "Strange things are afoot at the Circle-K\n", 'got warning' );

$obj = $pkg->new( on_warn => sub { 
    my $msg = shift;
    chomp $msg;
    $warning = "WARN[$msg]";
    return $msg;
} );

$obj->warn("Be excellent to each other\n");
is( $warning, "WARN[Be excellent to each other]", 'got warning from custom handler' );

my $extra;
$obj->on_warn( after => sub {
    my $msg = shift;
    chomp $msg;
    $extra = "EXTRA[$msg]";
    return $msg;
});

$obj->warn("Totally bogus, dude\n");
is( $warning, "WARN[Totally bogus, dude]", 'got totally bogus warning' );
is( $extra, "EXTRA[Totally bogus, dude]", 'got totally bogus extra warning' );

pass( '** TODO ** - test on_warn before/after/replace modes' );

#------------------------------------------------------------------------
# test the $ON_WARN pkg var works
#------------------------------------------------------------------------

package Badger::Test::Warning;
use base 'Badger::Base';

our $ON_WARN = 'totally_bogus';

package main;
delete $SIG{__WARN__};

my $wpkg = 'Badger::Test::Warning';
eval { $wpkg->warn("fall apart") };
like( $@, qr/Invalid on_warn method: totally_bogus/, 'detected bogus warn handler' );


package Badger::Test::Warning2;

use base 'Badger::Base';

our $ON_WARN  = 'most_excellent';
our $ON_ERROR = 'most_bogus';
our $MESSAGES = {
    totally => 'Totally %s dude',
};

sub most_excellent {
    my ($self, $message) = @_;
    $self->{ excellent } =  $message;
    return 0;  # don't pass it on.
}

sub most_bogus {
    my ($self, $message) = @_;
    $self->{ bogus } =  $message;
}

package main;
my $goodness = 'this is good';
$SIG{__WARN__} = sub { $goodness = 'this is bad' };

# 0 return value from most_excellent should terminate warning chain
# before it gets a change to raise a regular warning
$wpkg = 'Badger::Test::Warning2';
$obj = $wpkg->new;
$obj->warn("I believe our adventure through time has taken a most serious turn.");
is( $obj->{ excellent }, "I believe our adventure through time has taken a most serious turn.", 'adventure through time');

is( $goodness, 'this is good', 'warning chain was broken by the most excellent handler' );

$obj->warn_msg( totally => 'bogus' );
is( $obj->{ excellent }, "Totally bogus dude", 'Totally bogus dude');

# redirect warnings to errors
$obj = $pkg->new;
$obj->on_warn('error');
eval { $obj->warn("This warning goes up to eleven") };
is( $@, 'base error - This warning goes up to eleven', 'upgraded warning to error' );


#-----------------------------------------------------------------------
# test ON_ERROR is *NOT* inherited
#-----------------------------------------------------------------------

our $SAVE_THIS;

package Foo;
use base 'Badger::Base';
our $ON_WARN = 'error';

package Bar;
use base 'Badger::Base';
our $ON_WARN = sub { $SAVE_THIS = shift };

package main;
$obj = Bar->new();
$obj->warn('poop');
is( $SAVE_THIS, 'poop', "You've got poop on your shoes" );

#------------------------------------------------------------------------
# Badger::Test::Fail always fails, but we check it reports errors OK
#------------------------------------------------------------------------

package Badger::Test::Fail;
use base qw( Badger::Base );
use vars qw( $ERROR $WARNING );

sub init {
    my $self = shift;
    return $self->error('expected failure');
}

package main;

# Badger::Test::Fail should never work, but we check it reports errors OK
$pkg = 'Badger::Test::Fail';
eval { $pkg->new() };
ok( $@, 'test fail failed' );
is( $pkg->error, 'expected failure', 'got object error' );
is( $Badger::Test::Fail::ERROR, 'expected failure', 'got package error' );



#------------------------------------------------------------------------
# Badger::Test::Name should only work with a 'name' parameter
#------------------------------------------------------------------------

package Badger::Test::Name;
use base qw( Badger::Base );
use vars qw( $ERROR );

sub init {
    my ($self, $params) = @_;
    $self->{ NAME } = $params->{ name } 
        || return $self->error("No name!");
    return $self;
}

sub name {
    $_[0]->{ NAME };
}

package main;

$pkg = 'Badger::Test::Name';
eval { $obj = $pkg->new() };
ok( $@, 'name test failed' );
is( $Badger::Test::Name::ERROR, 'No name!', 'name error variable' );
is( $pkg->error(), 'No name!', 'name error method' );

# give it what it wants...
$obj = $pkg->new({ name => 'foo' }) || die $pkg->error();
ok( $obj, 'created name object' );
ok( ! $obj->error(), 'no error' );
is( $obj->name(), 'foo', 'name matches' );

# ... in 2 different flavours
$obj = $pkg->new(name => 'foo') || die $pkg->error();
ok( $obj, 'got args object' );
ok( ! $obj->error(), 'no args error' );
is( $obj->name(), 'foo', 'args name matches' );


#------------------------------------------------------------------------
# test the throw option
#------------------------------------------------------------------------

$obj = Badger::Base->new( throws => 'food' );
eval { $obj->error('cheese ', 'roll') };
our $except = $@;
ok( $except, 'thrown food exception' );
is( $except->type(), 'food', 'type is food' );
is( $except->info(), 'cheese roll', 'info is cheese roll' );

$obj->throws('cutlery');
eval { $obj->error('knife ', 'fork') };
$except = $@;
ok( $except, 'thrown cutlery exception' );
is( $except->type(), 'cutlery', 'type is cutlery' );
is( $except->info(), 'knife fork', 'info is knife fork' );


#------------------------------------------------------------------------
# test that the $THROWS package variable has the same effect
#------------------------------------------------------------------------

package My::Thrower;
use base qw( Badger::Base );

our $THROWS = 'thrower';

package My::Sub::Thrower;
use base qw( My::Thrower );
use vars qw( $THROWS );

*THROWS = \$My::Thrower::THROWS;

our $MESSAGES = {
    runny => 'Your %s is too runny',
};

sub cheese {
    shift->throw_msg( cheese => runny => 'Camembert' );
}

package main;

$obj = My::Thrower->new();
eval { $obj->error('threw error') };
$except = $@;
ok( $except, 'thrown thrower exception' );
is( $except->type(), 'thrower', 'type is thrower' );
is( $except->info(), 'threw error', 'info is threw error' );

$obj = My::Sub::Thrower->new();
eval { $obj->error('threw sub-error') };
$except = $@;
ok( $except, 'thrown sub-thrower exception' );
is( $except->type(), 'thrower', 'type is still thrower' );
is( $except->info(), 'threw sub-error', 'info is threw sub-error' );

$obj = My::Sub::Thrower->new( throws => 'frobless' );
eval { $obj->error('threw frobless error') };
$except = $@;
ok( $except, 'thrown frobless exception' );
is( $except->type(), 'frobless', 'type is frobless' );
is( $except->info(), 'threw frobless error', 'info is threw frobless error' );

My::Sub::Thrower->throws('frisbee');
$obj = My::Sub::Thrower->new();
eval { $obj->error('threw frisbee') };
$except = $@;
ok( $except, 'thrown frisbee' );
is( $except->type(), 'frisbee', 'a small plastic disc' );
is( $except->info(), 'threw frisbee', 'it spins, it hovers!' );

ok( ! $obj->try('cheese'), 'cheese fail' );
$except = $obj->reason;
is( $except->type, 'cheese', 'cheese thrown' );
is( $except->info, 'Your Camembert is too runny', $except->info );


#-----------------------------------------------------------------------
# and the same via T::Class
#-----------------------------------------------------------------------

package Another::Thrower;
use Badger::Class
    version => 3.00,
    base    => 'Badger::Base',
    throws  => 'frisbee';

package Another::SubClass;
use Badger::Class
    base    => 'Another::Thrower',
    version => 3.00;
    
package main;

is( Another::Thrower->throws, 'frisbee', 'Another::Thrower throws frisbee' );
is( Another::SubClass->throws, 'frisbee', 'Another::SubClass throws frisbee' );


#------------------------------------------------------------------------
# test the throw() method in throwing and re-throwing exceptions
#------------------------------------------------------------------------

my $base = Badger::Base->new();
my $ee = Badger::Exception->new( type => 'engine', 
                                   info => 'warp drive offline' );

eval { $base->throw( engine => $ee ) };
is( "$@", 'engine error - warp drive offline', 'warp drive is offline' );

eval { $base->throw( propulsion => $ee ) };
is( "$@", 'propulsion error - engine error - warp drive offline', 
    'propulsion system is NFG' );



#------------------------------------------------------------------------
# error_msg()
#------------------------------------------------------------------------

package My::Base;
use base qw( Badger::Base );

our $MESSAGES = {
    no_pony    => 'Missing pony! (got "%s")',
    no_buffy   => 'Missing Buffy! (got %s and %s)',
    one_louder => '%1$s. Exactly. %2$s louder',
    not_ten    => "Well, it's %2\$s louder, isn't it? It's not %1\$s.",
};

package main;

$base = My::Base->new();

eval { $base->error_msg( no_pony => 'donkey' ) };
ok( $@, 'pony error' );
is( $base->error(), 'Missing pony! (got "donkey")', 'no pony!' );

eval { $base->error_msg( no_buffy => 'Angel', 'Willow' ) };
ok( $@, 'Buffy error' );
is( $base->error(), 'Missing Buffy! (got Angel and Willow)', 'no Buffy!' );

eval { $base->error_msg( one_louder => 'Eleven', 'One' ) };
ok( $@, 'One louder error' );
is( $base->error(), 'Eleven. Exactly. One louder', 'Eleven is one louder' );

eval { $base->error_msg( not_ten => 'ten', 'one' ) };
ok( $@, 'Not ten error' );
is( $base->error(), "Well, it's one louder, isn't it? It's not ten.", "It's not ten" );


#------------------------------------------------------------------------
# error_msg() with subclass
#------------------------------------------------------------------------

package My::Sub;
use base qw( My::Base );

our $MESSAGES = {
    no_buffy => 'Buffy still missing! (%s is here)',
    no_angel => 'Angel is slain! (by %s)',
};

package main;

my $sub = My::Sub->new();

eval { $sub->error_msg( no_pony => 'ass' ) };
ok( $@,  'ass error' );
is( $sub->error(), 'Missing pony! (got "ass")', 'still no pony!' );

eval { $sub->error_msg( no_buffy => 'Giles' ) };
ok( $@, 'Giles error' );
is( $sub->error(), 'Buffy still missing! (Giles is here)', 'still no Buffy!' );

eval { $sub->error_msg( no_angel => 'Buffy' ) };
ok( $@, 'Angel error' );
is( $sub->error(), 'Angel is slain! (by Buffy)', 'Angle is slain!' );


#------------------------------------------------------------------------
# test the on_error() method
#------------------------------------------------------------------------

package My::OnError;
use base 'Badger::Base';

My::OnError->on_error(\&complain);

our @COMPLAINT;

sub complain {
    push(@COMPLAINT, @_);
    return @_;
}

package main;

my $complainer = My::OnError->new();
eval { $complainer->error("it's raining") };
ok( $@, "it's raining" );
is( $My::OnError::COMPLAINT[0], "it's raining", "raining error reported" );
is( $@->type, "my.onerror", "raining error type" );

$complainer = My::OnError->new( throws => 'umbrella' );
eval { $complainer->error("it's pouring") };
ok( $@, "it's pouring" );
is( $My::OnError::COMPLAINT[1], "it's pouring", "pouring error reported" );
is( $@->type, "umbrella", "umbrella error type" );
is( $@->info, "it's pouring", "umbrella error info" );


#-----------------------------------------------------------------------
# test the not_implemented() and todo() methods
#-----------------------------------------------------------------------

our ($foo_line, $bar_line, $wam_line, $bam_line) = (0) x 4;

package My::Incomplete;
use base 'Badger::Base';

sub foo {
    $main::foo_line = __LINE__ + 1;
    shift->not_implemented;
}

sub bar {
    $main::bar_line = __LINE__ + 1;
    shift->not_implemented('first test case');
}

sub wam {
    $main::wam_line = __LINE__ + 1;
    shift->todo;
}

sub bam {
    $main::bam_line = __LINE__ + 1;
    shift->todo('second test case');
}

package main;
my $incomplete = My::Incomplete->new();

eval { $incomplete->foo };
like( $@, 
    qr/my.incomplete error - foo\(\) is not implemented .*?base.t at line $foo_line/, 
    'foo not implemented' );

eval { $incomplete->bar };
like( $@, 
    qr/my.incomplete error - bar\(\) first test case is not implemented .*?base.t at line $bar_line/, 
    'bar not implemented' );

eval { $incomplete->wam };
like( $@, 
      qr/my\.incomplete error - wam\(\) is TODO for My::Incomplete in .*? at line $wam_line/, 
      'wam todo' );

eval { $incomplete->bam };
like( $@, 
      qr/my\.incomplete error - bam\(\) second test case is TODO for My::Incomplete in .*? at line $bam_line/, 
      'bam not implemented' );


#-----------------------------------------------------------------------
# test decline() method an friends
#-----------------------------------------------------------------------

package Badger::Test::Decliner;
use base 'Badger::Base';

sub barf {
    shift->error("failed in a miserable way");
}    

sub yelp {
    shift->decline("decline in a wishy-washy way");
}

package main;

my $dec = Badger::Test::Decliner->new;
ok( ! $dec->yelp, 'yelp declined' );
is( $dec->reason, 'decline in a wishy-washy way', 'got reason' );
ok( $dec->declined, 'declined flag set' );

# try() puts an eval { ... } wrapper around a methods
eval { $dec->barf };
is( $dec->reason, 'failed in a miserable way', 'barfed error' );
ok( ! $dec->declined, 'declined flag cleared' );
    


#-----------------------------------------------------------------------
# test try/catch
#-----------------------------------------------------------------------

package Danger::Mouse;
use base 'Badger::Base';

sub hurl {
    shift->error("HURLING: ", @_);
}

sub missing {
    shift->not_implemented;
}

sub not_done {
    my $self = shift;
    my $item = shift || $self->todo;
    $self->todo('with argument');
}

package main;
my $mouse = Danger::Mouse->new();
ok( ! eval { $mouse->hurl('cheese') }, 'eval failed' );
is( $@, 'danger.mouse error - HURLING: cheese', 'danger mouse error' );

ok( ! $mouse->try( hurl => 'cheese' ), 'try failed' );
is( $mouse->reason, 'danger.mouse error - HURLING: cheese', 'danger mouse error' );

ok( ! $mouse->try('missing'), 'try missing' );
like( $mouse->reason, qr/danger\.mouse error - missing\(\) is not implemented for Danger::Mouse/, 'danger mouse missing' );

ok( ! $mouse->try('not_done'), 'not_done' );
like( $mouse->reason, qr/danger\.mouse error - not_done\(\) is TODO for Danger::Mouse/, 'danger mouse todo' );

ok( ! $mouse->try( not_done => 10 ), 'not_done with arg' );
like( $mouse->reason, qr/danger\.mouse error - not_done\(\) with argument is TODO for Danger::Mouse/, 'danger mouse todo' );


#-----------------------------------------------------------------------
# test try monad
#-----------------------------------------------------------------------

ok( ! $mouse->try->hurl('cheese'), 'try trial failed' );
is( $mouse->reason, 'danger.mouse error - HURLING: cheese', 'danger mouse trial error' );

ok( ! $mouse->try->missing, 'try trial missing' );
like( $mouse->reason, qr/danger\.mouse error - missing\(\) is not implemented for Danger::Mouse/, 'danger mouse trial missing' );

ok( ! $mouse->try->not_done, 'trial not_done' );
like( $mouse->reason, qr/danger\.mouse error - not_done\(\) is TODO for Danger::Mouse/, 'danger mouse trial todo' );

ok( ! $mouse->try->not_done(10), 'not_done trial with arg' );
like( $mouse->reason, qr/danger\.mouse error - not_done\(\) with argument is TODO for Danger::Mouse/, 'danger mouse trial todo' );


#-----------------------------------------------------------------------
# test fatal
#-----------------------------------------------------------------------

eval { $mouse->fatal('sun exploded') };
like( $@, qr/Fatal badger error: sun exploded/, 'fatal error' );

package Your::Badger::Module;
use base 'Badger::Base';
our $THROWS = 'YBM';

package main;
eval { Your::Badger::Module->error('Fail!') };
is( $@, 'YBM error - Fail!', 'YBM Fail!' );

Your::Badger::Module->throws('BadgerMod');
eval { Your::Badger::Module->error('Fail!') };
is( $@, 'BadgerMod error - Fail!', 'BadgerMod Fail!' );

    
__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
