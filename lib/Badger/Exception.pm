#========================================================================
#
# Badger::Exception
#
# DESCRIPTION
#   Module implementing an exception class for reporting structured
#   errors.
#
# AUTHOR
#   Andy Wardley <abw@wardley.org>
#
#========================================================================

package Badger::Exception;

use Badger::Class
    base        => 'Badger::Base',
    version     => 0.01,
    debug       => 0,
    mutators    => 'type',
    accessors   => 'stack',
    constants   => 'TRUE ARRAY HASH DELIMITER',
    import      => 'class',
    as_text     => 'text',      # overloaded text stringification
    is_true     => 1,           # always evaluates to a true value
    exports     => {
        hooks => {
            trace  => [
                # args are ($self, $target, $symbol, $value)
                sub { $TRACE = $_[3] },
                # expects one value argument
                1
            ],
            colour  => [
                # args are ($self, $target, $symbol, $value)
                sub { $COLOUR = $_[3] },
                # expects one value argument
                1
            ],
        },
    },
    messages => {
        caller => "<4> called from <1>\n  in <2> at line <3>",
    };

use Badger::Rainbow ANSI => 'cyan yellow green';
our $FORMAT  = '<type> error - <info>' unless defined $FORMAT;
our $TYPE    = 'undef'                 unless defined $TYPE;
our $INFO    = 'no information'        unless defined $INFO;
our $ANON    = 'unknown'               unless defined $ANON;
our $TRACE   = 0                       unless defined $TRACE;
our $COLOUR  = 0                       unless defined $COLOUR;


sub init {
    my ($self, $config) = @_;
    $self->{ type  } = $config->{ type  } || $self->class->any_var('TYPE');
    $self->{ info  } = $config->{ info  } || '';
    $self->{ file  } = $config->{ file  };
    $self->{ line  } = $config->{ line  };
    # watch out for the case where 'trace' is set explicitly to 0
    $self->{ trace } =
        exists $config->{ trace }
             ? $config->{ trace }
             : $TRACE;

    return $self;
}


sub info {
    my $self = shift;
    return @_
        ? ($self->{ info }  = shift)
        : ($self->{ info } || $INFO);
}


sub file {
    my $self = shift;
    return @_
        ? ($self->{ file }  = shift)
        : ($self->{ file } || $ANON);
}


sub line {
    my $self = shift;
    return @_
        ? ($self->{ line }  = shift)
        : ($self->{ line } || $ANON);
}


sub text {
    my $self = shift;
    my $text = shift || $self->class->any_var('FORMAT');

    # TODO: extend Badger::Utils::xprintf to handle this
    $text  =~ s/<(\w+)>/defined $self->{ $1 } ? $self->{ $1 } : "(no $1)"/eg;

    # TODO: not sure we should add file and line automatically - better to
    # leave it up to the $FORMAT
    $text .= " in $self->{ file }"      if $self->{ file };
    $text .= " at line $self->{ line }" if $self->{ line };

    if ($self->{ trace } && (my $trace = $self->stack_trace)) {
        $text .= "\n" . $trace;
    }

    return $text;
}


sub stack_trace {
    my $self = shift;
    my @lines;

    if (my $stack = $self->{ stack }) {
        foreach my $caller (@$stack) {
            my @args = $COLOUR
                ? (
                    cyan($caller->[0]),
                    cyan($caller->[1]),
                    yellow($caller->[2]),
                    yellow($caller->[3]),
                  )
                : @$caller;
            push(@lines, $self->message( caller => @args ));
        }
    }

    return join("\n", @lines);
}


sub trace {
    my $self = shift;
    if (ref $self) {
        return @_
            ? ($self->{ trace } = shift )
            :  $self->{ trace };
    }
    else {
        return @_
            ? $self->class->var( TRACE => shift )
            : $self->class->var('TRACE');
    }
}

sub throw {
    my $self = shift;

    # save relevant information from caller stack for enhanced debugging,
    # but only the first time the exception is thrown
    if ($self->{ trace } && ! $self->{ stack }) {
        my @stack;
        my $i = 1;
        while (1) {
            my @info = caller($i++);
            last unless @info;
            push(@stack, \@info);
        }
        $self->{ stack } = \@stack;
    }

    die $self;
}




#------------------------------------------------------------------------
# match_type(@types)
#
# Selects the most appropriate handler for the current exception type,
# from the list of types passed in as arguments.  The method returns the
# item which is an exact match for type or the closest, more
# generic handler (e.g. foo being more generic than foo.bar, etc.)
#------------------------------------------------------------------------

sub match_type {
    my $self  = shift;
    my $types = @_ == 1 ? shift :  [@_];
    my $type  = $self->{ type };

    $types = [ split(DELIMITER, $types) ]
        unless ref $types;

    $types = { map { $_ => $_ } @$types }
        if ref $types eq ARRAY;

    return $self->error( invalid => 'type match' => $types )
        unless ref $types eq HASH;

    while ($type) {
        return $types->{ $type }
            if $types->{ $type };

        # strip .element from the end of the exception type to find a
        # more generic handler
        $type =~ s/\.?[^\.]*$//;
    }

    return undef;
}



1;
__END__

=head1 NAME

Badger::Exception - structured exception for error handling

=head1 SYNOPSIS

    use Badger::Exception;

    # create exception object
    my $exception = Badger::Exception->new({
        type => $type,
        info => $info,
    });

    # query exception type and info fields
    $type = $exception->type();
    $info = $exception->info();
    ($type, $info) = $exception->type_info();

    # print string summarising exception
    print $exception->text();

    # use automagic stringification
    print $exception;

    # throw exception
    $exception->throw;

=head1 DESCRIPTION

This module defines an object class for representing exceptions.  These are
simple objects that store various bits of information about an error
condition.

The C<type> denotes what kind of error occurred (e.g. 'C<file>', 'C<parser>',
'C<database>', etc.). The C<info> field provides further information about the
error (e.g. 'C<foo/bar.html not found>', 'C<parser error at line 42>',
'C<server is on fire>', etc). Other optional fields include C<file> and
C<line> for specifying the location of the error.

In most cases you wouldn't generate and/or throw an exception object directly
from your code.  A better approach is to define a C<throw()> method in a
base class which does this for you.

The L<Badger::Base> module is an example of just such a module. You can use
this as a base class for your modules to inherit the
L<throw()|Badger::Base/throw()> method.

Here's an example of a module that implements a method which expects an
argument.  If if doesn't get the argument it's looking for then it throws
an exception via the inherited L<throw()|Badger::Base/throw()> method.
The exception type is C<example> and the additional information is
C<No argument specified>.

    package Your::Module;
    use base 'Badger::Base';

    sub example_method {
        my $self = shift;
        my $arg  = shift
            || self->throw( example => 'No argument specified' );

        # ...do something with ...
    }

The L<error()|Badger::Base/error()> provides a higher level of abstraction.
You provide the error message (which becomes the exception C<info>) and it
will generate an exception type based on the package name of your module.

    package Your::Module;
    use base 'Badger::Base';

    sub example_method {
        my $self = shift;
        my $arg  = shift
            || self->error('No argument specified' );

        # ...do something with ...
    }

In the example above, an exception will be thrown with a C<type> defined
as C<your.module>.  The module name is converted to lower case and the
package delimiters are replaced with dots.  There are configuration options
that allow you to define other exceptions types.  Consult the L<Badger::Base>
documentation for further information.

You can choose any values you like for C<type> and C<info>. The C<type> is
used to identify what kind of error occurred and should be a short word like
"C<example>", or a dot-separated sequence of words like
"C<example.file.missing">. In the latter case, dotted exception types are
assumed to represent a hierarchy where C<example.file.missing> error is a more
specialised kind of C<example.file> error, which in turn is a more specialised
kind of C<example> error. The L<match_type()> method takes this into account
when matching exception types.

    eval {
        # some code that throws an exception
    };
    if ($@) {
        if ($@->match_type('example')) {
            # caught 'example' or 'example.*' error
            # ...now do something
        }
        else {
            # re-throw any other exception types
            $@->throw;
        }
    }

The C<info> field should provide a more detailed error message in a format
suitable for human consumption.

=head2 STACK TRACING

The C<Badger::Exception> module also has a tracing mode which will
automatically save the caller stack at the point at which the error is thrown.
This allows you to inspect the full code path which led to the error from the
comfort of you exception catching code, rather than having to deal with it at
the point where the error is throw.

    # deep in your code somewhere.... in a class derived from Badger::Base
    $self->throw(
        database => 'The database is made of cheese',
        trace    => 1,
    );

The C<text()> method (which is called whenever the object is stringified)
will then append a stack track to the end of the generated message.

    # high up in your calling code:
    eval { $object->do_something_gnarly };

    if ($err = $@) {
        print $err;
        exit;
    }

You can also call the L<stack()> method to return the stored call stack
information, or the L<stack_trace()> method to see a textual summary.

You can enable the tracing behaviour for all exception objects by setting the
C<$TRACE> package variable.

    use Badger::Exception;
    $Badger::Exception::TRACE = 1;

The L<trace> import hook is provided as a short-cut for this.

    use Badger::Exception trace => 1;

=head1 IMPORT HOOKS

=head2 trace

This import hook can be used to set the C<$TRACE> package variable to
enable stack tracing for the L<Badger::Exception>  module.

    use Badger::Exception trace => 1

When stack tracing is enabled, the exception will store information
about the calling stack at the point at which it is thrown.  This information
will be displayed by the L<text()> method.  It is also available in raw form
via the L<stack()> method.

=head1 METHODS

=head2 new()

Constructor method for creating a new exception.

    my $exception = Badger::Exception->new(
        type => 'database',
        info => 'could not connect',
        file => '/path/to/file.pm',
        line => 420,
    );

=head2 type()

When called without arguments, this method returns the exception type,
as defined by the first argument passed to the C<new()> constructor method.

    my $type = $exception->type();

It can also be called with an argument to set a new type for the exception.

    $exception->type('database');

=head2 info()

When called without arguments, this method returns the information field
for the exception.

    my $info = $exception->info();

It can also be called with an argument to define new information for
the exception.

    $exception->info('could not connect');

=head2 file()

Method to get or set the name of the file in which the exception was raised.

    $exception->file('path/to/file.pm');
    print $exception->file;                 # /path/to/file.pm

=head2 line()

Method to get or set the line number at which the exception was raised.

    $exception->line(420);
    print $exception->line;                 # 420

=head2 text()

This method returns a text representation of the exception object.
The string returned is formatted as C<$type error - $info>.

    print $exception->text();   # database error - could not connect

This method is also bound to the stringification operator, allowing you to
simple C<print> the exception object to get the same result as calling
C<text()> explicitly.

    print $exception;   # database error - could not connect

=head2 trace()

Method to get or set the flag which determines if the exception captures
a stack backtrace at the point at which it is thrown.  It can be called
as an object method to affect an individual exception object, or as a class
method to get or set the C<$TRACE> package variable which provides the
default value for any exceptions created from then on.

    $exception->trace(1);               # object method
    print $exception->trace;            # 1

    Badger::Exception->trace(1);        # class method - sets $TRACE
    print Badger::Exception->trace;     # 1

=head2 match_type()

This method selects and returns a type string from the arguments passed
that is the nearest correct match for the current exception type.  This
is used to select the most appropriate handler for the exception.

    my $match = $exception->match_type('file', 'parser', 'database')
        || die "no match for exception\n";

In this example, the exception will return one of the values C<file>,
C<parser> or C<database>, if and only if its type is one of those
values.  Otherwise it will return undef;

Exception types can be organised into a hierarchical structure by
delimiting each part of the type with a period.  For example, the
C<database> exception type might be further divided into the more
specific C<database.connection>, C<database.query> and
C<database.server_on_fire> exception types.

An exception of type C<database.connection> will match a handler type
of C<database.connection> or more generally, C<database>.  The longer
(more specific) handler name will always match in preference to a shorter
(more general) handler as shown in the next example:

    $exception->type('database.connection');

    my $match = $exception->match_type('database', 'database.connection')
        || die "no match for exception\n";

    print $match;    # database.connection

When there is no exact match, the C<match_type()> method will return
something more general that matches.  In the following example, there
is no specific handler type for C<database.exploded>, but the more
general C<database> type still matches.

    $exception->type('database.exploded');

    my $match = $exception->match_type('database', 'database.connection')
        || die "no match for exception\n";

    print $match;    # database

You can also specify multiple exception types using a reference to a list.

    if ($exception->match_type(['warp.drive', 'shields'])) {
        ...
    }

Or using a single string of whitespace delimited exception types.

    if ($exception->match_type('warp.drive shields')) {
        ...
    }

You can also pass a reference to a hash array in which the keys are exception
types.  The corresponding value for a matching type will be returned.

    my $type_map = {
        'warp.drive'    => 'propulsion',
        'impulse.drive' => 'propulsion',
        'shields'       => 'defence',
        'phasers'       => 'defence'
    };

    if ($exception->match_type($type_map)) {
        ...
    }

=head2 throw()

This method throws the exception by calling C<die()> with the exception object
as an argument. If the C<$TRACE> flag is set to a true value then the method
will first save the pertinent details from a stack backtrace into the
exception object before throwing it.

=head2 stack()

If stack tracing is enabled then this method will return a reference to a list
of information from the caller stack at the point at which the exception was
thrown. Each item in the list is a reference to a list containing the
information returned by the inbuilt C<caller()> method. See
C<perldoc -f caller> for further information.

    use Badger::Exception trace => 1;

    eval {
        # some code that throws an exception object
        $exception->throw();
    };

    my $catch = $@;                 # exception object
    my $stack = $catch->stack;

    foreach my $caller (@$stack) {
        my ($pkg, $file, $line, @other_stuff) = @$caller;
        # do something
    }

The first set of information relates to the immediate caller of the
L<throw()> method.  The next item is the caller of that method, and so
on.

=head2 stack_trace()

If stack tracing is enabled then this method returns a text string summarising
the caller stack at the point at which the exception was thrown.

    use Badger::Exception trace => 1;

    eval {
        # some code that throws an exception object
        $exception->throw();
    };
    if ($@) {
        print $@->stack_trace;
    }

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Base>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
