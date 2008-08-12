#========================================================================
#
# Badger::Filesystem::Directory
#
# DESCRIPTION
#   OO representation of a file in a filesystem.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Filesystem::Directory;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Filesystem::Path',
    constants   => 'ARRAY',
    constant    => {
        is_directory => 1,
        type         => 'Directory',
    };

use Badger::Filesystem::Path ':fields';

*dir    = \&directory;
*dirs   = \&directories;
*is_dir = \&is_directory;

sub init {
    my ($self, $config) = @_;
    my ($path, $name, $vol, $dir, @dirs);
    my $fs = $self->filesystem;

    $self->debug("init(", $self->dump_data_inline($config), ")\n") if $DEBUG;
    
    if ($path = $config->{ path }) {
        $path = $self->{ path } = $fs->join_directory($path);
        @$self{@VDN_FIELDS} = $fs->split_path($path);
        $self->debug("path: $self->{ path }  vol: $self->{ volume }  dir: $self->{ directory }  name: $self->{ name }\n") if $DEBUG;
    }
    elsif ($self->{ name } = $config->{ name }) {
        @$self{@VD_FIELDS} = ($vol, $dir) = map { defined($_) ? $_ : '' } @$config{@VD_FIELDS};
        $self->{ path } = $fs->join_path($vol, $dir, $self->{ name });
        $self->debug("name: $self->{ name }  vol: $self->{ volume }  dir: $self->{ directory }  name: $self->{ name }  path: $self->{ path }\n") if $DEBUG;
    }
    else {
        $self->error_msg( missing => 'path or name' );
    }
    return $self;
}

sub base {
    $_[0];
}

sub directory {
    my $self = shift;
    return @_
        ? $self->filesystem->directory( $self->relative(@_) )
        : $self->{ directory };
}

sub file {
    my $self = shift;
    return @_
        ? $self->filesystem->file( $self->relative(@_) )
        : $self->error( missing => 'file name' );
}

sub exists {
    my $self = shift;
    $self->filesystem->directory_exists($self->{ path });
}

sub create { 
    my $self = shift;
    $self->filesystem->create_directory($self->{ path }, @_);
}

sub delete { 
    my $self = shift;
    $self->filesystem->delete_directory($self->{ path }, @_);
}

sub open { 
    my $self = shift;
    $self->filesystem->open_directory($self->{ path }, @_);
}

sub read {
    my $self = shift->must_exist;
    $self->filesystem->read_directory($self->{ path }, @_);
}

sub children {
    my $self = shift;
    $self->debug("asking for $self->{ path } children\n") if $DEBUG;
    return $self->filesystem->directory_children($self->{ path }, @_);
}

sub files {
    my $self  = shift;
    my @files = grep { $_->is_file } $self->children;
    return wantarray ? @files : \@files;
}

sub directories {
    my $self = shift;
    my @dirs = grep { $_->is_dir } $self->children;
    return wantarray ? @dirs : \@dirs;
}

sub visit {
    my $self    = shift;
    my $visitor = $self->filesystem->visitor(@_);
    # directory doesn't visit self, but instead visits all children
    $visitor->visit_directory_children($self);
    return $visitor;
}

sub accept {
    $_[1]->visit_directory($_[0]);
}

1;


=head1 NAME

Badger::Filesystem::Directory - directory object

=head1 SYNOPSIS

    # using either of Badger::Filesytem constructor subroutines
    use Badger::Filesystem 'Dir Directory';
    
    # use native OS-specific paths:
    $dir = Dir('/path/to/dir');
    
    # or generic OS-independent paths
    $dir = Dir('path', 'to', 'dir');

    # Dir is short for Directory if you prefer longness
    $dir = Directory('/path/to/dir');
    $dir = Directory('path', 'to', 'dir');

    # manual object construction
    use Badger::Filesystem::Directory;
    
    # positional arguments
    $dir = Badger::Filesystem::Directory->new('/path/to/file');
    $dir = Badger::Filesystem::Directory->new(['path', 'to', 'file']);
    
    # named parameters
    $dir = Badger::Filesystem::Directory->new(
        path => '/path/to/dir'              # native
    );
    $dir = Badger::Filesystem::Directory->new(
        path => ['path', 'to', 'dir']       # portable
    );
    
    # path inspection methods
    $dir->path;                     # full path
    $dir->directory;                # same as path()
    $dir->dir;                      # alias to directory()
    $dir->base;                     # same as path()
    $dir->volume;                   # path volume (e.g. C:)
    $dir->is_absolute;              # path is absolute
    $dir->is_relative;              # path is relative
    $dir->exists;                   # returns true/false
    $dir->must_exist;               # throws error if not
    @stats = $dir->stat;            # returns list
    $stats = $dir->stat;            # returns list ref

    # path translation methods
    $dir->relative;                 # relative to cwd
    $dir->relative($base);          # relative to $base
    $dir->absolute;                 # relative to filesystem root
    $dir->definitive;               # physical file location
    $dir->collapse;                 # resolve '.' and '..' in $file path
    
    # path comparison methods
    $dir->above($another_path);     # $dir is ancestor of $another_path
    $dir->below($another_path);     # $dir is descendant of $another_path
    
    # directory manipulation methods
    $dir->create;                   # create directory
    $dir->delete;                   # delete directory
    $fh = $dir->open;               # open directory to read
    
    # all-in-one read/write methods
    @data  = $dir->read;             # return directory index
    @kids  = $dir->children;         # objects for each file/subdir
    @files = $dir->files;            # objects for each file in dir
    @dirs  = $dir->dirs;             # objects for each sub-dir in dir
    @dirs  = $dir->directories;      # same as dirs()

=head1 DESCRIPTION

The C<Badger::Filesystem::Directory> module is a subclass of
L<Badger::Filesystem::Path> for representing directories in a file system.

You can create a file object using the C<Dir> constructor function in
L<Badger::Filesystem>.  This is also available as C<Directory> if you 
prefer longer names.

    use Badger::Filesystem 'Dir';

Directory paths can be specified as a single string using your native
filesystem format or as a list or reference to a list of items in the path for
platform-independent paths.

    my $dir = Dir('/path/to/dir');

If you're concerned about portability to other operating systems and/or file
systems, then you can specify the directory path as a list or reference to a list
of component names.

    my $dir = File('path', 'to', 'dir');
    my $dir = File(['path', 'to', 'dir']);

=head1 METHODS

In addition to the methods inherited from L<Badger::Filesystem::Path>, the
following methods are defined or re-defined.

=head2 init(\%config)

Customised initialisation method specific to directories.

=head2 exists

Returns true if the directory exists in the filesystem.  Returns false if the 
directory does not exists or if it is not a directory (e.g. a file).

=head2 is_directory() / is_dir()

This method returns true for all C<Badger::Filesystem::Directory> instances.

=head2 volume() / vol()

Returns any volume defined as part of the path.  This is most commonly used
on MS Windows platforms to indicate drive letters, e.g. C<C:>.

=head2 base()

This always returns C<$self> for directories.

=head2 directory() / dir()

Returns the complete directory path when called without arguments. This is
effectively the same thing as C<path()> or C<base()> returns, given that this
object I<is> a directory. 

This can also be used with an argument to locate another directory relative 
to this one.

    my $dir = Dir('/path/to/dir');
    print $dir->dir;                   # /path/to/dir
    print $dir->dir('subdir');         # /path/to/dir/subdir

=head2 file($name)

This method can be used to locate a file relative to the directory.  The
file is returned as a L<Badger::Filesystem::File> object.

=head2 create()

This method can be used to create the directory if it doesn't already exist.

=head2 delete()

This method deletes the directory permanently.  Use it wisely.

=head2 open()

This method opens the directory and returns an L<IO::Dir> handle to it.

    $fh = $dir->open;
    while (defined($item = $fh->read)) {
        print $item, "\n";
    }

=head2 read($all)

This method read the contents of the directory.  It returns a list (in list
context) or a reference to a list (in scalar context) containing the names
of the entries in the directory.

    my @entries = $dir->read;           # list in list context
    my $entries = $dir->read;           # list ref in scalar context

By default, the C<.> and C<..> directories (or the equivalents for your file
system) are ignored.  Pass a true value for the C<$all> flag if you want
them included.

=head2 children($all)

Returns the entries of a directory as L<Badger::Filesystem::File> or 
L<Badger::Filesystem::Directory> objects.  Returns a list (in list context)
or a reference to a list (in scalar context).

    my @kids = $dir->children;          # list in list context
    my $kids = $dir->children;          # list ref in scalar context

=head2 files()

Returns a list (in list context) or a reference to a list (in scalar context)
of all the files in a directory as L<Badger::Filesystem::File> objects.

    my @files = $dir->files;            # list in list context
    my $files = $dir->files;            # list ref in scalar context

=head2 directories() / dirs()

Returns a list (in list context) or a reference to a list (in scalar context)
of all the sub-directories in a directory as L<Badger::Filesystem::Directory>
objects.

    my @dirs = $dir->dirs;              # list in list context
    my $dirs = $dir->dirs;              # list ref in scalar context

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2005-2008 Andy Wardley. All rights reserved.

=head1 ACKNOWLEDGEMENTS

The C<Badger::Filesystem> modules are built around a number of existing
Perl modules, including L<File::Spec>, L<File::Path>, L<Cwd>, L<IO::File>,
L<IO::Dir> and draw heavily on ideas in L<Path::Class>.

Please see the L<ACKNOWLEDGEMENTS|Badger::Filesystem/ACKNOWLEDGEMENTS>
in L<Badger::Fileystem> for further information.

=head1 SEE ALSO

L<Badger::Filesystem>, 
L<Badger::Filesystem::Path>,
L<Badger::Filesystem::File>.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
# TextMate: doesn't need this cruft
