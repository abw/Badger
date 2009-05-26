#========================================================================
#
# Badger::Filesystem::Base
#
# DESCRIPTION
#   Base class for Badger::Filesystem modules implementing some common
#   functionality.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Filesystem::Base;

use Badger::Class
    version     => 0.01,
    base        => 'Badger::Base',
    debug       => 0,
    import      => 'class',
    messages    => {
        no_option_method => 'No method defined to handle %s option',
    };

our @VDN_FIELDS = qw( volume directory name );
our @VD_FIELDS  = qw( volume directory );
our @OPTIONS    = qw( encoding codec );


sub init_path {
    my ($self, $config) = @_;
    my ($path, $vol, $dir, $name);
    my $fs = $self->filesystem;

    if ($config->{ path }) {
        # split path into volume, directory, name
        # set colume, 
        $path = $self->{ path } = $fs->join_dir( $config->{ path } );
        @$self{@VDN_FIELDS} = $fs->split_path($path);
    }
    elsif ($self->{ name } = $config->{ name }) {
        @$self{@VD_FIELDS} = ($vol, $dir) = map { defined($_) ? $_ : '' } @$config{ @VD_FIELDS };
        $self->{ path } = $fs->join_path($vol, $dir, $self->{ name });
    }
    else {
        $self->error_msg( missing => 'path or name' );
    }

    return $self;
}

sub init_options {
    my ($self, $config) = @_;
    my $opts  = $self->{ options } = { };
    my $method;

    foreach my $name (@OPTIONS) {
        if ($config->{ $name }) {
            $method = $self->can($name)
                || return $self->error_msg( no_option_method => $name );
            $method->( $self, $config->{ $name } );
        }
    }

    return $self;
}

sub codec {
    my $self = shift;
    if (@_) {
        require Badger::Codecs;
        $self->{ options }->{ codec } = Badger::Codecs->codec(@_);
    }
    return $self->{ options }->{ codec };
}

sub encoding {
    my $self = shift;
    if (@_) {
        my $layer = shift;
        # be generous in what you accept...
        $layer = ":$layer" unless $layer =~ /^:/;
        $self->{ options }->{ encoding } = $layer;
    }
    return $self->{ options }->{ encoding };
}


1;

=head1 NAME

Badger::Filesystem::Base - common functionality for Badger::Filesystem modules

=head1 SYNOPSIS

    package Badger::Filesystem::SomeOtherModule;
    use base 'Badger::Filesystem::Base'
    # now this module inherits the base class functionality

=head1 DESCRIPTION

C<Badger::Filesystem::Base> is a base class module that defines some common
functionality shared by L<Badger::Filesystem> and L<Badger::Filesystem::Path>
(which itself is the base class for L<Badger::Filesystem::Directory> and 
L<Badger::Filesystem::File>.

=head1 METHODS

=head2 init_path(\%config)

Initialisation method which examines the filesystem path specified as a 
parameter and splits it into volume, directory and name.

=head2 init_options(\%config)

Initialisation method which handles the C<encoding> and C<codec> options.

=head2 encoding($enc)

This method can be used to get or set the default encoding for a file.

    $file->encoding(':utf8');

The encoding will affect all operations that read data from, or write data
to the file.

The method can also be used to get or set the default encoding for a 
directory or filesystem.  In this case the option specifies the default 
encoding for file contained therein.

    $directory->encoding(':utf8');
    $file = $directory->file('foo.txt');        # has :utf8 encoding set

=head2 codec()

This method can be used to get or set the codec used to serialise data to
and from a file via the L<data()> method.  The codec should be specified
by name, using any of the names that L<Badger::Codecs> recognises or can 
load.

    $file->codec('storable');
    
    # first save the data to file
    $file->data($some_data_to_save);
    
    # later... load the data back out
    my $data = $file->data;

You can use chained codec specifications if you want to pass the data 
through more than one codec.

    $file->code('storable+base64');

See L<Badger::Codecs> for further information on codecs.

As with L<encoding()>, this method can also be used to get or set the default
codec for a directory or filesystem. 

    $directory->codec('json');
    $file = $directory->file('foo.json');       # has json codec set

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2009 Andy Wardley. All rights reserved.

=head1 SEE ALSO

L<Badger::Filesystem>, 
L<Badger::Filesystem::Path>,
L<Badger::Filesystem::Directory>,
L<Badger::Filesystem::File>.

=cut

