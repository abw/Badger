#========================================================================
#
# Badger::Log
#
# DESCRIPTION
#   A simple base class logging module.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Log;

use Badger::Class
    version   => 0.01,
    base      => 'Badger::Prototype',
    import    => 'class',
    utils     => 'blessed',
    config    => 'system|class:SYSTEM format|class:FORMAT',
    constants => 'ARRAY CODE',
    constant  => {
        MSG   => '_msg',        # suffix for message methods, e.g. warn_msg()
        LOG   => 'log',         # method a delegate must implement
    },
    vars      => {
        SYSTEM => 'Badger',
        FORMAT => '[<time>] [<system>] [<level>] <message>',
        LEVELS => {
            debug => 0,
            info  => 0,
            warn  => 1,
            error => 1,
            fatal => 1,
        }
    },
    messages  => {
        bad_level => 'Invalid logging level: %s',
    };
    


class->methods(
    # Our init method is called init_log() so that we can use Badger::Log as 
    # a mixin or base class without worrying about the init() method clashing 
    # with init() methods from other base classes or mixins.  We create an 
    # alias from init() to init_log() so that it also Just Works[tm] as a 
    # stand-alone object
    init   => \&init_log,

    # Now we define two methods for each logging level.  The first expects
    # a pre-formatted output message (e.g. debug(), info(), warn(), etc)
    # the second additionally wraps around the message() method inherited
    # from Badger::Base (eg. debug_msg(), info_msg(), warn_msg(), etc)
    map {
        my $level = $_;             # lexical variable for closure
        
        $level => sub {
            my $self = shift;
            return $self->{ $level } unless @_;
            $self->log($level, @_) 
                if $self->{ $level };
        },

        ($level.MSG) => sub {
            my $self = shift;
            return $self->{ $level } unless @_;
            $self->log($level, $self->message(@_)) 
                if $self->{ $level };
        }
    }
    keys %$LEVELS
);


sub init_log {
    my ($self, $config) = @_;
    my $class  = $self->class;
    my $levels = $class->hash_vars( LEVELS => $config->{ levels } );
    
    # populate $self for each level in $LEVEL using the 
    # value in $config, or the default in $LEVEL
    while (my ($level, $default) = each %$levels) {
        $self->{ $level } = 
            defined $config->{ $level }
                  ? $config->{ $level } 
                  : $levels->{ $level };
    }

    # call the auto-generated configure() method to update $self from $config
    $self->configure($config);

    return $self;
}

sub log {
    my $self    = shift;
    my $level   = shift;
    my $action  = $self->{ $level };
    my $message = join('', @_);
    my $method;

    return $self->_fatal_msg( bad_level => $level )
        unless defined $action;
        
    # depending on what the $action is set to, we add the message to
    # an array, call a code reference, delegate to another log object,
    # print or ignore the mesage

    if (ref $action eq ARRAY) {
        push(@$action, $message);
    }
    elsif (ref $action eq CODE) {
        &$action($level, $message);
    }
    elsif (blessed $action && ($method = $action->can(LOG))) {
        $method->($action, $level, $message);
    }
    elsif ($action) {
        warn $self->format($level, $message), "\n";
    }
}

sub format {
    my $self = shift;
    my $args = {
        time    => scalar(localtime(time)),
        system  => $self->{ system },
        level   => shift,
        message => shift,
    };
    my $format = $self->{ format };
    $format =~ 
            s/<(\w+)>/
              defined $args->{ $1 } 
                    ? $args->{ $1 }
                    : "<$1>"
            /eg;
    return $format;
}

sub level {
    my $self  = shift;
    my $level = shift;
    return $self->_fatal_msg( bad_level => $level )
        unless exists $LEVELS->{ $level };
    return @_ ? ($self->{ $level } = shift) : $self->{ $level };
}

sub enable {
    my $self = shift;
    $self->level($_ => 1) for @_;
}

sub disable {
    my $self = shift;
    $self->level($_ => 0) for @_;
}

sub _error_msg {
    my $self = shift;
    $self->Badger::Base::error(
        $self->Badger::Base::message(@_)
    );
}

sub _fatal_msg {
    my $self = shift;
    $self->Badger::Base::fatal(
        $self->Badger::Base::message(@_)
    );
}


1;

__END__

=head1 NAME

Badger::Log - log for errors, warnings and other messages

=head1 SYNOPSIS

    use Badger::Log;
    
    my $log = Badger::Log->new({
        debug => 0,      # ignore debug messages
        info  => 1,      # print info messages
        warn  => \@warn, # add warnings to list
        error => $log2,  # delegate errors to $log2
        fatal => sub {   # custom fatal error handler
            my $message = shift;
            print "FATAL ERROR: $message\n";
        },
    });
        
    $log->debug('a debug message');
    $log->info('an info message');
    $log->warn('a warning message');
    $log->error('an error message');
    $log->fatal('a fatal error message');

=head1 DESCRIPTION

This module defines a simple base class module for logging messages
generated by an application.

There are five message categories:

=over

=item debug

A debugging message.  

=item info

A message providing some general information.

=item warn

A warning message.

=item error

An error message.

=item fatal

A fatal error message.

=back

=head1 CONFIGURATION OPTIONS

=head2 debug

Flag to indicate if debugging messages should be generated and output.
The default value is C<0>.  It can be set to C<1> to enable debugging
messages or to one of the other reference values described in the 
documentation for the L<new()> method.

=head2 info

Flag to indicate if information messages should be generated and output.
The default value is C<0>.  It can be set to C<1> to enable information
messages or to one of the other reference values described in the 
documentation for the L<new()> method.

=head2 warn

Flag to indicate if warning messages should be generated and output.
The default value is C<1>.  It can be set to C<0> to disable warning
messages or to one of the other reference values described in the 
documentation for the L<new()> method.

=head2 error

Flag to indicate if error messages should be generated and output.
The default value is C<1>. It can be set to C<0> to disable error 
messages or to one of the other reference values described in the 
documentation for the L<new()> method.

=head2 fatal

Flag to indicate if fatal messages should be generated and output. The default
value is C<1>. It can be set to C<0> to disable fatal error messages (at your
own peril) or to one of the other reference values described in the
documentation for the L<new()> method.

=head2 format

This option can be used to define a different log message format.  

    my $log = Badger::Log->new(
        format => '[<level>] [<time>] <message>',
    );

The default message format is:

    [<time>] [<system>] [<level>] <message>

The C<E<lt>XXXE<gt>> snippets are replaced with their equivalent values:

    time        The current local time
    system      A system identifier, defaults to 'Badger'
    level       The message level: debug, info, warn, error or fatal
    message     The log message itself

The format can also be set using a C<$FORMAT> package variable in a subclass
of C<Badger::Log>.

    package Your::Log::Module;
    use base 'Badger::Log';
    our $FORMAT = '[<level>] [<time>] <message>';
    1;

=head2 system

A system identifier which is inserted into each message via the
C<E<lt>systemE<gt>> snippet.  See L<format> for further information.
The default value is C<Badger>.

    my $log = Badger::Log->new(
        system => 'MyApp',
    );

The system identifier can also be set using a C<$SYSTEM> package variable in a
subclass of C<Badger::Log>.

    package Your::Log::Module;
    use base 'Badger::Log';
    our $SYSTEM = 'MyApp';
    1;

=head1 METHODS

=head2 new(\%options)

Constructor method which creates a new C<Badger::Log> object.  It
accepts a list of named parameters or reference to hash of
configuration options that define how each message type should be
handled.

    my $log = Badger::Log->new({
        debug => 0,      # ignore debug messages
        info  => 1,      # print info messages
        warn  => \@warn, # add warnings to list
        error => $log2,  # delegate errors to $log2
        fatal => sub {   # custom fatal error handler
            my $message = shift;
            print "FATAL ERROR: $message\n";
        },
    });

Each message type can be set to C<0> to ignore messages or C<1> to
have them printed to C<STDERR>.  They can also be set to reference a list
(the message is appended to the list), a subroutine (which is called,
passing the message as an argument), or any object which implements a 
L<log()> method (to which the message is delegated).

=head2 debug($message)

Generate a debugging message.

    $log->debug('The cat sat on the mat');

=head2 info($message)

Generate an information message.

    $log->info('The pod doors are closed');

=head2 warn($message)

Generate a warning message.

    $log->warn('The pod doors are opening');

=head2 error($message)

Generate an error message.

    $log->error("I'm sorry Dave, I can't do that');

=head2 fatal($message)

Generate a fatal error message.

    $log->fatal('HAL is dead, aborting mission');

=head2 debug_msg($format,@args)

This method uses the L<message()|Badger::Base/message()> method inherited
from L<Badger::Base> to generate a debugging message from the arguments
provided.  To use this facility you first need to create your own logging
subclass which defines the message formats that you want to use.

    package Your::Log;
    use base 'Badger::Log';
    
    our $MESSAGES = {
        denied => "Denied attempt by %s to %s",
    };
    
    1;

You can now use your logging module like so:

    use Your::Log;
    my $log = Your::Log->new;
    
    $log->debug_msg( denied => 'Arthur', 'make tea' );

The log message generated will look something like this:

# TODO

=head2 info_msg($format,@args)

This method uses the L<message()|Badger::Base/message()> method inherited
from L<Badger::Base> to generate an info message from the arguments
provided.  See L<debug_msg()> for an example of using message formats.

=head2 warn_msg($format,@args)

This method uses the L<message()|Badger::Base/message()> method inherited
from L<Badger::Base> to generate a warning message from the arguments
provided.  See L<debug_msg()> for an example of using message formats.

=head2 error_msg($format,@args)

This method uses the L<message()|Badger::Base/message()> method inherited
from L<Badger::Base> to generate an error message from the arguments
provided.  See L<debug_msg()> for an example of using message formats.

=head2 fatal_msg($format,@args)

This method uses the L<message()|Badger::Base/message()> method inherited
from L<Badger::Base> to generate a fatal error message from the arguments
provided.  See L<debug_msg()> for an example of using message formats.

=head2 log($level, $message) 

This is the general-purpose logging method that the above methods call.

    $log->log( info => 'star child is here' );

=head2 level($level, $action)

This method is used to get or set the action for a particular level.
When called with a single argument, it returns the current action 
for that level.

    my $debug = $log->level('debug');

When called with two arguments it sets the action for the log level 
to the second argument.

    $log->level( debug => 0 );      # disable
    $log->level( info  => 1 );      # enable
    $log->level( warn  => $list );  # push to list
    $log->level( error => $code );  # call code
    $log->level( fatal => $log2 );  # delegate to another log

=head2 enable($level)

This method can be used to enable one or more logging levels.

    $log->enable('debug', 'info', 'warn');

=head2 disable($level)

This method can be used to disable one or more logging levels.

    $log->disable('error', 'fatal');

=head1 INTERNAL METHODS

=head2 _error_msg($format,@args)

The L<error_msg()> method redefines the L<error_msg()|Badger::Base/error_msg()>
method inherited from L<Badger::Base> (which can be considered both a bug and
a feature).  The internal C<_error_msg()> method effectively bypasses the 
new method and performs the same functionality as the base class method, in 
throwing an error as an exception.

=head2 _fatal_msg($format,@args)

As per L<_error_msg()>, this method provides access to the functionality
of the L<fatal_msg()|Badger::Base/fatal_msg()> method in L<Badger::Base>.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2005-2009 Andy Wardley.  All Rights Reserved.

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



