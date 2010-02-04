#============================================================= -*-perl-*-
#
# t/core/timestamp.t
#
# Test the Badger::Timestamp module.
#
# Copyright (C) 2006-2009 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Test 
    tests  => 168, 
    debug  => 'Badger::Timestamp',
    args   => \@ARGV;
    
use Badger::Timestamp 'Timestamp TS Now';
use Badger::Utils 'refaddr';


#-----------------------------------------------------------------------
# check we barf on invalid dates
#-----------------------------------------------------------------------

eval { Timestamp->new('foobar') };
is( $@, 'timestamp error - Invalid timestamp: foobar', 'bad timestamp format');
my $n = 1;


#-----------------------------------------------------------------------
# check timestamp created now
#-----------------------------------------------------------------------

my $now = Timestamp->new();
my ($second, $minute, $hour, $day, $month, $year ) = localtime(time());
$year += 1900;
$month++;
is($now->day(), $day, 'day now' );
is($now->month(), $month, 'month now' );
is($now->year(), $year, 'year now' );
is($now->hour(), $hour, 'hour now' );
is($now->minute(), $minute, 'minute now' );

$now = Timestamp->now;
ok( $now, 'got now() timestamp' );

$now = Now;
ok( $now, 'got Now() timestamp' );


#-----------------------------------------------------------------------
# check timestamp parsing
#-----------------------------------------------------------------------

foreach my $timestamp (
    '2006/08/04 21:22:23',
    '2006-08-04 21:22:23',
    '2006-08-04T21:22:23',
    ) {
    my $stamp = Timestamp->new($timestamp);
    ok( $stamp, "created timestamp $n" );
    is( "$stamp", '2006-08-04 21:22:23', "timestamp $n string" );
    is( $stamp->timestamp(), '2006-08-04 21:22:23', "timestamp() $n" );
    is( $stamp->date(), '2006-08-04', "date() $n" );
    is( $stamp->year(), '2006', "year() $n" );
    is( $stamp->month(), '08', "month() $n" );
    is( $stamp->day(), '04', "day() $n" );
    is( $stamp->time(), '21:22:23', "time() $n" );
    is( $stamp->hours(), '21', "hours() $n" );
    is( $stamp->minutes(), '22', "hours() $n" );
    is( $stamp->seconds(), '23', "minutes() $n" );
    $n++;
}    

#-----------------------------------------------------------------------
# check short numbers work
#-----------------------------------------------------------------------
my $short = Timestamp->new('2010/2/5 4:20:42');
ok( $short, 'created timestamp with short numbers');
is( $short->time, '04:20:42', 'got time' );
is( $short->date, '2010-02-05', 'got date' );


#-----------------------------------------------------------------------
# check named parameters work
#-----------------------------------------------------------------------

my $time = Timestamp->new( hour => 1, minute => 2, second => 3 );
is( $time->hour, 1, 'set 1 hour' );
is( $time->minute, 2, 'set 2 minute' );
is( $time->second, 3, 'set 3 second' );

$time = Timestamp->new( hours => 4, minutes => 5, seconds => 6 );
is( $time->hours, 4, 'set 4 hours' );
is( $time->minutes, 5, 'set 5 minutes' );
is( $time->seconds, 6, 'set 6 seconds' );

my $date = Timestamp->new( day => 7, month => 8, year => 2009 );
is( $date->date, '2009-08-07', 'set day' );


#-----------------------------------------------------------------------
# check we can change items
#-----------------------------------------------------------------------

my $stamp = Timestamp->new('2006-03-19 04:20:42');
ok( $stamp, 'created new timestamp' );
ok( $stamp->year(2007), 'changed year' );
is( $stamp, '2007-03-19 04:20:42', 'new year set' );
ok( $stamp->month(04), 'changed month' );
is( $stamp, '2007-04-19 04:20:42', 'new month set' );
ok( $stamp->day(20), 'changed year' );
is( $stamp, '2007-04-20 04:20:42', 'new day set' );
ok( $stamp->hours(05), 'changed hours' );
is( $stamp, '2007-04-20 05:20:42', 'new hours set' );
ok( $stamp->minutes(21), 'changed minutes' );
is( $stamp, '2007-04-20 05:21:42', 'new minutes set' );
ok( $stamp->seconds(43), 'changed seconds' );
is( $stamp, '2007-04-20 05:21:43', 'new seconds set' );

#-----------------------------------------------------------------------
# test the adjust() method
#-----------------------------------------------------------------------

is( $stamp->adjust( year => 1, month => 2, day => 3, 
                    hours => 4, minutes => 5, seconds => 6 ), $stamp, 'adjusted time' );
is( $stamp, '2008-06-23 09:26:49', 'time adjusted' );

# roll over a minute, hour, day, and so on
is( $stamp->adjust( seconds => 12 ), '2008-06-23 09:27:01', 'rolled over minute' );
is( $stamp->adjust( minutes => 32, seconds => 63 ), '2008-06-23 10:00:04', 'rolled over hour' );
is( $stamp->adjust( hours => 20 ), '2008-06-24 06:00:04', 'rolled over day' );
is( $stamp->adjust( day => 8 ), '2008-07-02 06:00:04', 'rolled over 30 day month' );
is( $stamp->adjust( days => 30 ), '2008-08-01 06:00:04', 'rolled over 31 day month' );

# try with single argument 
is( $stamp->adjust("3 days"), '2008-08-04 06:00:04', 'adjust 3 days' );
#is( $stamp->adjust("-1 month"), '2008-07-04 06:00:04', 'adjust -1 month' );
is( $stamp->adjust(month => -1), '2008-07-04 06:00:04', 'adjust -1 month' );
is( $stamp->adjust("-4 days"), '2008-06-30 06:00:04', 'adjust -4 days' );



#-----------------------------------------------------------------------
# test leap_year() and days_in_month() 
#-----------------------------------------------------------------------

$stamp = Timestamp('2008-08-01 06:00:04');

ok( ! $stamp->leap_year(1900), 'not leap year 1900' );
ok( ! $stamp->leap_year(1999), 'not leap year 1999' );
ok(   $stamp->leap_year(2000), 'leap year 2000' );
ok( ! $stamp->leap_year(2001), 'not leap year 2001' );
ok( ! $stamp->leap_year(2002), 'not leap year 2002' );
ok( ! $stamp->leap_year(2003), 'not leap year 2003' );
ok( $stamp->leap_year(2004), 'leap year 2004' );
ok( ! $stamp->leap_year(2005), 'leap year 2005' );

is( $stamp->days_in_month(), 31, 'august has 31 days' );
is( $stamp->days_in_month(1), 31, 'january has 31 days' );
is( $stamp->days_in_month(2, 2003), 28, 'january has 28 days in 2003' );
is( $stamp->days_in_month(2, 2004), 29, 'january has 29 days in 2004' );
is( $stamp->days_in_month(3), 31, 'march has 31 days' );
is( $stamp->days_in_month(4), 30, 'april has 30 days' );
is( $stamp->days_in_month(5), 31, 'may has 31 days' );
is( $stamp->days_in_month(6), 30, 'june has 30 days' );
is( $stamp->days_in_month(7), 31, 'july has 31 days' );
is( $stamp->days_in_month(8), 31, 'august has 31 days' );
is( $stamp->days_in_month(9), 30, 'september has 30 days' );
is( $stamp->days_in_month(10), 31, 'october has 31 days' );
is( $stamp->days_in_month(11), 30, 'november has 30 days' );
is( $stamp->days_in_month(12), 31, 'december has 31 days' );


#-----------------------------------------------------------------------
# test compare() method
#-----------------------------------------------------------------------

$stamp= Timestamp->new();
$stamp->adjust( second => -1 );
is( $stamp->compare(time()), -1, 'compare earlier than now' );
$stamp->adjust( minute => 1 );
is( $stamp->compare(time()), 1, 'compare later than now' );

$stamp = Timestamp->new();
my $compare = Timestamp->new($stamp);

is( $stamp->compare($compare), 0, 'compare the same' );
foreach my $item (qw(second minute hour day month year )) {
    $stamp->adjust( $item => -1 );
    is( $stamp->compare($compare), -1, "$stamp $item earlier $compare" );
    $stamp->adjust( $item => 2 );
    is( $stamp->compare($compare), 1, "$stamp $item later $compare" );
}


#-----------------------------------------------------------------------
# test before(), after() and equal()
#-----------------------------------------------------------------------

my $old = Timestamp->new('2009-07-05 12:47:42');
my $new = Timestamp->new('2009-07-05 16:20:00');
ok( $old->equal($old), 'old is equal to old' );
ok( $new->equal($new), 'new is equal to new' );
ok( $old->not_equal($new), 'old is not equal to new' );
ok( $new->not_equal($old), 'new is not equal to old' );

# before/after/compare/equal all accept another timestamp...
ok( $old->before($new), 'old is before new' );
ok( $new->after($old), 'new is after old' );

# ...or a time in epoch seconds...
ok( $old->before($new->epoch_time), 'old is before new epoch time' );
ok( $new->after($old->epoch_time), 'new is after old epoch time' );

# ...or a timestamp...
ok( $old->before($new->timestamp), 'old is before new epoch timestamp' );
ok( $new->after($old->timestamp), 'new is after old epoch timestamp' );

# ...or a set of named params
ok( $old->before( year => 2010 ), 'old is before new year' );
ok( $new->after( year => 1969 ), 'new is after old year' );

# test some negatives to make sure we're not using rose tinted methods
ok( ! $new->equal($old), 'new is not equal to old' );
ok( ! $old->equal($new), 'old is not equal to new' );
ok( ! $new->before($old), 'new is not before old' );
ok( ! $old->after($new), 'old is not after new' );
ok( ! $new->equal($old), 'new is not equal to old' );
ok( ! $old->equal($new), 'old is not equal to new' );
ok( ! $new->before($old->epoch_time), 'new is not before old epoch time' );
ok( ! $old->after($new->epoch_time), 'old is not after new epoch time' );
ok( ! $new->equal($old->epoch_time), 'new is not equal to old epoch time' );
ok( ! $old->equal($new->epoch_time), 'old is not equal to new epoch time' );


#-----------------------------------------------------------------------
# test comparison operators
#-----------------------------------------------------------------------

ok( $old == $old, 'old == old' );
ok( $new == $new, 'new == new' );
ok( $old != $new, 'old != new' );
ok( $new != $old, 'new != old' );
ok( $old < $new, 'old < new' );
ok( $new > $old, 'new > old' );
ok( $old <= $new, 'old <= new' );
ok( $new >= $old, 'new >= old' );
ok( $old <= $old, 'old <= old' );
ok( $new >= $new, 'new >= new' );

ok( ! ($old != $old), 'old != old is false' );
ok( ! ($new != $new), 'new != new is false' );
ok( ! ($old == $new), 'old == new is false' );
ok( ! ($new == $old), 'new == old is false' );
ok( ! ($old > $new), 'old > new is false' );
ok( ! ($new < $old), 'new < old is false' );
ok( ! ($old >= $new), 'old >= new is false' );
ok( ! ($new <= $old), 'new <= old is false' );


#-----------------------------------------------------------------------
# test epoch_seconds()
#-----------------------------------------------------------------------

$now   = time();
$stamp = Timestamp->new($now); 
my $epoch = $stamp->epoch_time();
is( $now, $epoch, 'epoch_time()' );


#-----------------------------------------------------------------------
# test month rollover
#-----------------------------------------------------------------------

$stamp = Timestamp->new();
#print "NOW: $stamp\n";
$stamp->adjust( months => 12 );
#print "ONE YEAR FROM NOW: $stamp (", $stamp->longmonth(), ")\n";


#-----------------------------------------------------------------------
# test format() method
#-----------------------------------------------------------------------

$stamp = Timestamp->new('2005-06-07 08:09:10');
is( $stamp->format('%Y/%m/%d'), '2005/06/07', 'format test date' );
is( $stamp->format('%Hh %Mm %Ss'), '08h 09m 10s', 'format test time' );


#-----------------------------------------------------------------------
# test copy constructor
#-----------------------------------------------------------------------

my $copy = Timestamp->new($stamp);
ok( $copy, 'created object from object' );
is( $copy->compare($stamp), 0, 'copy same as original' );

my $other = $copy->copy;
ok( $other, 'created new object from object new() method' );
is( $other->compare($copy), 0, 'new object same as original' );

isnt( refaddr($stamp), refaddr($copy), 'copy is new object' );
isnt( refaddr($stamp), refaddr($other), 'new is new object' );


#-----------------------------------------------------------------------
# check Timestamp also works as constructor subroutine
#-----------------------------------------------------------------------

my $substamp = Timestamp('2009/01/10 19:11:12');
ok( $substamp, 'created timestamp via Timestamp() subroutine' );
is( $substamp->date, '2009-01-10', "Timestamp() date" );
is( $substamp->year, '2009', "Timestamp() year" );
is( $substamp->month, '01', "Timestamp() month" );


#-----------------------------------------------------------------------
# check TS is an alias to module name
#-----------------------------------------------------------------------

my $tstamp = TS->new('2009/01/10 19:14:12');
ok( $tstamp, 'created timestamp via Timestamp() subroutine' );
is( $tstamp->date, '2009-01-10', "TS stamp date" );
is( $tstamp->year, '2009', "TS stamp year" );
is( $tstamp->minutes, '14', "TS stamp month" );

__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
