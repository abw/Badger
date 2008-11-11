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
    constants   => 'TRUE',
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
        },
    };;

our $FORMAT  = '<type> error - <info>'  unless defined $FORMAT;
our $TYPE    = 'undef'                  unless defined $TYPE;
our $INFO    = 'no information'         unless defined $INFO;
our $ANON    = 'unknown'                unless defined $ANON;
our $TRACE   = 0                        unless defined $TRACE;


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
    $text .= " in $self->{ file }"      if $self->{ file };
    $text .= " at line $self->{ line }" if $self->{ line };
    
    if ($self->{ trace } && (my $trace = $self->trace)) {
        $text .= "\n" . $trace;
    }

    return $text;
}


sub trace {
    my $self = shift;
    my @lines;

    if (my $stack = $self->{ stack }) {
        foreach my $caller (@$stack) {
            push(@lines, "called from $caller->[3] in $caller->[1] at line $caller->[2]");
        }
    }
    
    return join("\n", @lines);
}


sub throw {
    my $self = shift;

    # save relevant information from caller stack for enhanced debugging
    if ($self->{ trace }) {
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
    my ($self, @types) = @_;
    my $type = $self->{ type };
    my %thash;
    @thash{ @types } = (1) x @types;

    while ($type) {
        return $type if $thash{ $type };

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
    print $exception->as_string();
    
    # use automagic stringification 
    print $exception;
    
    # throw exception
    $exception->throw;

=head1 DESCRIPTION

This module defines an object class for representing exceptions.  These are
simple objects that store various bits of information about an error 
condition.

The C<type> denotes what kind of error occurred (e.g. 'C<file>', 'C<parser>',
'C<database>', etc.). 

The C<info> field provides further information about the error (e.g.
'C<foo/bar.html not found>', 'C<parser error at line 42>', 'C<server is on
fire>', etc.)

Other optional fields include C<file> and C<line> for specifying the location
of the error.  

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
information, or the L<trace()> method to see a textual summary.

You can enable the tracing behaviour for all exception objects by setting the
C<$TRACE> package variable.

    use Badger::Exception;
    $Badger::Exception::TRACE = 1;

The C<trace> import hook is provided as a short-cut for this.

    use Badger::Exception trace => 1;

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

=head2 throw()

This method throws the exception by calling C<die()> with the exception object
as an argument. If the C<$DEBUG> flag is set to a true value then the method
will first save the pertinent details from a stack backtrace into the
exception object before throwing it.

TODO: stack backtrace example

=head2 stack()

Return

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
