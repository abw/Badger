package Badger::Storage::Memory;

use Badger::Debug ':dump';
use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Storage',
    utils       => 'params';

sub init_storage {
    my ($self, $config) = @_;
    $self->{ items } = { };
    return $self;
}

sub fetch {
    my $self = shift;
    my $name = shift;
    return $self->{ items }->{ $name }
        || $self->decline_msg( not_found => $name );
}


sub store {
    my $self = shift;
    my $name = shift;
    $self->{ items }->{ $name } = params(@_);
}


sub delete {
    my $self = shift;
    my $name = shift;
    return delete $self->{ items }->{ $name }
        || $self->decline_msg( not_found => $name );
}

1;

__END__

=head1 NAME

Badger::Storage::Memory - memory-based storage module

=head1 SYNOPSIS

    use Badger::Storage::Memory;
    
    # create a storage object
    my $storage = Badger::Storage::Memory->new;
    
    # some sample data
    my $data = {
        message => 'Hello World!',
        numbers => [1.618, 2.718, 3.142],
    };
    
    # create a new record
    my $id = $storage->create($data);
    
    # fetch data for identifier - returns undef if not found
    $data = $storage->fetch($id)
        || die $storage->error;
    
    # insert/update data using identifier
    $storage->store($id, $data);

    # delete data using identifier
    $storage->store($id, $data);

=head1 DESCRIPTION

The L<Badger::Storage::Memory> module is a subclass of L<Badger::Storage>
for storing data in memory.

=head1 METHODS

The following methods are defined in addition to those inherited from
the L<Badger::Storage>, L<Badger::Prototype> and L<Badger::Base> base classes.

=head2 store($id,$data)

Stores C<$data> in memory using C<$id> as an index key.

=head2 fetch($id)

Returns the data stored in memory for the index key C<$id> or C<undef> if
no data is defined for it.

=head2 delete($id)

Permanently deletes the data in memory associated with the C<$id> index key.

=head1 INTERNAL METHODS

=head2 init_storage($config)

This method is used internally to initialise the memory storage object.

=head1 AUTHOR

Andy Wardley L<http://wardley.org>

=head1 COPYRIGHT

Copyright (C) 2007-2009 Andy Wardley.  All Rights Reserved.

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
