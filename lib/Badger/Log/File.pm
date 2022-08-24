#========================================================================
#
# Badger::Log::File
#
# DESCRIPTION
#   Subclass of Badger::Log for logging messages to a file.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Log::File;

use Badger::Class
    version    => 0.02,
    base       => 'Badger::Log',
    filesystem => 'FS',
    utils      => 'Now',
    config     => [
        'filesystem|method:FS',
        'filename|class:FILENAME',
        'filename_format|class:FILENAME_FORMAT',
        'keep_open|class:KEEP_OPEN=0',
    ],
    messages  => {
        no_filename => 'No filename or filename_format specified for log file',
        started     => 'Started logging',
    };

our $FORMATS = {
    DATE    => '%Y-%m-%d',
    TIME    => '%H-%M-%S',
    YEAR    => '%Y',
    MONTH   => '%m',
    DAY     => '%d',
    HOURS   => '%H',
    MINUTES => '%M',
    SECONDS => '%S',
};

sub init {
    my ($self, $config) = @_;
    $self->init_log($config);
    $self->init_file($config);
    return $self;
}

sub init_file {
    my ($self, $config) = @_;

    # init_log() has already called configured() which will copy the filename
    # parameter into $self.  We don't make the filename parameter mandatory
    # in the config schema because that will report missing parameters
    # using error_msg() which has been redefined in Badger::Log.  So we
    # check for it here and use our "backdoor" _error_msg() method.
    return $self->_error_msg('no_filename')
        unless defined $self->{ filename }
            || defined $self->{ filename_format };

    # if filename is set but not filename_format then this is a no-op
    # as expand_filename() will return the filename
    $self->{ filename } = $self->expand_filename;

    $self->info_msg('started');
}

sub expand_filename {
    my $self     = shift;
    my $format   = $self->{ filename_format } || return $self->{ filename };
    my $strftime = $format;
    # expand any <XXXX> markers to convert to strftime format
    $strftime =~ s/<(\w+)>/$FORMATS->{ $1 } || $1/ge;
    # now format using strftime
    return Now->format($strftime);
}

sub filename_changed {
    my $self     = shift;
    my $filename = $self->expand_filename;
    return $filename ne $self->{ filename }
        ? ($self->{ filename } = $filename)
        : undef;
}

sub file {
    my $self     = shift;
    my $filename = $self->{ filename };
    return ($self->{ file } = $self->{ filesystem }->file($filename));
}

sub filehandle {
    my $self = shift;
    if ($self->filename_changed) {
        $self->release;
    }
    return $self->acquire;
}

sub acquire {
    my $self = shift;

    # Badger::Filesystem::File::append() method returns file handle open for append
    return $self->{ handle }
        ||= $self->file->append;
}

sub release {
    my $self = shift;
    my $fh   = delete $self->{ handle } || return;
    $fh->close;
}


sub log {
    my ($self, $level, $message) = @_;
    my $handle = $self->filehandle;
    my $output = sprintf($self->format($level, $message));
    $output =~ s/\n+$//;
    $handle->printflush($output, "\n");

    $self->release unless $self->{ keep_open };
}


sub DESTROY {
    shift->release;
}


1;

__END__

=head1 NAME

Badger::Log::File - writes log messages to a log file

=head1 SYNOPSIS

    use Badger::Log::File;

    my $log = Badger::Log::File->new({
        filename  => '/var/log/badger.log',
        keep_open => 1,
    });

    $log->log('a debug message');
    $log->info('an info message');
    $log->warn('a warning message');
    $log->error('an error message');
    $log->fatal('a fatal error message');

=head1 DESCRIPTION

This module is a subclass of L<Badger::Log> that implements a simple
mechanism for logging messages to a file.  It uses L<Badger::Filesystem>
for all the underlying file operations.

=head1 CONFIGURATION OPTIONS

The following configuration options are available in addition to those
inherited form the L<Badger::Log> base class.

=head2 filename

The name of the log file which you want messages appended to.  Either this or the
L<filename_format> option must be provided.

=head2 filename_format

A format which can be used to generate a filename to write messages to.
This can include any of the C<strftime()> character sequences, e.g.
C<%Y> for the four digit year, C<%m> for a two digit month number, C<%d>
for a two digit day of the month, etc.

    my $log = Badger::Log::File->new({
        filename_format  => '/var/log/badger-%Y-%m-%d.log',
        keep_open => 1,
    });

If, like me, you find it hard to remember the C<strftime()> character sequences,
then you can use an alternate format where the elements of the date and/or
time are encoded as upper case words embedded in angle brackets.
e.g. C<badger-E<lt>DATEE<gt>.log>, or C<badger-E<lt>YEARE<gt>-E<lt>MONTHE<gt>.log>.

The words that can be embedded this way, and their corresponding C<strftime()> character
sequences are:

    DATE    => '%Y-%m-%d'       # e.g. 2022-08-24
    TIME    => '%H-%M-%S'       # e.g. 13:54:07
    YEAR    => '%Y'             # e.g. 2022
    MONTH   => '%m'             # e.g. 08
    DAY     => '%d'             # e.g. 24
    HOURS   => '%H'             # e.g. 13
    MINUTES => '%M'             # e.g. 54
    SECONDS => '%S'             # e.g. 07

The module will automatically create a new logfile when the C<filename_format>
generates a filename that is different to any previous value.

=head2 filesystem

An optional reference to a L<Badger::Filesystem> object, or the name of a
filesystem class having a L<file()|Badger::Filesystem/file()> method similar
to that in L<Badger::Filesystem>. This defaults to the L<Badger::Filesystem>
class.

=head2 keep_open

A flag indicating if the log file should be kept open between calls to
logging methods.  The default value is C<0> meaning that the file will be
opened for each message and closed again afterwards.  Set it to any true
value to have the file kept open.

=head1 METHODS

The following methods are implemented in addition to those inherited
from L<Badger::Log> and its base classes.

=head2 log($level,$message)

This method redefines the L<log()|Badger::Log/log()> method in
L<Badger::Log> to write logging messages to the log file.

=head2 INTERNAL METHODS

=head2 init(\%config)

Custom initialiser method which calls the base class
L<init_log()|Badger::Log/init_log()> method followed by the L<init_file()>
method.

=head2 init_file(\%config)

Custom initialiser method which handles the configuration and initialisation
of the file-specific parts of the logger.

=head2 expand_filename()

Expands the format defined by the C<filename_format> configuration option
to a filename using the current date and time.

If C<filename_format> has not been specified then it returns the value of
the C<filename> configuration option.

=head2 filename_changed()

Calls L<expand_filename()> to expand any C<filename_format> and compares it
to the current C<filename> (which may have been generated by a previous call
to this method).

If they are the same then it returns C<undef>.  Otherwise it saves the new
filename to the internal C<filename> value and returns it.

=head2 file()

Returns a reference to a L<Badger::Filesystem::File> object based on the
C<filename> which can either be defined as a static configuration option
or will be generated by the L<expand_filename()> method from the
C<filename_format> configuration option.

=head2 filehandle()

Returns a filehandle for the current logfile.  If the filename has changed
since the last call this method (determined by calling L<filename_changed()>)
then any existing filehandle is closed (by calling L<release()>) and the new
file is opened to return a new filehandle (by calling L<acquire()>).

=head2 acquire()

This method acquires a file handle (an L<IO::File> object) for the specified
L<filename>, opened ready for appending log messages.

=head2 release()

The method releases a previously acquired file handle.  i.e. it closes the
log file.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2005-2022 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Log>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:



