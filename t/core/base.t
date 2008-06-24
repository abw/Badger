#============================================================= -*-perl-*-
#
# t/base.t
#
# Test the Badger::Base module.
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
use Test::More tests  => 96;

# run with -d flag to enable debugging, e.g. perl base.t -d
our $DEBUG = $Badger::Base::DEBUG = grep(/^-d/, @ARGV);
$Badger::Base::WARN_OUT_LOUD = $DEBUG;

my ($pkg, $obj);


#-----------------------------------------------------------------------
# Special cases for testing the id() method.
#-----------------------------------------------------------------------

use Badger;
is( Badger->id, 'badger', 'Badger id' );
is( Badger::Base->id, 'base', 'Badger::Base id' );


#------------------------------------------------------------------------
# basic test of constructor
#------------------------------------------------------------------------

# instantiate a base class object and test error reporting/returning
$pkg = 'Badger::Base';
$obj = $pkg->new() || die $pkg->error();
ok( $obj, 'created a base class object' );
is( $obj->id, 'base', 'base type' );


#------------------------------------------------------------------------
# test the error() method
#------------------------------------------------------------------------

eval { $obj->error('barf') };
ok( $@, 'set object error' );
is( $@->type(), 'base', 'got exception type' );
is( $@->info(), 'barf', 'got exception info' );
ok( $obj->error() eq 'barf', 'got object error' );


#------------------------------------------------------------------------
# test the warning() and warnings() object methods
#------------------------------------------------------------------------

ok( ! $obj->warning('first warning'), 'sent first warning' );

my $warnings = $obj->warning() || die "no warnings returned\n";
ok( $warnings, 'got warnings back' );
is( ref $warnings, 'ARRAY', 'warnings is an array ref' );
is( scalar @$warnings, 1, 'has one item' );
is( $warnings->[0], 'first warning', 'first warning correct' );

ok( ! $obj->warning('second ', 'warning'), 'sent second warning' );
is( scalar @$warnings, 2, 'has two items' );
is( $warnings->[0], 'first warning', 'first warning still correct' );
is( $warnings->[1], 'second warning', 'second warning correct' );

ok( ! $obj->warning({ test => 'reference' }), 'sent reference warning' );
is( $warnings->[2]->{ test }, 'reference', 'got reference warning back' );

# warnings() returns list in list context
my @warns = $obj->warnings();
is( $warns[0], 'first warning', 'list warning one' );
is( $warns[1], 'second warning', 'list warning two' );

# warnings() returns list ref in scalar context
my $warns = $obj->warnings();
is( $warns, 3, 'three warnings' );
$warns = $obj->warning();
is( $warns->[0], 'first warning', 'list ref warning one' );
is( $warns->[1], 'second warning', 'list ref warning two' );

# warnings($a, $b, $c) sets several warnings
ok( ! $obj->warnings('foo', 'bar', { ping => 'pong' }), 'set warnings' );
is( $warns->[3], 'foo', 'foo warning' );
is( $warns->[4], 'bar', 'bar warning' );
is( $warns->[5]->{ ping }, 'pong', 'game of ping pong' );


#------------------------------------------------------------------------
# test the warning() and warnings() class methods
#------------------------------------------------------------------------

package Badger::Test::Warning;
use base qw( Badger::Base );
use vars qw( $WARNING );

package main;

my $wpkg = 'Badger::Test::Warning';
ok( ! defined $wpkg->warning('warning one'), 'sent first pkg warning' );
$warns = $wpkg->warning();
ok( $warns, 'got package warnings back' );
is( ref $warns, 'ARRAY', 'it is an array' );
is( scalar @$warns, '1', 'it has one entry' );
is( $warns->[0], 'warning one', 'package warning is correct' );

ok( ! defined $wpkg->warning('two'), 'sent second pkg warning' );
is( join(', ', $wpkg->warnings()), 'warning one, two', 
    'got back both package warnings' );

is( $wpkg->warnings('three', 'four'), 0, 
    'sent third and fourth pkg warning' );
is( join(', ', $wpkg->warnings()), 'warning one, two, three, four', 
    'got back all four package warnings' );



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
    one_louder => '%0. Exactly. %1 louder',
    not_ten    => "Well, it's %1 louder, isn't it? It's not %0.",
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
    qr/my.incomplete error - foo\(\) is not implemented in .*?base.t at line $foo_line/, 
    'foo not implemented' );

eval { $incomplete->bar };
like( $@, 
    qr/my.incomplete error - bar\(\) first test case is not implemented in .*?base.t at line $bar_line/, 
    'bar not implemented' );

eval { $incomplete->wam };
is( $@, 
    "my.incomplete error - wam() is TODO in My::Incomplete at line $wam_line", 
    'wam todo' );

eval { $incomplete->bam };
is( $@, 
    "my.incomplete error - bam() second test case is TODO in My::Incomplete at line $bam_line", 
    'bam not implemented' );

__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
