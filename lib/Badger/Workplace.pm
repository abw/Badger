package Badger::Workplace;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Base',
    import      => 'class',
    utils       => 'Dir', # resolve_uri truelike falselike params self_params extend',
    accessors   => 'root urn',
    alias       => {
        directory => \&dir,
    };


#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    $self->init_workplace($config);
    return $self;
}

sub init_workplace {
    my ($self, $config) = @_;

    # The neophyte flag is used to indicate the special case where the root 
    # directory (and perhaps other support files, data, etc) don't yet exist
    # because some other bit of code is in the process of creating it anew.
    my $neophyte = $config->{ nephyte } || 0;

    # The root directory must exist unless this is a neophyte in which case 
    # we can create the directory.
    my $dir  = $config->{ root      }
            || $config->{ dir       } 
            || $config->{ directory }
            || return $self->error_msg( missing => 'root directory' );
    my $root = Dir($dir, $config->{ filespec });

    if (! $root->exists) {
        if ($self->{ neophyte }) {
            $root->mkdir;
        }
        else {
            return $self->error_msg( invalid => root => $dir );
        }
    }

    $self->{ root } = $root;
    $self->{ urn  } = $config->{ urn } // $root->name;
    $self->{ uri  } = $config->{ uri } // $self->{ urn };

    return $self;
}

#-----------------------------------------------------------------------------
# Methods for accessing directories and files relative to the workplace root
#-----------------------------------------------------------------------------

sub dir {
    my $self = shift;
    return @_
        ? $self->root->dir(@_)
        : $self->root;
}

sub file {
    my $self = shift;
    return $self->root->file(@_);
}

1;

=head1 NAME

Badger::Workplace - a place to do work

=head1 DESCRIPTION

This is a very simple base class for modules that operate on or around 
a particular filesystem directory.  See L<Badger::Config::Filesystem> for an 
example of it in us.

=head1 CONFIGURATION OPTIONS

=head2 root / dir / directory

Any of C<root>, C<dir> or C<directory> can be provided to specify the root
directory of the workplace.

=head1 METHODS

=head2 dir($name) / directory($name)

Returns a L<Badger::Filesystem::Directory> object for a named sub-directory 
relative to the workplace root.

When called with any arguments it returns a L<Badger::Filesystem::Directory> 
object for the workplace root directory.

=head2 file($name)

Returns a L<Badger::Filesystem::File> object for a named files
relative to the workplace root.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
