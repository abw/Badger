#========================================================================
#
# Badger::Storage::Filesystem::Store
#
# DESCRIPTION
#   Backend storage module using the filesystem.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Storage::Filesystem::Store;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Storage::Store',
    get_methods => 'hub directory filesystem';

use Badger::Hub;
use Badger::Filesystem;
use Badger::Storage::Filesystem::Table;
use Badger::Storage::Filesystem::Record;
our $TABLE  = 'Badger::Storage::Filesystem::Table';
our $RECORD = 'Badger::Storage::Filesystem::Record';

*dir = \&directory;
*fs  = \&filesystem;

sub init {
    my ($self, $config) = @_;
    $self->SUPER::init($config);

    # must have a root directory
    my $dir = $self->{ directory } 
            = $config->{ directory } 
           || $config->{ dir }
           || return $self->error_msg( missing => 'directory' );

    # create a virtual filesystem
    $self->{ filesystem } = $self->{ hub }->filesystem( root => $dir );
    
#    $self->debug("virtual f/s root: $self->{ filesystem } / ", $self->{ filesystem }->root, "\n");
    return $self;
}

sub table_id {
    my $self = shift;
    my $name = shift || return $self->error_msg( missing => 'table' );
    $name =~ s/\W+/_/g;
    $name;
}

sub table_dir { 
    my $self = shift;
    $self->{ filesystem }->directory( $self->table_id(shift) );
}

sub create_table { 
    my $self = shift;
    my $id   = $self->table_id(shift);
    my $dir  = $self->{ filesystem }->directory($id);
    return $self->error_msg( existing => directory => $dir ) if $dir->exists;
    $dir->create;
    $self->debug("created new filesystem table for $id in ", $dir->definitive, "\n") if $DEBUG;
    $self->table_object( directory => $dir );
}

sub open_table {
#    local $DEBUG = 1;
    my $self = shift;
    my $id   = $self->table_id(shift);
    my $dir  = $self->{ filesystem }->directory($id);
    my $args = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };
    $self->debug("open_table($id, ", $self->dump_data_inline($args), ")\n") if $DEBUG;
    return $self->error_msg( non_existing => directory => $dir ) unless $dir->exists;
    $self->debug("opening filesystem table for $id in $dir\n") if $DEBUG;
    $args->{ directory } = $dir;
    my $t = $self->table_object($args);
    return $t;
}

sub delete_table {
    my $self = shift;
    my $id   = $self->table_id(shift);
    my $dir  = $self->{ filesystem }->directory($id);
    return $self->error_msg( non_existing => directory => $dir ) unless $dir->exists;
    $self->close_table($id) if $self->{ tables }->{ $id };
    $self->debug("deleting filesystem table for $id in $dir\n") if $DEBUG;
    $dir->delete;
}

1;

__END__

=head1 NAME

Badger::Storage::Filesystem::Store - storage backend using the filesystem

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
