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
    set_methods => 'type',
    constants   => 'TRUE',
    as_text     => 'text',
    is_true     => 1;

our $FORMAT  = '<type> error - <info>'  unless defined $FORMAT;
our $TYPE    = 'undef'                  unless defined $TYPE;
our $INFO    = 'no information'         unless defined $INFO;
our $ANON    = 'unknown'                unless defined $ANON;


sub init {
    my ($self, $config) = @_;
    $self->{ type } = $config->{ type } || $self->class->any_var('TYPE');
    $self->{ info } = $config->{ info } || '';
    $self->{ file } = $config->{ file };
    $self->{ line } = $config->{ line };
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


#------------------------------------------------------------------------
# text()
#
# Return a text string containing the type and info fields.
#------------------------------------------------------------------------

sub text {
    my $self   = shift;
    my $format = shift || $self->class->any_var('FORMAT');

    $format =~ s/<(\w+)>/defined $self->{ $1 } ? $self->{ $1 } : "(no $1)"/eg;
    $format .= " in $self->{ file }" if $self->{ file };
    $format .= " at line $self->{ line }" if $self->{ line };

    return $format;
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
    die $exception;

=head1 DESCRIPTION

This module defines an object class for representing exceptions.  An
exception is a structured error with C<type> and C<info> fields.  The
C<type> denotes what kind of error occurred (e.g. 'file', 'parser',
'database', etc.).  The C<info> field provides further information
about the error (e.g. 'foo/bar.html not found', 'parser error at line
42', 'server is on fire', etc.)

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
