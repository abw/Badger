package Badger::Period;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Comparable',
    utils     => 'numlike is_object',
    accessors => 'uri',
    as_text   => 'uri',
    is_true   => 1,
    constants => 'HASH ARRAY DELIMITER',
    constant  => {
        FIELD_NAMES => undef,
        TYPE_NAME   => 'period',
    },
    messages  => {
        bad_type      => 'Invalid %s: %s',
        bad_duration  => 'Invalid duration: %s',
    };

use Time::Local;
use POSIX 'strftime';

our @YMD        = qw( year month day );
our @HMS        = qw( hour minute second );
our @SMHD       = qw( second minute hour day );
our @YMDHMS     = (@YMD, @HMS);
our $SECONDS    = {
    s => 1,
    m => 60,
    h => 60*60,
    d => 60*60*24,
    M => 60*60*24*30,
    y => 60*60*24*365,
};


sub split_regex {
    shift->not_implemented;
}


sub join_format {
    shift->not_implemented;
}


sub text_format {
    shift->join_format;
}


sub field_names {
    my $class = shift;
    my $names = $class->FIELD_NAMES
        || return $class->not_implemented;

    $names = [ split(DELIMITER, $names) ] 
        unless ref $names eq ARRAY;

    return wantarray
        ?  @$names
        : \@$names
}


#-----------------------------------------------------------------------
# Methods
#-----------------------------------------------------------------------

sub new {
    my $class  = shift; 
    my @fields = $class->field_names;
    my $self   = bless { map { ($_, 0) } @fields }, ref $class || $class;
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
            (@$config{ @YMDHMS }) = reverse( ( localtime($time) )[0..5] );
            $config->{ year  }+= 1900;
            $config->{ month }++;
            $config->{ etime } = $time;
        }
        elsif (is_object(ref $class || $class, $time)) {
            $config->{ uri   } = $time->uri;
            $config->{ etime } = $time->epoch_time;
            $self->split_uri($config->{ uri }, $config);
        }
        else {
            # $time is a timestamp so split and rejoin into canonical form
            $config->{ uri } = $time;
            $self->split_uri($config);
        }
        $self->join_uri($config);
    }

    # set any fields defined in config, allowing singular (second,month,
    # etc) and plural (seconds, months, etc)
    foreach my $field (@fields) {
        $self->{ $field } = $config->{ $field } || $config->{"${field}s"} || 0;
    }

    $self->join_uri;

    return $self;
}


sub copy {
    my $self = shift;
    $self->new( $self->{ uri } );
}


sub split_uri {
    my $self   = shift;
    my $target = shift || $self;
    my $regex  = $self->split_regex;
    my @fields = $self->field_names;

    $target->{ uri } = '' unless defined $target->{ uri };

    (@$target{ @fields } = map { 0+$_ } $target->{ uri } =~ m/$regex/o)
        || return $self->error_msg( bad_type => $self->TYPE_NAME, $target->{ uri } );
}


sub join_uri {
    my $self   = shift;
    my $target = shift || $self;
    my @fields = $self->field_names;

    return ($target->{ uri } = sprintf(
        $self->join_format,
        map { defined $_ ?  $_ : 0 } 
        @$target{ @fields }
    ));
}


sub epoch_time {
    my $self = shift;

    return $self->{ etime } ||= timelocal(
        $self->posix_args
    );
}


sub posix_args {
    my $self = shift;
    return (
        (
            map { $self->{ $_ } || 0 }
            @SMHD
        ),
        ($self->{ month } ||    1) - 1, 
        ($self->{ year  } || 1900) - 1900
    );
}


sub format {
    my $self = shift;
    my $fmt  = shift;
    return strftime(
        $fmt, 
        $self->posix_args
    );
}


sub text {
    my $self   = shift;
    my @fields = $self->field_names;
    return $self->{ text } 
       ||= sprintf( $self->text_format, @$self{ @fields } );
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


sub compare {
    my $self   = shift;
    my @fields = $self->field_names;

    # optimisation: if the $self object has an epoch time and a single 
    # numerical argument is passed (also an epoch time) then we can do a 
    # simple comparison
    return $self->{ etime } <=> $_[0]
        if $self->{ etime } 
        && @_ == 1
        && numlike $_[0];

    # otherwise we upgrade any argument(s) to another timestamp and comare
    # them piecewise
    my $comp = @_ && is_object(ref $self || $self, $_[0]) 
        ? shift 
        : $self->new(@_);
    
    foreach my $item (@fields) {
        if ($self->{ $item } < $comp->{ $item }) {
            return -1;  # -1 - self earlier than comparison timestamp
        }
        elsif ($self->{ $item } > $comp->{ $item }) {
            return 1;   #  1 - self later than comparison timestamp
        }
    }
    return 0;           #  0 - same time
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

Badger::Period - base class for Badger::Date and Badger::Time

=head1 DESCRIPTION

This is a work in progress.

=head1 AUTHOR

Andy Wardley L<http://wardley.org>

=head1 COPYRIGHT

Copyright (C) 2001-2012 Andy Wardley.  All Rights Reserved.

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
