#========================================================================
#
# Badger::Storage::Store
#
# DESCRIPTION
#   Base class storage module.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Storage::Store;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Base',
    get_methods => 'hub',
    messages    => {
        existing     => 'Table %s already exists: %s',
        non_existing => 'Table %s does not exist: %s',
    };

use Badger::Hub;
use Badger::Storage::Table;
use Badger::Storage::Record;
our $HUB    = 'Badger::Hub';
our $TABLE  = 'Badger::Storage::Table';
our $RECORD = 'Badger::Storage::Record';
our @PARAMS = qw( hub table record );

sub init {
    my ($self, $config) = @_;

    # The hub, table and record classes can be passed as named parameters
    # or we grok them from the class variables, allowing for subclassing.
    foreach my $arg (@PARAMS) {
        $self->{ $arg } = $config->{ $arg } || $self->class->any_var(uc $arg);
    }

    return $self;
}

sub table {
    my $self = shift;
    my $name  = $self->table_id(shift);
    return $self->{ tables }->{ $name } 
       ||= $self->try( open_table => $name )
       ||  $self->create_table($name);      # TODO: this should be optional
}

sub table_id {
    my $self = shift;
    shift || return $self->error_msg( missing => 'table' );
}

sub table_object {
    my $self   = shift;
    my $config = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };
    $config->{ store } = $self;
    $self->{ table }->new($config);
}

sub record_object {
    # trust record to validate arguments
    shift->{ record }->new(@_);
}

# these are specific to the backend subclass
sub create_table { shift->not_implemented }
sub open_table   { shift->not_implemented }
sub delete_table { shift->not_implemented }

sub close_table {
    my $self  = shift;
    my $id    = $self->table_id(shift);
    my $table = delete $self->{ tables }->{ $id }
        || return $self->error_msg( not_found => table => $id );
    $table->close;
}


1;

__END__

=head1 NAME

Badger::Filesystem::Store - storage backend using the filesystem

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
