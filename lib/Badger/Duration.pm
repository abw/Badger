package Badger::Duration;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Comparable',
    import    => 'CLASS',
    utils     => 'numlike is_object params inflect',
    as_text   => 'text',
    is_true   => 1,
    accessors => 'duration seconds',
    constants => 'HASH DELIMITER',
    constant  => {
        DURATION => 'Badger::Duration',
    },
    exports   => {
        any   => 'DURATION Duration',
    };

our $SECONDS = {
    second => 1,
    minute => 60,
    hour   => 60*60,
    day    => 60*60*24,
    week   => 60*60*24*7,
    month  => 60*60*24*30,
    year   => 60*60*24*365,
};

our $ALIAS_LIST = {
    second  => 's sec secs second seconds',
    minute  => 'm min mins minute minutes',
    hour    => 'h hr hrs hour hours',
    day     => 'd day days',
    week    => 'w wk week weeks',
    month   => 'M mon mons month months',
    year    => 'y yr yrs year years',
};

our $ALIASES = {
    map { 
        my $key     = $_;
        my $aliases = $ALIAS_LIST->{ $key };
        map { $_ => $key }
        split(/\s+/, $aliases);
    }
    keys %$ALIAS_LIST
};

our @ORDER = qw( year month day hour minute second );


sub Duration { 
    return DURATION unless @_; 
    if (@_ == 1) {
        if (is_object(DURATION, $_[0])) {
            return $_[0];
        }
        else {
            return DURATION->new( duration => $_[0] );
        }
    }
    else {
        return DURATION->new( duration => params(@_) );
    }
}

sub init {
    my ($self, $config) = @_;
    my $duration = $config->{ duration } || $config;

    $self->debug(
        "init() : ", $self->dump_data($duration)
    ) if DEBUG;

    if (ref $duration eq HASH) {
        $duration = $self->parse_hash($duration);
    }
    else {
        $duration = $self->parse_text($duration);
    }

    $self->{ seconds  } = $self->count_seconds($duration);
    $self->{ duration } = $duration;

    return $self;
}

sub parse_text {
    my ($self, $duration) = @_;
    my $bits  = { };

    # $duration can be a number, assumed to be seconds
    return { seconds => $duration }
        if numlike($duration);

    while ($duration =~ /\G\s*(-?[\d\.]+)\s*(\w+)\s*(,|and)?\s*/gc) {
        $self->debug("PARSE [$1] [$2]") if DEBUG;
        my $name = $ALIASES->{ $2 } || $ALIASES->{ lc $2 }
            || return $self->error_msg( invalid => duration => "$1 $2" );
        my $old = $bits->{ $name } || 0;
        my $new = $1;
        return $self->error_msg( invalid => duration => "$1 $2" )
            unless numlike($new);
        $bits->{ $name } += $new;
        $self->debug("+ $new $name") if DEBUG;
    }

    if ($duration =~ /\G\s*(.*)/gc && length $1) {
        return $self->error_msg( invalid => duration => $1 );
    }

    return $bits;
}

sub parse_hash {
    my ($self, $duration) = @_;
    my $bits  = { };

    while (my ($key, $value) = each %$duration) {
        my $name = $ALIASES->{ $key } || $ALIASES->{ lc $key }
            || return $self->error_msg( invalid => duration => $key );
        my $old = $bits->{ $name } || 0;
        return $self->error_msg( invalid => duration => "$key => $value" )
            unless numlike($value);
        $bits->{ $name } += $value;
        $self->debug("+ $value $name") if DEBUG;
    }
    return $bits;
}

sub count_seconds {
    my ($self, $bits) = @_;
    my $seconds = 0;

    while (my ($key, $value) = each %$bits) {
        my $name = $ALIASES->{ $key } || $ALIASES->{ lc $key }
            || return $self->error_msg( invalid => duration => $key );
        $self->debug("COUNT [$key => $name] [$value]") if DEBUG;
        my $secs = $SECONDS->{ $name }
            || return $self->error_msg( invalid => duration => "$key -> $name" );
        return $self->error_msg( invalid => duration => "$value $key" )
            unless numlike($value);
        $seconds += $secs * $value;
    }

    return $seconds;
}

sub compare {
    my ($this, $that) = @_;
    return $this->{ seconds } <=> $that->{ seconds };
}

sub text {
    my $self     = shift;
    my $duration = $self->{ duration };
    my @bits;

    $self->debug("DURATION: ", $self->dump_data($duration)) if DEBUG;

    foreach my $item (@ORDER) {
        my $value = $duration->{ $item } || next;
        push(@bits, inflect($value, $item));
        $self->debug("DURATION + $value $item") if DEBUG;
    }
    return join(' ', @bits);
}



1;
__END__

=head1 NAME

Badger::Duration - simple class for representing durations

=head1 SYNOPSIS

    use Badger::Duration 'Duration';

    my $d = Duration('7 days 4 hours 20 minutes');

    print "$d is ", $d->seconds, " seconds\n";

=head1 DESCRIPTION

This is a simple module for parsing durations.  

It is ideally suited for things like the calculation of expiry times (e.g. 
for cookies, items in a cache, etc) allowing them to be specified in 
human-friendly format, e.g. "4 minutes 20 seconds" (or various alternatives).

=head1 EXPORTABLE SUBROUTINES

=head2 DURATION

This is a shortcut alias to C<Badger::Duration>.

    use Badger::Duration 'DURATION';
    
    my $duration = DURATION->new(
        hours   => 4,
        minutes => 20,
    );              # same as Badger::Duration->new(...);

=head2 Duration()

This subroutine returns the name of the C<Badger::Duration> class when called
without arguments. Thus it can be used as an alias for C<Badger::Duration>
as per L<DURATION>.

    use Badger::Duration 'Duration';
    
    my $duration = Duration->new(...);  # same as Badger::Duration->new(...);

When called with arguments, it creates a new C<Badger::Duration> object.

    my $duration = Duration(...);       # same as Badger::Duration->new(...);

=head1 METHODS

The following methods are defined in addition to those inherited from the
L<Badger::Comparable> and L<Badger::Base> base classes.

=head2 new()

Constructor method to create a new C<Badger::Duration> object.  The duration
can be specified as a single C<duration> parameter.

    my $d = Badger::Duration->new(
        duration => '4 minutes 20 seconds'
    );

The duration string can contain any number of 
"E<lt>numberE<gt> E<lt>durationE<gt>" sequences separate by whitespace, 
commas or the word C<and>.  The following  are all valid:

    4 minutes 20 seconds
    4 minutes,20 seconds
    4 minutes, 20 seconds
    4 minutes and 20 seconds

The canonical names for durations are: C<year>, C<month>, C<day>, C<hour>, 
C<minute> and C<second>.  The following aliases may be used:

=over

=item second

    s sec secs seconds

=item minute

    m min mins minutes

=item hour

    h hr hrs hours

=item day

    d days

=item week

    w wk weeks

=item month

    M mon mons months

=item year

    y yr yrs years

=back

A duration can also be specified using named parameters:

    my $d = Badger::Duration->new(
        minutes => 4,
        seconds => 20,
    );

Or by reference to a hash array:

    my $d = Badger::Duration->new({
        minutes => 4,
        seconds => 20,
    });

This can also be specified as an explicit C<duration> option if you prefer:

    my $d = Badger::Duration->new(
        duration => {
            minutes => 4,
            seconds => 20,
        }
    );

In all cases, any of the valid aliases for durations may be used, e.g.

    my $d = Badger::Duration->new(
        h => 1,
        m => 4,
        s => 20,
    );

=head2 duration()

Returns a reference to a hash array containing the canonical values of 
the duration.

    my $d = Badger::Duration->new(
        duration => '4 hours 20 minutes'
    );
    my $h = $d->duration;
    print $h->{ hour   };     # 4
    print $h->{ minute };     # 20

=head2 seconds()

Returns the total number of seconds for the duration.

    my $d = Badger::Duration->new(
        duration => '4 hours 20 minutes'
    );
    print $d->seconds;      # 15600

=head2 compare($that)

This method is defined to enable the functionality provided by the 
L<Badger::Comparable> base class.

    use Badger::Duration 'Duration';

    my $d1 = Duration('4 hours 20 minutes');
    my $d2 = Duration('270 minutes');

    if ($d1 < $d2) {
        # ...do something...
    }

=head2 text()

Returns a canonical text representation of the duration.

    use Badger::Duration 'Duration';
    my $d1 = Duration('4 hrs 20 mins');
    print $d1->text;            # 4 hours 20 minutes

Note that the units will be pluralised appropriately.  e.g.

    1 hour 1 minute 1 second
    2 hours 2 minutes 2 seconds

This method is bound to the auto-stringification operation which is a fancy
way of saying it gets called automatically when you simply print a 
C<Badger::Duration> object.

    print $d1;                  # 4 hours 20 minutes

=head1 INTERNAL METHODS

=head2 init($config)

Object initialisation method called automatically by the 
L<new()|Badger::Base/new()> constructor method inherited from the 
L<Badger::Base> base class.

=head2 parse_text($text)

Internal method to parse a text string and return a hash reference of canonical
values.

=head2 parse_hash($hash)

Internal method to parse a hash reference and return another hash reference of 
canonical values (e.g. after mapping aliases to canonical names).

=head2 count_seconds($hash)

Counts the total number of seconds in a duration passed by reference to a hash
array.

=head1 AUTHOR

Andy Wardley L<http://wardley.org>

=head1 COPYRIGHT

Copyright (C) 2013 Andy Wardley.  All Rights Reserved.

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
