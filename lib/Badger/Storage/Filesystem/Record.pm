#========================================================================
#
# Badger::Storage::Filesystem::Record
#
# DESCRIPTION
#   Storage record module using a filesystem as the backend.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Storage::Filesystem::Record;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Storage::Record';

sub init {
    my ($self, $config) = @_;
    $self->SUPER::init($config);

    # must have a file
    my $dir = $self->{ _file } 
            = $config->{ _file } 
            = $config->{ file } 
           || return $self->error_msg( missing => 'file' );

    return $self;
}

sub delete {
    my $self = shift;
    $self->{ _file }->delete;
}
    

1;

__END__

=head1 NAME

Badger::Storage::Filesystem::Record - storage record using filesystem backend

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
