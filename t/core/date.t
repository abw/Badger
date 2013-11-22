#============================================================= -*-perl-*-
#
# t/core/date.t
#
# Test the Badger::Date module.
#
# Copyright (C) 2006-2012 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Test 
    tests  => 16, 
    debug  => 'Badger::Date',
    args   => \@ARGV;
    
use Badger::Date 'Date Today';


#-----------------------------------------------------------------------
# check we barf on invalid dates
#-----------------------------------------------------------------------

eval { Date->new('foobar') };
is( $@, 'date error - Invalid date: foobar', 'bad date format');
my $n = 1;


#-----------------------------------------------------------------------
# check date created now
#-----------------------------------------------------------------------

my $today = Today;
ok( $today, 'created a day today' );
print "today: ", $today->text, "\n";
print "today: ", $today->uri, "\n";

my ($second, $minute, $hour, $day, $month, $year ) = localtime(time());
$year += 1900;
$month++;
is($today->day, $day, 'day today' );
is($today->month, $month, 'month today' );
is($today->year, $year, 'year today' );


my $tomorrow = $today->copy->adjust( days => 1 );
print "tomorrow: $tomorrow\n";

ok( $tomorrow->after($today), "tomorrow is after today" );
ok( $today->before($tomorrow), "today is before tomorrow" );
ok( ! $tomorrow->before($today), "tomorrow is not before today" );
ok( ! $today->after($tomorrow), "today is not after tomorrow" );
ok( $tomorrow->not_before($today), "tomorrow is not_before today" );
ok( $today->not_after($tomorrow), "today is not_after tomorrow" );


ok( $tomorrow > $today, "tomorrow > today" );
ok( $today < $tomorrow, "today < tomorrow" );
ok( !( $tomorrow < $today ), "not tomorrow < today" );
ok( !( $today > $tomorrow ), "not today > tomorrow" );

