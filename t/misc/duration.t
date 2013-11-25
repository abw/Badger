#============================================================= -*-perl-*-
#
# t/misc/duration.t
#
# Test the Badger::Duration module.
#
# Copyright (C) 2013 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ../../lib );
use Badger;
use Badger::Test 
    tests  => 12,
    debug  => 'Badger::Duration',
    args   => \@ARGV;
    
use Badger::Utils 'Duration';

my $d1 = Duration('20s');
is( $d1->text, "20 seconds", '20s is 20 seconds');
is( $d1->seconds, 20, 'there are 20 seconds' );

my $d2 = Duration('5m');
is( $d2->text, "5 minutes", '5m is 5 minutes');
is( $d2->seconds, 300, '5m is 300 seconds');

my $d3 = Duration('1m 20s');
is( $d3->text, "1 minute 20 seconds", '1m 20s is 1 minute 20 seconds');
is( $d3->seconds, 80, '1m 20s is 80 seconds');

my $d4 = Duration('2 hrs, 5 mins and 23 secs');
is( $d4->text, "2 hours 5 minutes 23 seconds", '2 hrs, 5mins and 23 secs is blah blah');

my $d5 = Duration({
    years   => 2,
    months  => 3,
    days    => 5,
    hours   => 7,
    minutes => 11,
    seconds => 13,
});
is( "$d5", "2 years 3 months 5 days 7 hours 11 minutes 13 seconds", 'hashref constructor');

my $d6 = Duration(
    yr      => 3,
    month   => 5,
    d       => 7,
    hr      => 11,
    mins    => 13,
    secs    => 17,
);
is( "$d6", "3 years 5 months 7 days 11 hours 13 minutes 17 seconds", 'params constructor');

my $d7 = Duration('4 hours 20 minutes');
#  1 min  =    60 seconds
# 20 mins =  1200 seconds
# 60 mins =  3600 seconds
# 4 hours = 14400 seconds
# 4h 20m  = 15600 seconds
is( $d7->seconds, 15600, '4 hours 20 minutes is 15600 seconds' );
my $dd = $d7->duration;
is( $dd->{ hour   }, 4, 'duration 4 hours' );
is( $dd->{ minute }, 20, 'duration 20 minutes' );
