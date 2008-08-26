#========================================================================
#
# Badger::Filesystem::Virtual
#
# DESCRIPTION
#   Subclass of Badger::Filesystem which implements a virtual filesystem
#   composed from several source directories, conceptually layered on
#   top of each other.  
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Filesystem::Virtual;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Filesystem',
    constants => 'ARRAY',
    constant  => {
        VFS     => __PACKAGE__,
        virtual => __PACKAGE__,
    },
    exports   => {
        any   => 'VFS',
    };

*definitive = \&definitive_write;


sub init {
    my ($self, $config) = @_;

    # let the base class have a go first, so it can set rootdir et al
    $self->SUPER::init($config);

    # root can be a single item or list ref
    my $root = $config->{ root } || $self->{ rootdir };
    $root = [$root] unless ref $root eq ARRAY;
    $self->{ root } = $root;
    
    # we must set cwd to / so that the relative -> absolute path translation
    # works as expected.  The concept of having a current working directory 
    # in a VFS is just a bit too weird to contemplate anyway.
    $self->{ cwd } = $self->{ rootdir };
    
    $self->debug("Virtual root: ", join(', ', @$root), "\n" ) if $DEBUG;
    
    return $self;
}

sub definitive_write {
    my $self = shift;
    my $path = $self->absolute(@_);
    return $self->join_directory($self->{ root }->[0], $path);
}

sub definitive_read {
    my $self = shift;
    my $path = $self->absolute(@_);
    my ($base, $full);

    foreach $base (@{ $self->{ root } }) {
        $full = $self->merge_paths($base, $path);
        $self->debug("looking for $full\n") if $DEBUG;
        return $full if -e $full;
    }
}

sub read_directory {
    my $self = shift;
    my $path = $self->absolute(shift);
    my $all  = shift;
    my $root = $self->{ root };
    my ($base, $full, $dirh, $item, @items, %seen);

    require IO::Dir;

    foreach $base (@{ $self->{ root } }) {
        $full = $self->join_directory($base, $path);
        $self->debug("Opening directory: $full\n") if $DEBUG;
        $dirh = IO::Dir->new($full)
            || $self->error_msg( open_failed => directory => $full => $! );
        while (defined ($item = $dirh->read)) {
            push(@items, $item) unless $seen{ $item }++;
        }
        $dirh->close;
    }
    @items = $self->FILESPEC->no_upwards(@items)
        unless $all || ref $self && $self->{ all_entries };

    return wantarray ? @items : \@items;
}


1;

__END__

=head1 NAME

Badger::Filesystem::Virtual - virtual filesystem

=head1 SYNOPSIS

    use Badger::Filesystem::Virtual;
    
    my $fs = Badger::Filesystem::Virtual->new(
        root => ['/path/to/dir/one', '/path/to/dir/two'],
    );
    my $file = $fs->file('/example/file');
    my $dir  = $fs->dir('/example/directory');
    
    if ($file->exists) {        # under either root directory
        print $file->text;      # loaded from correct location
    }
    else {                      # writes under first directory
        $file->write("hello world!\n");
    }

=head1 INTRODUCTION

This module defines a subclass of L<Badger::Filesystem> for creating virtual
filesystems that are "mounted" onto one or more underlying source directories
in a real file system (if you're familiar with the Template Toolkit then think
of the INCLUDE_PATH). If that doesn't mean much to you then the chances are
that you don't need to read this documentation. Either way you should read the
documentation for L<Badger::Filesystem> first, closely followed by
L<Badger::Filesystem::Path>, L<Badger::Filesystem::File> and
L<Badger::Filesystem::Directory>.

Done that now?  Good, welcome back.  Let us begin.

=head1 DESCRIPTION

C<Badger::Filesystem::Virtual> module is a specialised subclass of the
L<Badger::Filesystem> module. In contrast to L<Badger::Filesystem> module
which gives you access to the files and directories in a I<real> filesystem,
C<Badger::Filesystem::Virtual> allows you to create a I<virtual> filesystem
I<mounted> under a I<real> directory, or composed from a number of I<real>
directories.

    use Badger::Filesystem::Virtual;

    # virtual file system with single root
    my $vfs1 = Badger::Filesystem::Virtual->new(
        root => '/path/to/virtual/root',
    );

    # virtual file system with multiple roots
    my $vfs2 = Badger::Filesystem::Virtual->new(
        root => [
            '/path/to/virtual/root/one',
            '/path/to/virtual/root/two',
        ],
    );

The module defines the exportable C<VFS> symbol as an alias for
C<Badger::Filesystem::Virtual> to save on typing:

    use Badger::Filesystem::Virtual 'VFS';
    
    my $vfs1 = VFS->new( root => '/path/to/virtual/root' );

You can also access this via the L<Badger::Filesystem> module.

    use Badger::Filesystem 'VFS';

TODO: and eventually the L<Badger> module...

=head2 Single Root Virtual Filesystem

A filesystem object with a single virtual root directory works in a similar
way to the C<chroot> command.

    use Badger::Filesystem::Virtual 'VFS';
    
    my $vfs1 = VFS->new( root => '/my/web/site' );

Any absolute paths specified for this file system are then assumed to be
relative to the virtual root. For example, we can create an object to
represent a file in our virtual file system.

    my $home = $vfs1->file('index.html');

This file as a relative path of C<index.html>.

    print $home->relative;                     # index.html

The absolute path is C</index.html>.

    print $home->absolute;                     # /index.html

However, the real, physical path to the file is relative to the 
virtual root directory.  The L<definitive()> method returns this
path.

    print $home->definitive;                   # /my/web/site/index.html

You can open, read, write and generally perform any kind of operation on a
file or directory in a virtual file system the same way as you would for a
real file system (i.e. one without a virtual C<root> directory defined).
Behind the scenes, the filesystem object handles the mapping of paths in the
virtual file system to their physical counterparts via the L<definitive>
method. 

    my $text = $home->read;                     # read file
    $home->write($text);                        # write file
    $home->append($more_text);                  # append file
    # ...etc...

=head2 Multiple Root Virtual File System

Things get a little more interesting when you have a virtual filesystem
with multiple root directories.

    use Badger::Filesystem::Virtual 'VFS';
    
    my $vfs2 = VFS->new( root => [
        '/my/root/dir/one',
        '/my/root/dir/two'
    ] );

The handling of relative and absolute paths is exactly the same as for a 
single root virtual file system.  

    my $home = $vfs2->file('index.html');
    print $home->relative;                     # index.html
    print $home->absolute;                     # /index.html

You can call any of the regular methods on L<Badger::Filesystem::File> and
L<Badger::Filesystem::Directory> objects as you would for a normal file
system, and leave it up to the C<Badger::Filesystem::Virtual> module to Do The
Right Thing to handle the mapping.

    print $home->text;          # locates file under either root dir
    print $home->size;

If you look at the contents of a directory, you'll see the combined contents
of that directory under any and all virtual roots that contain it.

    my $dir = $vfs2->dir('foo');
    print join "\n", $dir->children;

The L<children()|Badger::Filesystem::Directory/children()> method in this
example will returns all the files and sub-directories in both 
C</my/root/dir/one/foo> and C</my/root/dir/two>.

The L<definitive_read()> and L<definitive_write()> methods are used to map
virtual paths onto their real counterparts whenever you read, write, or
perform any other operation on an underlying file or directory. For read
operations, the L<definitive_read()> method will look for the file or
directory under each of the virtual root directories until it is located or
presumed not found. The L<definitive_write()> method always maps paths to the
first root directory (NOTE: we'll be providing some options to customise this
at some point in the future - be aware for now that the append() method may
not work correctly if you're trying to append to a file that isn't under the
first root directory).

=head1 METHODS

L<Badger::Filesystem::Virtual> inherits all the methods of
L<Badger::Filesystem>.  The following methods are added or amended.

=head2 init(\%config)

This custom initialisation method allows one or more C<root> (or C<rootdir>)
directories to be specified as the base of the virtual filesystem.

=head2 definitive($path)

This is aliased to the L<definitive_write()> method.

=head2 definitive_write($path)

Maps a virtual file path to a definitive one for write operations.  The 
path will be mapped to the first virtual root directory.

=head2 definitive_read($path)

Maps a virtual file path to a definitive one for read operations.  The 
path will be mapped to the first virtual root directory in which the 
item exists.  If it does not exists in any of the virtual root directories
then an undefined value is returned.

=head2 read_directory($path)

Custom method to read a directory in a virtual filesystem.  This returns
a composite index of all entries in a particular directory across all 
roots of the virtual filesystem.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2005-2008 Andy Wardley. All rights reserved.

=head1 SEE ALSO

L<Badger::Filesystem>

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
# TextMate: rocks my world
