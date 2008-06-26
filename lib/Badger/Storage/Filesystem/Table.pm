#========================================================================
#
# Badger::Storage::Filesystem::Table
#
# DESCRIPTION
#   Storage table module using a filesystem backend.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Storage::Filesystem::Table;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Storage::Table',
    get_methods => 'directory',
    constants   => 'HASH',
    constant    => {
        CODEC   => 'CODEC',
    };

use Badger::Storage::Filesystem::Record;
our $RECORD = 'Badger::Storage::Filesystem::Record';
our $CODEC  = 'storable';

*dir = \&dir;

sub init {
    my ($self, $config) = @_;
    $self->SUPER::init($config);

    my $hub = $self->hub;
    my $dir = $config->{ directory }
           || $config->{ dir }
           || return $self->error_msg( missing => 'directory' );
    
    # upgrade $dir to Badger::Filesystem::Directory object if necessary
    $dir = $hub->filesystem->directory($dir) unless ref $dir;
    $self->{ directory } = $dir;
    
    # install a codec
    my $codec = $config->{ codec } || $self->class->any_var(CODEC);
    $codec = $hub->codec($codec) unless ref $codec;
    $self->{ codec   } = $codec;
    $self->{ encoder } = $codec->encoder;
    $self->{ decoder } = $codec->decoder;
    
    return $self;
}

sub record_id {
    my $self = shift;
    my $name = shift || return $self->error_msg( missing => 'record' );
    $name =~ s/\W+/_/g;
    $name;
}

sub record_file {
    my $self = shift;
    $self->{ directory }->file( $self->record_id(shift) );
}

sub create_record {
    my $self = shift;
    my $id   = $self->record_id(shift);
    my $file = $self->{ directory }->file($id);
    return $self->error_msg( existing => file => $file ) if $file->exists;
    my $data = @_ && ref $_[0] eq HASH ? shift : { @_ };
    $file->write( $self->encode($data) );
    $self->debug("created new filesystem record for $id in ", $file->definitive, "\n") if $DEBUG;
    $self->record_object( file => $file, data => $data );
}

sub fetch_record {
    my $self = shift;
    my $id   = $self->record_id(shift);
    my $file = $self->{ directory }->file($id);
    # decline - because a record not existing is not an error
    return $self->decline_msg( non_existing => file => $file ) unless $file->exists;
    my $data = $file->read;
    $self->debug("fetched filesystem record for $id in $file\n") if $DEBUG;
    $self->record_object( file => $file, data => $self->decode($data) );
}

sub delete_record {
    my $self   = shift;
    my $record = $self->fetch_record(@_)
        || return $self->error( $self->reason );
    $self->debug("deleting filesystem record for $record\n") if $DEBUG;
    $record->delete;
}

sub encode {
    my $self = shift;
    $self->{ encoder }->(@_);
}

sub decode {
    my $self = shift;
    $self->{ decoder }->(@_);
}



1;

__END__

=head1 NAME

Badger::Storage::Filesystem::Table - storage table using filesystem backend

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

TODO

=head1 METHODS

TODO

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
