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

