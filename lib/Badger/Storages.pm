package Badger::Storages;

use Badger::Factory::Class
    version   => 0.01,
    debug     => 0,
    item      => 'storage',
    path      => 'Badger::Storage BadgerX::Storage',
    import    => 'class CLASS',
    constants => 'HASH',
    exports   => {
        any   => 'Storage',
    },
    storages  => {
        file  => 'Badger::Storage::Filesystem',
    };

sub Storage { 
    CLASS->storage(@_);
}

sub type_args {
    my $self = shift;
    my $type = shift;
    my $args;
    
    if (ref $type eq HASH) {
        $args = $type;
        $type = $args->{ type } 
            || return $self->error_msg( missing => 'storage type' );
    }
    else {
        $args = @_ == 1 ? shift : { @_ };
    }

    unless (ref $args eq HASH) {
        $args = {
            path => $args
        };
    }

    # $type can be a URI, e.g. file://path/to/dir
    if ($type =~ /^(\w+):(.*)/) {
        $args->{ path } ||= $2;
        $type = $1;
    }
    
    $self->debug("type_args() => [$type] [$args]") if DEBUG;
    
    return ($type, $args);
}

1;


=head1 NAME

Badger::Storages - factory module for Badger::Storage objects

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
    
    # see Badger::Storage for further examples

=head1 DESCRIPTION

This clumsily named module implements a subclass of L<Badger::Factory>
for loading and instantiating L<Badger::Storage> object (or strictly speaking,
subclasses of L<Badger::Storage> such as L<Badger::Storage::Filesystem>).

You can call the C<storage()> method as a class method to load a storage
module and instantiate an instance of it.

    my $storage = Badger::Storages->storage( file => '/path/to/dir' );

You can also create a C<Badger::Storages> object and call the L<storage()>
method as an object method.  Creating a C<Badger::Storages> object allows
you to specify your own storage modules, a custom lookup path, or any other
valid configuration options for the storage factory.

    my $factory = Badger::Storages->new(
        storage_path => ['My::Storage', 'Badger::Storage', 'BadgerX::Storage'],
        storages     => {
            mumcached => 'My::MumCache::Storage',   # ask mum where it is
        },
    };

You can now load the entirely fictional C<My::MumCache::Storage> module as
follows:

    my $storage = $factory->storage(
        mumcached => { 
            # any options for the My::Mum::Storage module
        }
    );

Or any module under the C<My::Storage>, C<Badger::Storage> or
C<BadgerX::Storage> namespaces:

    my $storage = $factory->storage(
        example => { 
            # any options for the My::Storage::Example module
        }
    );

=head1 EXPORTABLE SUBROUTINES

=head2 Storage()

This function of convenience is a shortcut for fetching a storage object.

    use Badger::Storages 'Storage';
    my $storage = Storage('file:/path/to/dir');

It is equivalent to:

    use Badger::Storages;
    my $storage = Badger::Storages->storage('file:/path/to/dir');

=head1 METHODS

=head2 storage($type,@args)

This is the main method used to fetch a L<Badger::Storage> object. The first
argument is the storage type, corresponding to the name of a
L<Badger::Storage> subclass module.

    my $storage = Badger::Storages->storage( filesystem => '/path/to/dir' );

In this example the C<filesystem> type is mapped to
L<Badger::Storage::Filesystem>. You can also use the shorthand form of
C<file>.

    my $storage = Badger::Storages->storage( file => '/path/to/dir' );

You can even go one step further and specify the entire thing as a URL

    my $storage = Badger::Storages->storage('file:/path/to/dir');

These are all shorthand for the following:

    my $storage = Badger::Storages->storage( 
        filesystem => {
            path => '/path/to/dir',
        }
    );

If you prefer you can pass a single reference to a hash array with the 
storage type defined as the C<type> item.

    my $storage = Badger::Storages->storage( 
        {
            type => 'filesystem',
            path => '/path/to/dir',
        }
    );

Any other configuration arguments destined for the particular storage 
module can be added to this hash array.  For example, to create a 
L<Badger::Storage::Filesystem> object that stores YAML encoded files in
C</tmp/badger_data>, you can write this:

    my $storage = Badger::Storages->storage( 
        file => {
            path  => '/path/to/dir',
            codec => 'yaml',
        }
    );

See the documentation for L<Badger::Storage> for information about what 
you can do with the storage object returned.

=head1 INTERNAL METHODS

=head2 type_args(@args)

This internal method is used to massage the arguments passed to the 
L<storage()> method into a canonical format.

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
