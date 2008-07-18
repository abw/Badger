#========================================================================
#
# Badger::Storage::Record
#
# DESCRIPTION
#   Base class storage record module.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Storage::Record;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Base',
    get_methods => 'table id';

our $AUTOLOAD;

sub init {
    my ($self, $config) = @_;
    $self->{ table } = $config->{ table }
        || return $self->error_msg( missing => 'table reference' );
    $self->{ data  } = $config->{ data }
        || return $self->error_msg( missing => 'record data' );
    $self->{ id } = $config->{ id }
        || return $self->error_msg( missing => 'record id' );
    return $self;
}

sub AUTOLOAD {
    my ($self, @args) = @_;
    my ($name) = ($AUTOLOAD =~ /([^:]+)$/ );
    return if $name eq 'DESTROY';

    $self->debug("AUTOLOAD $name\n") if $DEBUG;
    if (exists $self->{ data }->{ $name }) {
        return $self->{ data }->{ $name };
    }
    else {
        return $self->error_msg( 
            bad_method => $name, ref $self, (caller())[1,2] 
        );
    }
}


1;

__END__

=head1 NAME

Badger::Storage::Record - base class storage record

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
