#============================================================= -*-perl-*-
#
# t/log/log.t
#
# Test the Badger::Log module.
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
    tests => 41,
    debug => 'Badger::Log',
    args  => \@ARGV;

use Badger::Log;
use Badger::Utils 'Now';
use constant LOG => 'Badger::Log';


#------------------------------------------------------------------------
# create a default log object
#------------------------------------------------------------------------

my $log = LOG->new();
ok( $log, 'created a first log object' );
is( $log->debug, 0, 'debug is off' );
is( $log->info, 0, 'info is off' );
is( $log->warn, 1, 'warn is on' );
is( $log->error, 1, 'error is on' );
is( $log->fatal, 1, 'fatal is on' );


#------------------------------------------------------------------------
# test constructor options
#------------------------------------------------------------------------

$log = LOG->new( debug => 1, info => 1, warn => 0 );
ok( $log, 'created a second log object' );
is( $log->debug, 1, 'debug is on' );
is( $log->info, 1, 'info is on' );
is( $log->warn, 0, 'warn is off' );
is( $log->error, 1, 'error is still on' );
is( $log->fatal, 1, 'fatal is still on' );


#------------------------------------------------------------------------
# test level() method
#------------------------------------------------------------------------

is( $log->level('debug'), 1, 'debug is on' );
is( $log->level( info => 0 ), 0, 'turned info off' );
is( $log->level('info'), 0, 'info is confirmed off' );
eval { $log->level( cheese => 42 ) };
like( $@, qr/^Fatal badger error: Invalid logging level/, 'invalid level error' );


#------------------------------------------------------------------------
# test enable()/disable() methods
#------------------------------------------------------------------------

$log->disable(qw( debug error fatal));
$log->enable(qw( info warn ));
is( $log->debug, 0, 'debug has been disabled' );
is( $log->info, 1, 'info has been enabled' );
is( $log->warn, 1, 'warn has been enabled' );
is( $log->error, 0, 'error has been disabled' );
is( $log->fatal, 0, 'fatal has been disabled' );

#------------------------------------------------------------------------
# test handlers
#------------------------------------------------------------------------

our @WARNINGS;
our @ERRORS;

$log = LOG->new({
    warn  => \@WARNINGS,
    error => sub {
        my ($level, $message) = @_;
        push(@ERRORS, $message);
    },
});

ok( $log, 'created a third log object' );
is( $log->debug, 0, 'debug is off again' );
is( $log->info, 0, 'info is off again' );
is( ref $log->warn, 'ARRAY', 'warn is an ARRAY reference ' );
is( ref $log->error, 'CODE', 'error is a CODE reference ' );
is( $log->fatal, 1, 'fatal is still going strong' );

# call some methods
$log->debug("I am debugging");
$log->info("I am info");
$log->warn("I am a warning");
$log->error("I am an error");

# check our arrays got populated
is( scalar @WARNINGS, 1, 'got 1 warning' );
is( scalar @ERRORS, 1, 'got 1 error' );

# once more for luck
$log->warn("I am another warning");
$log->error("I am another error");
is( scalar @WARNINGS, 2, 'got 2 warnings' );
is( scalar @ERRORS, 2, 'got 2 errors' );

# set up local warn handler to catch fatal to check that
#  warn() really gets called

local $SIG{__WARN__} = sub {
    push(@ERRORS, shift);
};

$log->fatal("I am fatal");
is( scalar @ERRORS, 3, 'got a fatal error' );


#------------------------------------------------------------------------
# test delegation
#------------------------------------------------------------------------

my $log2 = LOG->new( warn => 0, error => $log );
ok( $log2, 'created a second log' );

$log2->warn('a third warning should be ignored' );
is( scalar @WARNINGS, 2, 'still got 2 warnings' );

$log2->error('error should be delegated' );
is( scalar @ERRORS, 4, 'got the extra error' );
is( $ERRORS[3], 'error should be delegated', 'checked error' );


#------------------------------------------------------------------------
# test format
#------------------------------------------------------------------------

my $log3 = LOG->new({
    format => '<system>/<level> (<message>)',
});

$log3->fatal('blah blah blah');

is( $ERRORS[4], "Badger/fatal (blah blah blah)\n", 'checked error format' );

my $log4 = LOG->new({
    format => '<barf>/<level> (<message>)',
});

$log4->fatal('blah blah blah');

is( $ERRORS[5], "<barf>/fatal (blah blah blah)\n", 'checked barf format' );

#------------------------------------------------------------------------
# test strftime
#------------------------------------------------------------------------

my $strftime = '%a %b %d %Y';
my $today = Now->format($strftime);
my $log5 = LOG->new({
    format   => '<time> - <message>',
    strftime => '%a %b %d %Y'
});

$log5->error('one of our badgers is missing');

is( $ERRORS[6], "$today - one of our badgers is missing\n", 'checked strftime' );


#-----------------------------------------------------------------------
# test subclass
#-----------------------------------------------------------------------

package My::Log;
use base 'Badger::Log';

our $SYSTEM   = 'MyApp';
our $FORMAT   = '[<level>] [<system>] <message>';
our $MESSAGES = {
    sorry => "I'm sorry %s I'm afraid I can't do that",
};

package main;

my (@warnings);
my $mylog = My::Log->new(
    warn  => \@warnings,
);
$mylog->warn_msg( sorry => 'Dave' );

is( scalar(@warnings), 1, 'got one warning' );
is( $warnings[0], "I'm sorry Dave I'm afraid I can't do that", 'got warning' );



__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
