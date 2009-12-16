package Badger::Reporter;

use Badger::Class
    version      => 0.01,
    debug        => 0,
    base         => 'Badger::Base',
    import       => 'class',
    config       => 'verbose=0 quiet=0 dryrun=0 colour|color=1',
    utils        => 'self_params params xprintf',
    auto_can     => 'auto_can',
    constants    => 'ARRAY HASH BLANK DELIMITER',
    constant     => {
        NO_REASON   => 'no reason given',
    },
    messages     => {
        bad_colour => 'Invalid colour specified for %s event: %s',
    };

use Badger::Debug ':dump';
use Badger::Rainbow
    ANSI   => 'black white red green blue cyan magenta yellow',
    import => 'strip_ANSI_escapes';

our $COLOURS = {
    black     => \&black,
    red       => \&red,
    green     => \&green,
    blue      => \&blue,
    cyan      => \&cyan,
    magenta   => \&magenta,
    yellow    => \&yellow,
};


#-----------------------------------------------------------------------
# init methods
#-----------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    $self->configure($config)
         ->init_events($config)
         ->init_reporter($config);
    return $self;
}


sub init_events {
    my ($self, $config) = @_;
    my $lookup = $self->{ event       } = { };
    my $events = $self->{ events      } = [ ];
    my $names  = $self->{ event_names } = [ ];
    my ($evspec, $event, $name);

    $self->debug("init_events()") if DEBUG;

    # events can be specified as a list ref of 'whitespace delimited string'
    $evspec = $config->{ events } || [ ];
    $evspec = [ split(DELIMITER, $evspec) ]
        unless ref $evspec eq ARRAY;

    $self->debug("event spec: $evspec ==> ", $self->dump_data($evspec)) if DEBUG;
    
    # now merge it with any events specifed in $EVENTS class variable(s)
    $evspec = $self->class->list_vars( EVENTS => $evspec );
    
    $self->debug("event spec: ", $self->dump_data($evspec)) if DEBUG;

    foreach (@$evspec) {
        $self->debug("event: $_") if DEBUG;
        $event = $_;            # avoid aliasing
        $event = { name => $event } 
            unless ref $event eq HASH;
        $name  = $event->{ name }
            || return $self->error_msg( missing => 'event name' );
        
        # set some defaults
        $event->{ message } = '%s'    unless defined $event->{ message };
        $event->{ summary } = '%s %s' unless defined $event->{ summary };
        
        # TODO: is ignoring duplicates the right thing to do?
        next if $lookup->{ $name };
        
        push(@$names, $name);
        push(@$events, $event);
        $lookup->{ $name } = $event;
    }
    
    $self->debug("initalised events: ", $self->dump_data($lookup)) if DEBUG;
    
    return $self;
}


sub init_reporter {
    my ($self, $config) = @_;
    $self->init_stats;
    $self->init_output;
}


sub init_stats {
    my $self = shift;
    $self->{ count } = 0;
    $self->{ stats } = {
        map { $_ => 0 }
        $self->event_names
    };
    return $self;
}


sub init_output {
    my ($self, $config) = @_;
    my ($event, $cols, $col, $colname);

    # fetch a hash table for all the colo(u)rs we know about
    $cols = $self->{ colours } ||= $self->class->hash_vars( 
        COLOURS => $config->{ colours } || $config->{ colors }
    );

    if ($self->{ colour }) {
        foreach $event ($self->events) {
            # if the event specifies a colour then change the 'message' and
            # 'summary' output formats to include ANSI escape sequences
            if ($colname = $event->{ colour } || $event->{ color }) {
                $col = $cols->{ $colname }
                    || return $self->error_msg( bad_colour => $event->{ name } => $colname );
                $event->{ message } = $col->($event->{ message });
                $event->{ summary } = $col->($event->{ summary });
            }
        }
    }
    else {
        # strip any colour that might have been previously added
        foreach $event ($self->events) {
            $event->{ message } = strip_ANSI_escapes($event->{ message });
            $event->{ summary } = strip_ANSI_escapes($event->{ summary });
        }
    }
    
    return $self;
}


#-----------------------------------------------------------------------
# accessor methods
#-----------------------------------------------------------------------

sub event {
    my $self  = shift;
    # TODO: If we allow events to be added then we should also add them to
    # the events/name list.  That suggests that init_events() needs to be
    # cleaved in twain so that we can re-used the event adding code without
    # having to go through the full configuration process which expects a 
    # config and merges events from the $EVENTS package variable(s).
    return @_
        ? $self->{ event }->{ $_[0] }
        : $self->{ event };
}


sub events {
    my $self   = shift;
    my $events = $self->{ events };
    return wantarray
        ? @$events
        :  $events;
}


sub event_names {
    my $self = shift;
    my $names = $self->{ event_names };
    return wantarray
        ? @$names
        :  $names;
}


#-----------------------------------------------------------------------
# basic reporting methods
#-----------------------------------------------------------------------

sub report {
    my $self  = shift;
    my $type  = shift 
        || return $self->error_msg( missing => 'event type' );
    my $event = $self->{ event }->{ $type }
        || return $self->error_msg( invalid => 'event type' => $type );
    
    # TODO: Why don't we store the stats in the event?  Saves splitting 
    # things up...
    $self->{ stats }->{ $type }++;
    $self->{ count }++;

    # If we're running in quiet mode, or if the event describes itself as 
    # being verbose and we're not running in verbose mode, then we return
    # now.  We also return if the event doesn't have a message format.
    return if $self->{ quiet };
    return if $event->{ verbose } && ! $self->{ verbose };
    return unless $event->{ message };
        
    $self->say( xprintf($event->{ message }, @_) );

    return $event->{ return };      # usually undef
}


sub say_msg {
    my $self = shift;
    print $self->message(@_), "\n";
}


sub say {
    my $self = shift;
    print @_, "\n";
}




#-----------------------------------------------------------------------
# auto_can method generator
#-----------------------------------------------------------------------

sub auto_can {
    my ($self, $name) = @_;
    my $event;

    $self->debug("auto_can($name)") if DEBUG;
    
    if ($name =~ s/_msg$// && ($event = $self->{ event }->{ $name })) {
        return sub {
            my $self = shift;
            $self->report( $name => $self->message(@_) );
        }
    }
    elsif ($event = $self->{ event }->{ $name }) {
        return sub {
            shift->report( $name => @_ );
        }
    }
    elsif (DEBUG) {
        $self->debug("$name is not an event in ", $self->dump_data($self->{ event }));
    }
    return undef;
}



#-----------------------------------------------------------------------
# summary
#-----------------------------------------------------------------------

sub summary {
    my $self  = shift;
    my $stats = $self->{ stats };
    my ($event, $name, $format, $count, @output);
 
    $self->debug("summary of stats: ", $self->dump_data($stats)) if DEBUG;

    # TODO: no point worrying about being quiet if we're going to say it
    unless ($self->{ quiet }) {
        foreach $event ($self->events) {
            next unless $format = $event->{ summary };
            $name = $event->{ name };
            next unless $count  = $stats->{ $name };
            push(@output, xprintf($format, $count, $count == 1 ? '' : 's', $name) );
        }
    }
    
#    $self->init_stats;
    
    return join("\n", @output);
}     



#-----------------------------------------------------------------------
# Command line argument parser and help/usage for scripts to use.
# This is a quick hack until Badger::Config is finished.
#-----------------------------------------------------------------------

sub configure_args {
    my $self = shift;
    my @args = @_ == 1 && ref $_[0] eq ARRAY ? @{$_[0]} 
             : @_ ? @_
             : @ARGV;

    $self->debug("configure_args(", $self->dump_data(\@args)) if DEBUG;
    
    return $self->usage    if grep(/--?h(elp)?/, @args);
    $self->{ dryrun  } = 1 if grep(/--?(n(othing)?|dry[-_]?run)/, @args);
    $self->{ verbose } = 1 if grep(/--?v(erbose)?/, @args);
    $self->{ quiet   } = 1 if grep(/--?q(uiet)?/, @args);
    $self->{ colour  } = 1 if grep(/--?c(olou?r)?/, @args);

    # Get any extra configuration from the subclass scheme definition
    # NOTE: This only works in immediate subclasses. A more thorough 
    # implementation should call list_vars() and deal with everything,
    # thereby eliminating the above code.  However, that's something for 
    # Badger::Config
    my $config = $self->class->list_vars('CONFIG');     # may overwrite above
    if ($config) {
        foreach my $item (@$config) {
            my $name = quotemeta $item->{ name };
            $self->{ $name } = 1 if grep(/--?$name/, @args);
            if (DEBUG) {
                $self->debug("CONFIG $name => ", defined($self->{ name }) ? $self->{ name } : '<undef>');
            }
        }
    }

    $self->{ colour  } = 0 if grep(/--?no[-_]?c(olou?r)?/, @args);
    $self->{ colour  } = 0 if grep(/--?white/, @args);

    $self->init_output;
    
    return $self;
}




sub usage {
    my $options = shift->options_summary;
    die <<EOF;
$0 [options]

Options:
$options
EOF
}

sub options_summary {
    return <<EOF;
  -h  --help                    This help
  -v  --verbose                 Verbose mode (extra output)
  -q  --quiet                   Quiet mode (no output)
  -n  --nothing --dry-run       Dry run - no action performed
  -c  --colour --color          Colourful output
  -nc --no-colour --no-color    Uncolourful output
EOF
}


1;