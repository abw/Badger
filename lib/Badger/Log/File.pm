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
    version    => 0.01,
    base       => 'Badger::Log',
    filesystem => 'FS',
    config     => [
        'filesystem|method:FS',
        'filename|class:FILENAME',
        'keep_open|class:KEEP_OPEN=0',
    ],
    messages  => {
        no_filename => 'No filename specified for log file',
        started     => 'Started logging',
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
    my $filename = $self->{ filename };

    return $self->_error_msg('no_filename')
        unless defined $filename;
    
    $self->{ file } = $self->{ filesystem }->file($filename);

    $self->info_msg('started');
}

sub acquire {
    my $self = shift;

    # Badger::Filesystem::File::append() method returns file handle open for append
    return $self->{ handle }
       ||= $self->{ file }->append;
}

sub release {
    my $self = shift;
    my $fh   = delete $self->{ handle } || return;
    $fh->close()
# TODO: does IO::File throw an error on close fail?
#        || return $self->base_error_msg( bad_close => $self->{ filename }, $! );
}

sub log {
    my ($self, $level, $message) = @_;

    my $handle = $self->{ handle } 
        || $self->acquire;

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
mechanism for logging messages to a file.

=head1 CONFIGURATION OPTIONS

The following configuration options are available in addition to those
inherited form the L<Badger::Log> base class.

=head2 filename

The name of the log file which you want messages appended to.  This parameter
is mandatory.

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

This method redefines the L<log()|Badger::Log::log()> method in 
L<Badger::Log> to write logging messages to the log file.

=head2 INTERNAL METHODS

=head2 init(\%config)

Custom initialiser method which calls the base class
L<init_log()|Badger::Log/init_log()> method followed by the L<init_file()>
method.

=head2 init_file(\%config)

Custom initialiser method which handles the configuration and initialisation
of the file-specific parts of the logger.

=head2 acquire()

This method acquires a file handle (an L<IO::File> object) for the specified
L<filename>, opened ready for appending log messages. 

=head2 release()

The method releases a previously acquired file handle.  i.e. it closes the
log file.

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



