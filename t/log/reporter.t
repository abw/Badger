#============================================================= -*-perl-*-
#
# t/log/reporter.t
#
# Test the Badger::Reporter module, a new base class for Badger::Log,
# Badger::Test::Manager, and maybe a few other things.
#
# Copyright (C) 2005-2008 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Test
    skip  => 'Still in development',
    tests => 40,
    debug => 'Badger::Reporter',
    args  => \@ARGV;

use Badger::Reporter;
use constant REPORTER => 'Badger::Reporter';

pass( 'Loaded ' . REPORTER );

my $reporter = REPORTER->new(
    events => [
        { name    => 'foo',
          colour  => 'green',
          message => 'FOO: %s',
          summary => '%s foo events',
          verbose => 0,
        },
        'bar'
    ],
);

$reporter->foo('the foo happened');
$reporter->foo('the foo happened again');

$reporter->bar('the bar happened');
$reporter->bar('the bar happened again');

print $reporter->summary;


#-----------------------------------------------------------------------
# subclass
#-----------------------------------------------------------------------

package My::Reporter;

use base 'Badger::Reporter';

our $EVENTS = [
    { 
        name    => 'wiz',
        colour  => 'green',
        message => 'WIZ: %s',
        summary => '%s wizzy wiz events',
        verbose => 1,
    },
    { 
        name    => 'waz',
        colour  => 'red',
        message => 'WAZ: %s',
        summary => '%s wazzy waz events',
        verbose => 1,
    },
];

our $MESSAGES = {
    missing => 'You forget to bring the %s',
};

package main;

print "\n\n";

my $reporter = My::Reporter->new( verbose => 1 );

$reporter->wiz('number one');
$reporter->waz('number two');
$reporter->wiz('buckle');
$reporter->waz('my shoe');
$reporter->wiz_msg( missing => 'wizzyment' );
$reporter->waz_msg( missing => 'wazzyment' );