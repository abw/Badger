package Badger::Storage;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Prototype',
    init_method => 'configure init_storage',
    utils       => 'md5_hex',
    config      => [
        'id_length|class:ID_LENGTH=32',
    ];

sub init_storage {
    # return $self in base class - most subclasses will redefine this method
    $_[0];
}

sub create {
    my $self = shift;
    my $id   = $self->generate_id(@_);
    $self->store($id, @_);
    return $id;
}

sub store {
    shift->not_implemented;
}

sub fetch {
    shift->not_implemented;
}

sub delete {
    shift->not_implemented;
}

sub generate_id {
    my $self = shift;
    my $text = __PACKAGE__ . time() . md5_hex( 
        time() . rand() . $$ . { } 
    );
    return substr( md5_hex($text), 0, $self->{ id_length } );
}
    
1;

__END__

=head1 NAME

Badger::Storage - base class module for persistent storage

=head1 SYNOPSIS

    # Storage() is a shortcut to Badger::Storages->storage() which
    # loads and instantiates instances of Badger::Storage subclasses
    use Badger::Storages 'Storage';

    # the following are all equivalent
    my $storage = Storage('file:/path/to/directory');
    my $storage = Storage( file => '/path/to/directory' );
    my $storage = Storage({
        type => file,
        path => '/path/to/directory',
    });
    
    # specifying storage option (codec), the following are equivalent
    my $storage = Storage(
        file => {
            path  => '/path/to/directory',
            codec => 'json',
        }
    );
    my $storage = Storage({
        type  => file,
        path  => '/path/to/directory',
        codec => 'json',
    });
    
    # using the storage object
    my $data = { 
        # ...some perl data... 
    };
    
    # create() stores the data under a new identifier
    my $id = $storage->create($data);
    
    # store() stores data under an identifier
    $storage->store($id, $data);
    
    # fetch() fetches data under an identifier
    my $data = $storage->fetch($id)
        || die $storage->reason;        # not found
    
    # delete() delete the data under an identifier
    $storage->delete($id);

=head1 DESCRIPTION

This module implements an abstract interface for storing persistent data.
It is not intended to be used by itself, but as a base class for other modules
that implement the specifics of storing data in a filesystem, database, or
some other environment.

The L<Badger::Storage::Filesystem> module is a subclass for storing data in
files on your local filesystem.  Other storage modules are expected to follow
in the fullness of time.

=head1 METHODS

=head2 create($data)

The C<create()> method first calls the the L<generate_id()> method to 
generate a new identifier for the data.  It then call the L<store()> method, 
passing the identifier along with the data passed to it as an argument.
It returns the newly created identifier.

    my $id = $storage->create($data);

It returns the newly created identifier for the data record. Errors are thrown
as L<exceptions|Badger::Exception>. You can use the
L<try()|Badger::Base/try()> method inherited from L<Badger::Base> if you want
to catch any exceptions.

    my $id = $storage->try->create($data)
        || warn $storage->error;

This is equivalent to:

    my $id = eval { $storage->create($data) }
        || warn $storage->error;

=head2 store($id,$data)

This method is used to store data.  The first argument is a unique identifier
for the data.  The second argument should be a reference to the data to be
stored (e.g. a hash or list reference).

    $storage->store($id, $data);

It returns a true value which you can test if you want the warm glow of
satisfaction that it performed its job as expected.  

    if ($storage->store($id, $data)) {
        # phew!
    }

However, all errors are thrown as L<exceptions|Badger::Exception> so there's
no need to test the return value at all. If the method returns, then it
succeeded. You can use C<eval { }> if you want to trap errors, or the
L<try()|Badger::Base/try()> method, as shown in the documentation for 
L<create()>.

=head2 fetch($id)

This method is used to fetch data.  The single argument is a unique 
identifier for the data, such as that returned by a previous call to the 
L<create()> method, or passed as the first argument in a call to the 
L<store()> method.

    my $data = $storage->fetch($id);

If the data cannot be found then the method returns C<undef> by calling
its own L<decline()|Badger::Base/decline()> method (inherited from 
L<Badger::Base>).  You can call the L<error()|Badger::Base/error()> method
to view the message generated.

    my $data = $storage->fetch('foo')
        || print $storage->error;       # e.g. File not found: foo

It is important to understand the difference between the method I<declining>
to return a value and an I<error>. If the data for the requested identifier
cannot be found then the method returns C<undef> by calling its own
L<decline()|Badger::Base/decline()> method. This is considered part of its
normal operation. It is I<not> an error to ask for something that doesn't
exists. The method will politely turn you away.

On the other hand, if the method is prevented from looking for the data and
either returning it or declining, for whatever reason, then an
L<exceptions|Badger::Exception> will be thrown.  It could be that the 
the file contents got mangled, the database is offline, the network is
down, or maybe you forgot to pass an identifier as a parameter.  These are
all error conditions that are considered I<outside> of normal operation.

If your application dictates that a missing resource I<is> an error then you
should add the appropriate code to any call to C<fetch()>. For example, if
your application is loading a configuration file then you probably want to
know right away if the configuration file is missing, misnamed, or otherwise
unloaded for whatever reason.

    my $config = $storage->fetch( $config_file_name )
        || die $storage->error;

=head2 delete($id)

Permanently deletes the data associated with the identifier passed as an
argument.

    $storage->delete($id);

Returns a true value on success. If the data does not exist then it returns
C<undef>. All errors are thrown as L<exceptions|Badger::Exception>. As with
L<fetch()>, deleting a resource that does not exists is not considered an
error.  The method will L<decline()|Badger::Base/decline()> gracefully.

=head1 INTERNAL METHODS

=head2 init_storage($config)

This method should be redefined by subclasses to perform any storage-specific
initialisation.

=head2 generate_id(@args)

This method is called by the L<create()> method to generate a new identifier
for the data record.  It is passed all the arguments that were passed to 
the L<create()> method.  In the base class this method generates a random
MD5 hex string.  Subclasses can redefine it to do something different.

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
