package Badger::Workplace;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Base',
    import      => 'class',
    utils       => 'Dir resolve_uri', # resolve_uri truelike falselike params self_params extend',
    constants   => 'SLASH',
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

    # The mkdir flag is used to indicate the special case where the root 
    # directory (and perhaps other support files, data, etc) don't yet exist
    # because some other bit of code is in the process of creating it anew.
    my $mkdir = $config->{ mkdir } || 0;

    # The filespec can be specified to provide a hash of options for files
    my $filespec = $config->{ filespec } || { };

    # The root directory must exist unless this is a neophyte in which case 
    # we can create the directory.
    my $dir  = $config->{ root      }
            || $config->{ dir       } 
            || $config->{ directory }
            || return $self->error_msg( missing => 'root directory' );
    my $root = Dir($dir, $filespec);

    if (! $root->exists) {
        if ($mkdir) {
            $root->mkdir;
        }
        else {
            return $self->error_msg( invalid => root => $dir );
        }
    }

    $self->{ root  } = $root;
    $self->{ urn   } = $config->{ urn } // $root->name;
    $self->{ uri   } = $config->{ uri } // $self->{ urn };
    $self->{ mkdir } = $mkdir;

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

sub uri {
    my $self = shift;
    return @_
        ? sprintf("%s%s", $self->{ uri }, resolve_uri(SLASH, @_))
        : $self->{ uri };
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

=head2 urn

This option can be set to define a Universal Resource Name (URN) for the 
workplace for reference purposes.  If undefined it defaults to the name of
the root directory.

=head2 uri

This option can be set to define a Universal Resource Identifier (URN) for the 
workplace for reference purposes.  If undefined it defaults to the name of
the value of L<urn>.

=head2 mkdir

The object constructor will fail if the root directory specified via L<root>
(or C<dir> or C<directory>) does not exist.  Alternately, set the C<mkdir>
option to any true value and the directory will be created automatically.

=head1 METHODS

=head2 dir($name) / directory($name)

Returns a L<Badger::Filesystem::Directory> object for a named sub-directory 
relative to the workplace root.

When called with any arguments it returns a L<Badger::Filesystem::Directory> 
object for the workplace root directory.

=head2 file($name)

Returns a L<Badger::Filesystem::File> object for a named files
relative to the workplace root.

=head2 uri($path)

When called without any arguments this method returns the base URI for the 
workspace.

    print $workspace->uri;              # e.g. foo

When called with a relative URI path as an argument, it returns the URI
resolved relative to the project base URI. 

    print $workspace->uri('bar');       # e.g. foo/bar

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
