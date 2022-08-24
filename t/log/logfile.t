#============================================================= -*-perl-*-
#
# t/core/logfile.t
#
# Test the Badger::Log::File module.
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
    tests => 28,
    debug => 'Badger::Log Badger::Log::File',
    args  => \@ARGV;

use Badger::Filesystem '$Bin Dir';
use Badger::Log::File;
use Badger::Timestamp 'Now';
use constant LOG => 'Badger::Log::File';

my $logdir  = Dir($Bin, 'logs')->must_exist(1);
my $logfile = $logdir->file('test.log');

$logfile->delete if $logfile->exists;


#------------------------------------------------------------------------
# create a log file object
#------------------------------------------------------------------------

my $log = LOG->new(
    filename  => $logfile->path,
    keep_open => 1,
    format    => '[<level>] <message>'
);
ok( $log, 'created a first log file object' );
is( $log->debug, 0, 'debug is off' );
is( $log->info, 0, 'info is off' );
is( $log->warn, 1, 'warn is on' );
is( $log->error, 1, 'error is on' );
is( $log->fatal, 1, 'fatal is on' );

ok( $log->error('an error has occurred'), 'error message one' );
ok( $log->error('another error has occurred'), 'error message two' );
ok( $log->warn('this is just a warning'), 'warning one' );
ok( $log->fatal('this is a fatal error'), 'fatal one' );

ok( $logfile->exists, "logfile created: $logfile" );

#-----------------------------------------------------------------------
# check output
#-----------------------------------------------------------------------

my @lines = $logfile->read;
is( scalar(@lines), 4, 'got 4 lines in logfile' );
chomp for @lines;
is( $lines[0], '[error] an error has occurred', 'first error' );
is( $lines[1], '[error] another error has occurred', 'second error' );
is( $lines[2], '[warn] this is just a warning', 'first warning' );
is( $lines[3], '[fatal] this is a fatal error', 'first fatal' );


#-----------------------------------------------------------------------------
# file_format
#-----------------------------------------------------------------------------
my $logfile2 = $logdir->file('test-' . Now->format('%Y-%m-%d-%H-%M-%S') . '.log');
my $logfile3 = $logdir->file('test-' . Now->adjust( seconds => 1 )->format('%Y-%m-%d-%H-%M-%S') . '.log');
my $logfmt   = $logdir->file('test-<DATE>-<TIME>.log')->path;

$logfile2->delete if $logfile2->exists;

$log = LOG->new(
    filename_format => $logfmt,
    keep_open       => 1,
    format          => '[<level>] <message>'
);

ok( $log->error('an error'), 'filename_format error' );
ok( $log->warn('a warning'), 'filename_format warning one' );
ok( $log->fatal('a fatal error'), 'filename_format fatal one' );
ok( $logfile2->exists, "logfile2 created: $logfile2" );

@lines = $logfile2->read;
is( scalar(@lines), 3, 'got 3 lines in logfile2' );
chomp for @lines;
is( $lines[0], '[error] an error', 'filename_format error' );
is( $lines[1], '[warn] a warning', 'filename_format warning' );
is( $lines[2], '[fatal] a fatal error', 'filename_format fatal' );

sleep 1;

ok( $log->error('next logfile'), 'filename_format next logfile' );
ok( $logfile3->exists, "logfile3 created: $logfile3" );

@lines = $logfile3->read;
is( scalar(@lines), 1, 'got 1 line in logfile3' );
chomp for @lines;
is( $lines[0], '[error] next logfile', 'filename_format next logfile' );

$logfile2->delete;
$logfile3->delete;

__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
