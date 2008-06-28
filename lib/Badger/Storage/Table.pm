#========================================================================
#
# Badger::Storage::Table
#
# DESCRIPTION
#   Base class storage table module.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Storage::Table;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Base',
    get_methods => 'store',
    constants   => 'HASH',
    messages    => {
        existing     => 'Record %s already exists: %s',
        non_existing => 'Record %s does not exist: %s',
    };

use Badger::Storage::Record;
our $RECORD = 'Badger::Storage::Record';
our @PARAMS = qw( record );

sub init {
    my ($self, $config) = @_;
    $self->{ store } = $config->{ store }
        || return $self->error_msg( missing => 'store reference' );

    # The hub, table and record classes can be passed as named parameters
    # or we grok them from the class variables, allowing for subclassing.
    foreach my $arg (@PARAMS) {
        $self->{ $arg } = $config->{ $arg } || $self->class->any_var(uc $arg);
    }

    return $self;
}

sub hub {
    $_[0]->{ hub } ||= $_[0]->{ store }->hub;
}

sub record_id {
    my $self = shift;
    shift || return $self->error_msg( missing => 'record' );
}

sub record_object {
    my $self   = shift;
    my $record = $self->{ record } ||= $self->{ store }->record;
    my $config = @_ && ref $_[0] eq HASH ? shift : { @_ };
    $config->{ table } = $self;
    $record->new($config);
}

sub create_record { shift->not_implemented }
sub fetch_record  { shift->not_implemented }
sub delete_record { shift->not_implemented }


1;

__END__

=head1 NAME

Badger::Storage::Table - base class storage table

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
