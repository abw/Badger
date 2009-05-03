#========================================================================
#
# Badger::Timestamp
#
# DESCRIPTION
#   Simple object representing a date/time and providing methods for 
#   accessing and manipulating various parts of it.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
# COPYRIGHT
#   Copyright (C) 2001-2009 Andy Wardley.  All Rights Reserved.
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#========================================================================

package Badger::Timestamp;

use Badger::Class
    version   => 0.03,
    debug     => 0,
    base      => 'Badger::Base',
    utils     => 'numlike self_params is_object',
    accessors => 'timestamp',
    as_text   => 'timestamp',
    import    => 'class CLASS',
    is_true   => 1,
    constants => 'HASH',
    constant  => {
        TS    => __PACKAGE__,
    },
    exports   => {
        any   => 'TS Timestamp Now',
    },
    messages  => {
        bad_timestamp => 'Invalid timestamp: %s',
        bad_duration  => 'Invalid duration: %s',
    };

use Time::Local;
use POSIX 'strftime';

# Example timestamp: 2006/12/31 23:59:59
our $DATE_REGEX      = qr{ (\d{4})\D(\d{2})\D(\d{2}) }x;
our $TIME_REGEX      = qr{ (\d{2})\D(\d{2})\D(\d{2}) }x;
our $STAMP_REGEX     = qr{ ^\s* $DATE_REGEX (?:(?:T|\s) $TIME_REGEX)? }x;
our $DATE_FORMAT     = '%04d-%02d-%02d';
our $LONGDATE_FORMAT = '%02d-%3s-%04d';
our $TIME_FORMAT     = '%02d:%02d:%02d';
our $STAMP_FORMAT    = "$DATE_FORMAT $TIME_FORMAT";
our @YMD             = qw( year month day );
our @HMS             = qw( hour minute second );
our @SMHD            = qw( second minute hour day );
our @YMDHMS          = (@YMD, @HMS);
our @MONTHS          = qw( xxx Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
our @CACHE           = qw( date time longmonth longdate );
our $SECONDS         = {
    s => 1,
    m => 60,
    h => 60*60,
    d => 60*60*24,
    M => 60*60*24*30,
    y => 60*60*24*365,
};


#-----------------------------------------------------------------------
# Method generator: second()/seconds(), hour()/hours(), etc.
#-----------------------------------------------------------------------

class->methods(
    map {
        my $item  = $_;             # lexical copy for closure
        my $items = $_ . 's';       # provide singular and plural versions
        my $code  = sub {
            if (@_ > 1) {
                $_[0]->{ $item } = $_[1];
                $_[0]->join_timestamp;
                return $_[0];
            }
            return $_[0]->{ $item };
        };
        $item  => $code,
        $items => $code
    }
    @YMDHMS
);


#-----------------------------------------------------------------------
# Constructor subroutines
#-----------------------------------------------------------------------

sub Timestamp { 
    return @_ 
        ? TS->new(@_)
        : TS
}

sub Now { 
    TS->now;
}


#-----------------------------------------------------------------------
# Methods
#-----------------------------------------------------------------------

sub new {
    my $class = shift; 
    my $self  = bless { map { ($_, 0) } @YMDHMS }, ref $class || $class;
    my ($config, $time);
    
    if (@_ > 1) {
        # multiple arguments are named params
        $config = { @_ };
    }
    elsif (@_ == 1 && defined $_[0]) {
        # single argument is a hash of named params, a timestamp or time in
        # seconds since the epoch
        $config = ref $_[0] eq HASH ? shift : { time => shift };
    }
    # otherwise we default to now
    else {
        $config = { time => time() };
    }

    if ($time = $config->{ time }) {
        if (numlike $time) {
            # $time is seconds since epoch
            (@$self{ @YMDHMS }) = reverse( ( localtime($time) )[0..5] );
            $self->{ year  }+= 1900;
            $self->{ month }++;
        }
        elsif (is_object(ref $class || $class, $time)) {
            $self->{ timestamp } = $time->timestamp;
            $self->split_timestamp;
        }
        else {
            # $time is a timestamp so split and rejoin into canonical form
            $self->{ timestamp } = $time;
            $self->split_timestamp;
        }
        $self->join_timestamp;
    }
    else {
        # set any fields defined in config, allowing singular (second,month,
        # etc) and plural (seconds, months, etc)
        foreach my $field (@YMDHMS) {
            $self->{ $field } = $config->{ $field } || $config->{"${field}s"} || 0;
        }
    }
    return $self;
}

sub now {
    shift->new;
}

sub copy {
    my $self = shift;
    $self->new( $self->{ timestamp } );
}

sub split_timestamp {
    my $self = shift;
    $self->{ timestamp } = '' unless defined $self->{ timestamp };

    # TODO: this regex should be tweaked to make time (and/or date parts) optional
    (@$self{ @YMDHMS } = $self->{ timestamp } =~ m/$STAMP_REGEX/o)
        || return $self->error_msg( bad_timestamp => $self->{ timestamp } );
}

sub join_timestamp {
    my $self = shift;
    return ($self->{ timestamp } = sprintf($STAMP_FORMAT, @$self{ @YMDHMS }));
}

sub epoch_time {
    my $self = shift;
    return timelocal(
        @$self{@SMHD}, 
        $self->{ month } - 1, 
        $self->{ year  } - 1900
    );
}

sub format {
    my $self = shift;
    my $fmt  = shift;
    return strftime($fmt, @$self{@SMHD}, $self->{ month } - 1, $self->{ year } - 1900);
}

sub _OLD_longmonth {
    my $self = shift;
    return $self->{ longmonth }
       ||= $MONTHS[$self->{ month }];
}

sub _OLD_longdate {
    my $self = shift;
    # init the longmonth value
    $self->longmonth;
    return $self->{ longdate }
       ||= sprintf( $LONGDATE_FORMAT, @$self{ qw( day longmonth year ) } );
}

sub date {
    my $self = shift;
    return $self->{ date } 
       ||= sprintf( $DATE_FORMAT, @$self{ @YMD } );
}

sub time {
    my $self = shift;
    return $self->{ time } 
       ||= sprintf( $TIME_FORMAT, @$self{ @HMS });
}

sub adjust {
    my $self = shift;
    my ($args, $element, $dim);
    my $fix_month = 0;

    if (@_ == 1) {
        # single argument can be a reference to a hash: { days => 3, etc }
        # or a number/string representing a duration: "3 days", "1 year"
        $args = ref $_[0] eq HASH 
            ? shift
            : { seconds => $self->duration(shift) };
    }
    else {
        # multiple arguments are named parameters: days => 3, etc.
        $args = { @_ };
    }

    # If we're only adjusting by a month or a year, then we fix the day 
    # within the range of the number of days in the new month.  For example:
    # 2007-01-31 + 1 month = 2007-02-28.  We must handle this for a year
    # adjustment for the case: 2008-02-29 + 1 year = 2009-02-28
    if ((scalar(keys %$args) == 1) &&
        (defined $args->{ month } || defined $args->{ months } ||
         defined $args->{ year }  || defined $args->{ years })) {
        $fix_month = 1;
    }

    $self->debug("adjust: ", $self->dump_data($args)) if DEBUG;
    
    # allow each element to be singular or plural: day/days, etc.
    foreach $element (@YMDHMS) {
        $args->{ $element } = $args->{ "${element}s" }
            unless defined $args->{ $element };
    }

    # adjust the time by the parameters specified
    foreach $element (@YMDHMS) {
        $self->{ $element } += $args->{ $element }
            if defined $args->{ $element };
    }

    # Handle negative seconds/minutes/hours
    while ($self->{ second } < 0) {
        $self->{ second } += 60;
        $self->{ minute }--;
    }
    while ($self->{ minute } < 0) {
        $self->{ minute } += 60;
        $self->{ hour   }--;
    }
    while ($self->{ hour } < 0) {
        $self->{ hour   } += 24;
        $self->{ day    }--;
    }

    # now positive seconds/minutes/hours
    if ($self->{ second } > 59) {
        $self->{ minute } += int($self->{ second } / 60);
        $self->{ second } %= 60;
    }
    if ($self->{ minute } > 59) {
        $self->{ hour   } += int($self->{ minute } / 60);
        $self->{ minute } %= 60;
    }
    if ($self->{ hour   } > 23) {
        $self->{ day    } += int($self->{ hour } / 24);
        $self->{ hour   } %= 24;
    }

    # Handle negative days/months/years
    while ($self->{ day } <= 0) {
        $self->{ month }--;
        unless ($self->{ month } > 0) {
            $self->{ month } += 12;
            $self->{ year  }--;
        }
        $self->{ day } += $self->days_in_month;
    }
    while ($self->{ month } <= 0) {
        $self->{ month } += 12;
        $self->{ year } --;
    }
    while ($self->{ month } > 12) {
        $self->{ month } -= 12;
        $self->{ year  } ++;
    }

    # handle day wrap-around
    while ($self->{ day } > ($dim = $self->days_in_month)) {
        # If we're adjusting by a single month or year and the day is 
        # greater than the number days in the new month, then we adjust
        # the new day to be the last day in the month.  Otherwise we 
        # increment the month and remove the number of days in the current
        # month. 
        if ($fix_month) {
            $self->{ day } = $dim;
        } 
        else {
            $self->{ day } -= $dim;
            if ($self->{ month } == 12) {
                $self->{ month } = 1;
                $self->{ year  }++;
            }
            else {
                $self->{ month }++;
            }
        }
    }

    $self->uncache;
    $self->join_timestamp;
    
    return $self;
}

sub duration {
    my ($self, $duration) = @_;

    # $duration can be a number, assumed to be seconds
    return $duration 
        if numlike($duration);

    # Otherwise the $duration should be of the form "3 minutes".  We only 
    # look at the first character of the word (e.g. "3 m"), which creates a
    # potential conflict between "m(inute) and m(onth)".  So we use a capital
    # 'M' for month.  This is based on code by Mark Fisher in CGI.pm.  

    $duration =~ s/month/Month/i;

    # TODO: make this parser a bit smarter so we can support multiple
    # items (e.g. "2 hours 30 minutes") as per adjust()
    if ($duration =~ /^ ( -? (?: \d+ | \d*\.\d+ ) ) \s* ([smhdMy]?) /x) {
        return ($SECONDS->{ $2 } || 1) * $1;
    } 
    else {
        return $self->error_msg( bad_duration => $duration );
    }
}

sub uncache {
    my $self = shift;
    delete @$self{@CACHE};
    return $self;
}

sub compare {
    my $self = shift;
    my $comp = @_ && is_object(ref $self || $self, $_[0]) ? shift : $self->new(@_);

    foreach my $item (@YMDHMS) {
        if ($self->{ $item } < $comp->{ $item }) {
            return -1;  # -1 - self earlier than comparison timestamp
        }
        elsif ($self->{ $item } > $comp->{ $item }) {
            return 1;   #  1 - self later than comparison timestamp
        }
    }
    return 0;           #  0 - same time
}

sub before {
    my $self = shift;
    return $self->compare(@_) == -1;
}

sub after {
    my $self = shift;
    return $self->compare(@_) == 1;
}

sub days_in_month {
    my $self  = shift;
    my $month = shift || $self->{ month };
    if ($month == 4 || $month == 6 || $month == 9 || $month == 11) {
        return 30;
    }
    elsif ($month == 2) {
        return $self->leap_year(@_) ? 29 : 28;
    }
    else {
        return 31;
    }
}

sub leap_year {
    my $self = shift;
    my $year = shift || $self->{ year };
    if ($year % 4) {
        return 0;
    }
    elsif ($year % 400 == 0) {
        return 1;
    }
    elsif ($year % 100 == 0) {
        return 0;
    }
    else {
        return 1;
    }
}


1;
__END__

=head1 NAME

Badger::Timestamp - object representation of a timestamp

=head1 SYNOPSIS

    use Badger::Timestamp;
    
    # timestamp defaults to date/time now
    my $stamp = Badger::Timestamp->new();
    my $stamp = Badger::Timestamp->now();   # alias to new()
    
    # construct from seconds since epoch
    my $stamp = Badger::Timestamp->new($epoch_seconds);
    
    # or from ISO-8601 timestamp (or similar)
    my $stamp = Badger::Timestamp->new('2006-03-19 04:20:42');
    
    # or from individual arguments
    my $stamp = Badger::Timestamp->new(
        year    => 2006,
        month   => 3,
        day     => 19
        hours   => 4
        minutes => 20
        seconds => 42
    );
    
    # overloaded stringification operator calls timestamp() method
    print $stamp->timestamp;                # 2006-03-19 04:20:42
    print $stamp;                           # 2006-03-19 04:20:42
    
    # format using strftime()
    print $stamp->format('%d-%b-%y');
        
    # methods to access parts of date and time - in both singular
    # (month, year, etc) and plural (months, years, etc) forms
    print $stamp->date;                     # 2006-03-19
    print $stamp->year;                     # 2006
    print $stamp->month;                    # 03
    print $stamp->day;                      # 19
    print $stamp->time;                     # 04:20:42
    print $stamp->hours;                    # 04
    print $stamp->minutes;                  # 20
    print $stamp->seconds;                  # 42
    
    # update parts of date/time
    $stamp->year(2007);
    print $stamp;                           # 2007-03-19 04:20:42
    
    # adjust date/time
    $stamp->adjust( months => 3  );         # 3 months time
    $stamp->adjust( days   => 60 );         # 60 days time
    $stamp->adjust( hours  => -3 );         # 3 hours ago
    
    # comparisons
    $stamp->compare($epoch_seconds);        # returns -1/0/1
    $stamp->compare($timestamp_string);
    $stamp->compare($timestamp_object);
    $stamp->compare( year => 2006, month => 03, ...etc... );
    $stamp->compare($hash_ref_of_named_params);
    
    $stamp->before($any_of_the_above);      # returns 1/0
    $stamp->after($any_of_the_above);       # returns 1/0

=head1 DESCRIPTION

This module implements a small and simple object for representing a moment in
time. Its scope is intentionally limited to the kind of applications that
require very basic date and time functionality with minimal overhead. A
typical example would be a CGI script or library generating a timestamp for a
cookie, or printing out a "last modified" at the bottom of a web page.

For any non-trivial date manipulation you should almost certainly be using
the most excellent L<DateTime> modules instead.

The goals of this implementation are:

=over 4

=item *

To provide an OO wrapper of convenience around the core date and time 
functions and modules (C<time()>, C<localtime()>, C<strftime()>, etc).

=item * 

To parse timestamps in ISO-8601 format (and formats sufficiently similar to
it), such as those used to store timestamps in databases. e.g.
2009-04-20T04:20:00.

=item *

To grok epoch times (seconds since lst January 1970) such as those used
for file modification times.

=item *

To perform basic date manipulation, e.g adding or subtracting days, months, 
years, etc., such as you might want to do when constructing expiry dates
for web content, cookies, etc.

=item *

To perform simple date comparisons, e.g. so that you can see if one of the 
previously mentioned expiry dates has lapsed.

=back

The module is derived from the Template Toolkit date plugin. It was moved out
into stand-alone module in 2006 for use in various commercial projects. It was
made fully generic and moved into the L<Badger> fold in January 2009.

Please note that this documentation may be incorrect or incomplete in places.

=head1 EXPORTABLE SUBROUTINES

=head2 TS

This is a shortcut alias to C<Badger::Timestamp>.

    use Badger::Timestamp 'TS';
    
    my $ts = TS->new();         # same as Badger::Timestamp->new();

=head2 Timestamp()

This subroutine returns the name of the C<Badger::Timestamp> class when called
without arguments. Thus it can be used as an alias for C<Badger::Timestamp>
as per L<TS>.

    use Badger::Timestamp 'Timestamp';
    
    my $ts = Timestamp->new();  # same as Badger::Timestamp->new();

When called with arguments, it creates a new C<Badger::Timestamp> object.

    my $ts = Timestamp($date);  # same as Badger::Timestamp->new($date);

=head2 Now()

Returns a C<Badger::Timestamp> for the current time.

=head1 METHODS

=head2 new($timestamp)

Constructor method to create a new C<Badger::Timestamp> object
from a timestamp string or seconds since the epoch.

The timestamp should be specified as a date and time separated by a single
space or upper case C<T>.  The date should contain 4 digits for the year and
two for each of the month and day separated by any non-numerical characters.
The time is comprised of two digits for each of the hours, minutes and seconds,
also separated by any non-numerical characters.

    # examples of valid formats
    my $stamp = Badger::Timestamp->new('2006-03-19 04:20:42');
    my $stamp = Badger::Timestamp->new('2006-03-19T04:20:42');
    my $stamp = Badger::Timestamp->new('2006/03/19 04:20:42');
    my $stamp = Badger::Timestamp->new('2006/03/19T04:20:42');

The C<Badger::Timestamp> module converts these to the canonical form
of C<YYYY-MM-DD HH:MM:SS>

    my $stamp = Badger::Timestamp->new('2006/03/19T04.20.42');
    print $stamp;       # 2006-03-19 04:20:42

You can also construct a C<Badger::Timestamp> object by specifying the 
number of seconds since the epoch.  This is the value return by system
functions like C<time()> and used for file creation/modification times.

    my $stamp = Badger::Timestamp->new(time());

Or can can pass it an existing C<Badger::Timestamp> object.

    my $stamp2 = Badger::Timestamp->new($stamp);

If you don't specify any argument then you get the current system time as
returned by C<time()>.

    my $now = Badger::Timestamp->new;

=head2 now()

Returns a C<Badger::Timestamp> object representing the current date and
time.

=head2 copy()

Returns a new C<Badger::Timestamp> object creates as a copy of the 
current one.

    my $copy = $stamp->copy;

This can be useful for making adjustments to a timestamp without affecting
the original object.

    my $later = $stamp->copy->adjust( months => 3 );

=head2 timestamp()

Returns the complete timestamp in canonical form.

    print $stamp->timestamp();  # 2006-03-19 04:20:42

This method is called automatically whenever the object is
used as a string value.

    print $stamp;               # 2006-03-19 04:20:42

=head2 format($format)

Returns a formatted version of the timestamp, generated using the L<POSIX>
strftime function.

    print $stamp->format('%d-%b-%y');

=head2 date()

Returns the date component of the timestamp.

    print $stamp->date();       # 2006-03-19

=head2 year() / years()

Returns the year.

    print $stamp->year();       # 2006

Can also be called with an argument to change the year.

    $stamp->year(2007);

=head2 month() / months()

Returns the month.

    print $stamp->month();      # 03

Can also be called with an argument to change the yonth.

    $stamp->month(04);

=head2 day() / days()

Returns the day.

    print $stamp->day();        # 19

Can also be called with an argument to change the day.

    $stamp->day(20);

=head2 days_in_month()

Returns the number of days in the current month.  Accounts correctly
for leap years.

=head2 leap_year()

Returns a true value (1) if the year is a leap year, a false value (0) if not.

=head2 time()

Returns the time component of the timestamp.

    print $stamp->time();       # 04:20:42

=head2 hour() / hours()

Returns the hours.

    print $stamp->hours();      # 04

Can also be called with an argument to change the hours.

    $stamp->hours(05);

=head2 minute() / minutes()

Returns the minutes.

    print $stamp->minutes();    # 20

Can also be called with an argument to change the minutes.

    $stamp->minutes(21);

=head2 second() / seconds()

Returns the seconds.

    print $stamp->seconds();    # 42

Can also be called with an argument to change the seconds.

    $stamp->seconds(42);

=head2 epoch_time()

Returns the timestamp object as the number of seconds since the epoch time.

=head2 before($when)

Returns a true value (1) if the date is before the date passed as an argument,
a false value (0) otherwise.

The method can be passed another C<Badger::Timestamp> object to compare
against or an argument or arguments from which a C<Badger::Timestamp> object
can be constructed. If no arguments are passed then it defaults to a
comparison against the current time.

    my $date = Badger::Timestamp->new('2009-01-10 04:20:00');
    
    $date->before($another_date_object);       
    $date->before('2009-04-20 04:20:00');
    $date->before($epoch_seconds);
    $date->before;                          # before now

=head2 after($when)

Returns a true value (1) if the date is after the date passed as an argument,
a false value (0) otherwise.  See L<before()>,

=head2 compare($when)

Returns -1 if the date is before the date passed as an argument, 1 if it's
after, or 0 if it's equal.  See L<before()> and L<after> for examples of
the arguments that it accepts.

=head2 adjust(%adjustments)

Method to adjust the timestamp by a fixed amount or amounts.

    # positive adjustment
    $date->adjust( months => 6, years => 1 );
    
    # negative adjustment
    $date->adjust( months => -18, hours => -200 );

Named parameters can be passed as arguments or via a hash reference.

    $date->adjust(  months => -18, hours => -200  );        # naked
    $date->adjust({ months => -18, hours => -200 });        # clothed

You can specify units using singular (second, hour, month, etc) or plural
(seconds, hours, minutes, etc) keys. The method will correctly handle values
outside the usual ranges. For example, you can specify a change of 18 months,
-200 hours, -99 seconds, and so on.

A single non-reference argument is assumed to be a duration which is 
converted to a number of seconds via the L<duration()> method.

=head2 duration($duration)

Returns the number of seconds in a duration. A single numerical argument is
assumed to be a number of seconds and is returned unchanged.

    $date->adjust(300);     # 300 seconds

A single non-numerical argument should have a suffix indicating the units.
In "compact form" this is a single letter.  We use lower case C<m> for 
minutes and upper case C<M> for months.

    $date->adjust("300s");  # or "300 seconds"
    $date->adjust("90m");   # or "90 minutes"
    $date->adjust("3h");    # or "3 hours"    
    $date->adjust("2d");    # or "2 days"
    $date->adjust("6M");    # or "6 months"   
    $date->adjust("5y");    # or "5 years"

Alternately you can spell the units out in full as shown in the right
column above.  However, we only look at the first character of the following
word so you can write all sorts of nonsense which we will dutifully accept
without complaint.

    $date->adjust("5 sheep");   # 5 seconds
    $date->adjust("9 men");     # 9 minutes
    $date->adjust("3 yaks");    # 3 years

For the sake of convenience, the method will automatically convert the 
word C<month> into C<Month> so that the first letter is correctly capitalised.

=head1 INTERNAL METHODS

=head2 split_timestamp()

Splits a timestamp into its constituent parts.

=head2 join_timestamp()

Joins the constituent parts of a date back into a timestamp.

=head2 uncache()

Removes any internally cached items.  This is called automatically whenever
the timestamp is modified.

=head1 AUTHOR

Andy Wardley L<http://wardley.org>

=head1 COPYRIGHT

Copyright (C) 2001-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
