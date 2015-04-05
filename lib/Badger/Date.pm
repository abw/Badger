package Badger::Date;

use Badger::Class
    version   => 0.03,
    debug     => 0,
    import    => 'class CLASS',
    base      => 'Badger::Period',
    utils     => 'numlike is_object',
    accessors => 'uri',
    constants => 'HASH',
    constant  => {
        DATE        => __PACKAGE__,
        TYPE_NAME   => 'date',
        FIELD_NAMES => q{year month day},
        split_regex => qr{(\d{4})\D(\d{1,2})\D(\d{1,2})},
        join_format => q{%04d-%02d-%02d},
    },
    exports   => {
        any   => 'DATE Date Today',
    };

our @YMD   = qw( year month day );
our @CACHE = qw( date time etime longmonth longdate uri );


#-----------------------------------------------------------------------
# Method generator: year()/years(), month()/months(), day()/days()
#-----------------------------------------------------------------------

class->methods(
    map {
        my $item  = $_;             # lexical copy for closure
        my $items = $_ . 's';       # provide singular and plural versions
        my $code  = sub {
            if (@_ > 1) {
                $_[0]->{ $item } = $_[1];
                $_[0]->join_uri;
                return $_[0];
            }
            return $_[0]->{ $item };
        };
        $item  => $code,
        $items => $code
    }
    @YMD
);


#-----------------------------------------------------------------------
# Constructor subroutines
#-----------------------------------------------------------------------

sub Date {
    return @_
        ? DATE->new(@_)
        : DATE
}

sub Today {
    DATE->today;
}


#-----------------------------------------------------------------------
# Methods
#-----------------------------------------------------------------------

sub today {
    shift->new;
}


sub date {
    shift->text;
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
    foreach $element (@YMD) {
        $args->{ $element } = $args->{ "${element}s" }
            unless defined $args->{ $element };
    }

    # adjust the time by the parameters specified
    foreach $element (@YMD) {
        $self->{ $element } += $args->{ $element }
            if defined $args->{ $element };
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
    $self->join_uri;

    return $self;
}


sub uncache {
    my $self = shift;
    delete @$self{@CACHE};
    return $self;
}


1;
__END__

=head1 NAME

Badger::Date - simple object representation of a date

=head1 SYNOPSIS

    use Badger::Date;

    # date defaults to today to date/time now
    my $date = Badger::Date->new();
    my $date = Badger::Date->today();

    # or from ISO-8601 date (or similar)
    my $stamp = Badger::Date->new('2015-03-19');

    # or from individual arguments
    my $date = Badger::Date->new(
        year    => 2015,
        month   => 3,
        day     => 19
    );

=head1 DESCRIPTION

This module implements a small and simple object for representing a date.
Its scope is intentionally limited to the kind of applications that
require very basic date functionality with minimal overhead.

For any non-trivial date manipulation you should almost certainly be using
the most excellent L<DateTime> modules instead.

This code is derived from L<Badger::Timestamp>.

=head1 EXPORTABLE SUBROUTINES

=head2 DATE

This is a shortcut aliases to C<Badger::Date>.

    use Badger::Date 'DATE';

    my $date = DATE->new();         # same as Badger::Date->new();

=head2 Date()

This subroutine returns the name of the C<Badger::Date> class when called
without arguments. Thus it can be used as an alias for C<Badger::Date>
as per L<DATE>.

    use Badger::Date 'Date';

    my $ts = Date->new();  # same as Badger::Date->new();

When called with arguments, it creates a new C<Badger::Date> object.

    my $ts = Date($date);  # same as Badger::Date->new($date);

=head2 Today()

Returns a C<Badger::Date> for the current date.

=head1 METHODS

=head2 new('YYYY-MM-DD')

Constructor method to create a new C<Badger::Date> object
from a date string or seconds since the epoch.

The date should contain 4 digits for the year and two for each of the month and
day separated by any non-numerical characters.

    # examples of valid formats
    my $date = Badger::Date->new('2015-03-19');
    my $date = Badger::Date->new('2015/03/19');

The C<Badger::Date> module converts these to the canonical form
of C<YYYY-MM-DD>

    my $date = Badger::Date->new('2015/03/19');
    print $date;       # 2015-03-19

You can also construct a C<Badger::Date> object by specifying the
number of seconds since the epoch.  This is the value return by system
functions like C<time()> and used for file creation/modification times.

    my $stamp = Badger::Date->new(time());

Or can can pass it an existing C<Badger::Date> object.

    my $stamp2 = Badger::Date->new($stamp);

If you don't specify any argument then you get the current system time as
returned by C<time()>.

    my $now = Badger::Date->new;

=head2 today()

Returns a C<Badger::Date> object representing the current date.

=head2 copy()

Returns a new C<Badger::Date> object creates as a copy of the
current one.

    my $copy = $date->copy;

This can be useful for making adjustments to a date without affecting
the original object.

    my $later = $date->copy->adjust( months => 3 );

=head2 date()

Returns the complete date in canonical form.

    print $date->date();  # 2015-03-19

This method is called automatically whenever the object is
used as a string value.

    print $date;               # 2015-03-19

=head2 format($format)

Returns a formatted version of the timestamp, generated using the L<POSIX>
strftime function.

    print $date->format('%d-%b-%y');

=head2 year() / years()

Returns the year.

    print $date->year();       # 2015

Can also be called with an argument to change the year.

    $date->year(2016);

=head2 month() / months()

Returns the month.

    print $date->month();      # 03

Can also be called with an argument to change the yonth.

    $date->month(04);

=head2 day() / days()

Returns the day.

    print $date->day();        # 19

Can also be called with an argument to change the day.

    $date->day(20);

=head2 days_in_month()

Returns the number of days in the current month.  Accounts correctly
for leap years.

=head2 leap_year()

Returns a true value (1) if the year is a leap year, a false value (0) if not.

=head2 epoch_time()

Returns the timestamp object as the number of seconds since the epoch time.

=head2 compare($when)

This method is used to chronologically compare two dates to determine
if one is earlier, later, or exactly equal to another.

The method can be passed another C<Badger::Date> object to compare
against or an argument or arguments from which a C<Badger::Date> object
can be constructed. If no arguments are passed then it defaults to a
comparison against the current time.

    my $date    = Badger::Date->new('2015-01-10');
    my $compare = Badger::Date->new('2015-03-19');

    $date->before($compare);           # date object
    $date->before('2015-03-19');       # literal date
    $date->before($epoch_seconds);     # epoch seconds, e.g. from file time
    $date->before;                     # before now

The method returns -1 if the date object represents a date before the
date passed as an argument, 1 if it's after, or 0 if it's equal.

=head2 equal($when)

This is a method of convenience which uses L<compare()> to test if two
timestamps are equal.  You can pass it any of the arguments accepted by the
L<compare()> method.

    if ($date1->equal($date2)) {
        print "both dates are equal\n";
    }

This method is overloaded onto the C<==> operator, allowing you to perform
more natural comparisons.

    if ($date1 == $date2) {
        print "both date are equal\n";
    }

=head2 before($when)

This is a method of convenience which uses L<compare()> to test if one
date occurs before another.  It returns a true value (1) if the first
timestamp (the object) is before the second (the argument), or a false value
(0) otherwise.

    if ($date1->before($date2)) {
        print "$date1 is before $date2\n";
    }

This method is overloaded onto the C<E<lt>> operator.

    if ($date1 < $date2) {
        print "$date1 is before $date2\n";
    }

=head2 after($when)

This is a method of convenience which uses L<compare()> to test if one
date occurs after another.  It returns a true value (1) if the first
date (the object) is after the second (the argument), or a false value
(0) otherwise.

    if ($date1->after($date2)) {
        print "$date1 is after $date2\n";
    }

This method is overloaded onto the C<E<gt>> operator.

    if ($date1 > $date2) {
        print "$date1 is after $date2\n";
    }

=head2 not_equal($when)

This is an alias to the L<compare()> method.  It returns a true value (-1 or
+1, both of which Perl considers to be true values) if the dates are not
equal or false value (0) if they are.

    if ($date1->not_equal($date2)) {
        print "$date1 is not equal to $date2\n";
    }

This method is overloaded onto the C<!=> operator.

    if ($date1 != $date2) {
        print "$date1 is not equal to $date2\n";
    }

=head2 not_before($when)

This is a method of convenience which uses L<compare()> to test if one
date does not occur before another. It returns a true value (1) if the
first date (the object) is equal to or after the second (the argument),
or a false value (0) otherwise.

    if ($date1->not_before($date2)) {
        print "$date1 is not before $date2\n";
    }

This method is overloaded onto the C<E<gt>=> operator.

    if ($date1 >= $date2) {
        print "$date1 is not before $date2\n";
    }

=head2 not_after($when)

This is a method of convenience which uses L<compare()> to test if one
date does not occur after another. It returns a true value (1) if the
first date (the object) is equal to or before the second (the argument),
or a false value (0) otherwise.

    if ($date1->not_after($date2)) {
        print "$date1 is not after $date2\n";
    }

This method is overloaded onto the C<E<lt>=> operator.

    if ($date1 <= $date2) {
        print "$date1 is not after $date2\n";
    }

=head2 adjust(%adjustments)

Method to adjust the date by a fixed amount or amounts.

    # positive adjustment
    $date->adjust( months => 6, years => 1 );

    # negative adjustment
    $date->adjust( months => -18 );

Named parameters can be passed as arguments or via a hash reference.

    $date->adjust(  months => -18  );        # naked
    $date->adjust({ months => -18 });        # clothed

You can specify units using singular (day, month, year) or plural
(days, months, years) keys. The method will correctly handle values
outside the usual ranges. For example, you can specify a change of 18 months,
-2000 days, and so on.

A single non-reference argument is assumed to be a duration which is
converted to a number of seconds via the L<duration()> method.

=head2 duration($duration)

Returns the number of seconds in a duration. A single numerical argument is
assumed to be a number of seconds and is returned unchanged.

    $date->adjust(300);     # 300 seconds

A single non-numerical argument should have a suffix indicating the units.
In "compact form" this is a single letter.  We use lower case C<m> for
minutes and upper case C<M> for months.

    $date->adjust("2d");    # or "2 days"
    $date->adjust("6M");    # or "6 months"
    $date->adjust("5y");    # or "5 years"

Alternately you can spell the units out in full as shown in the right
column above.  However, we only look at the first character of the following
word so you can write all sorts of nonsense which we will dutifully accept
without complaint.

    $date->adjust("5 Monkeys"); # 5 months
    $date->adjust("9 doobies"); # 9 days
    $date->adjust("3 yaks");    # 3 years

For the sake of convenience, the method will automatically convert the
word C<month> into C<Month> so that the first letter is correctly capitalised.

=head1 AUTHOR

Andy Wardley L<http://wardley.org>

=head1 COPYRIGHT

Copyright (C) 2001-2015 Andy Wardley.  All Rights Reserved.

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
