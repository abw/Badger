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

use Badger::Debug ':dump';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Filesystem',
    accessors => 'root',
    constants => 'ARRAY CODE',
    constant  => {
        VFS          => __PACKAGE__,
        virtual      => __PACKAGE__,
        PATH_METHOD  => 'path',
        PATHS_METHOD => 'paths',
        ROOTS_METHOD => 'roots',
    },
    exports   => {
        any   => 'VFS',
    },
    messages => {
        bad_root  => 'Invalid root directory: %s', 
        max_roots => 'The number of virtual filesystem roots exceeds the max_roots limit of %s',
    };

*definitive = \&definitive_write;

our $MAX_ROOTS = 32 unless defined $MAX_ROOTS;

sub init {
    my ($self, $config) = @_;

    # let the base class have a go first, so it can set rootdir et al
    $self->SUPER::init($config);

    # root can be a single item or list ref
    my $root = $config->{ root } || $self->{ rootdir };
    $root = [$root] unless ref $root eq ARRAY;
    $self->{ root } = $root;

    # the dynamic flag indicates that the list of roots can change so we must 
    # recompute them each time we use them.  max_roots sets a limit on the 
    # expansion to prevent runaways
    $self->{ dynamic   } = $config->{ dynamic };
    $self->{ max_roots } = 
        defined $config->{ max_roots } 
              ? $config->{ max_roots }
              : $MAX_ROOTS;
    
    # we must set cwd to / so that the relative -> absolute path translation
    # works as expected.  The concept of having a current working directory 
    # in a VFS is just a bit too weird to contemplate anyway.
    $self->{ cwd } = $self->{ rootdir };
    
    $self->debug("Virtual root: ", join(', ', @$root), "\n" ) if $DEBUG;
    
    return $self;
}

sub roots {
    my $self = shift;

    if (my $roots = $self->{ roots }) {
        return wantarray
            ? @$roots
            :  $roots;
    }

    my $max    = $self->{ max_roots };
    my @paths  = @{ $self->{ root } };
    my (@roots, $type, $paths, $dir, $code);

    # If a positive max_roots is defined then we'll limit the number of 
    # roots we resolve.  If it's zero or negative then it will pre-decrement
    # before being tested so will always be true
    while (@paths && --$max) {
        $dir = shift @paths || next;

        $type = ref $dir || do {
            # non-reference paths get added as they are
            $self->debug("discovered root directory: $dir\n") if DEBUG;
            push(@roots, $dir);
            next;
        };

        # anything else can expand out to one or more paths, each of which
        # can expand recursively, so we push all new paths back onto the
        # candidate list and test each in turn.
        
        if ($type eq CODE) {
            # call code ref
            $paths = $dir->();
            $self->debug(
                "discovered root directories from code ref: ",
                $self->dump_data_inline($paths), "\n"
            ) if DEBUG;
            unshift(@paths, ref $paths eq ARRAY ? @$paths : $paths);
            next;
        }
        elsif ($type eq ARRAY) {
            # expand list ref
            $self->debug(
                "discovered root directories from code ref: ",
                join(', ', @$dir), "\n"
            ) if DEBUG;
            unshift(@paths, @$dir);
            next;
        }
        elsif (blessed $dir) {
            # see if object has a path(), paths() or roots() method
            # TODO: this is broken - we don't want to recompute paths 
            # each time just because we're using an object that has a 
            # path
            if ($code = $dir->can(PATH_METHOD)
                     || $dir->can(PATHS_METHOD)
                     || $dir->can(ROOTS_METHOD) ) {
                $paths = $code->($dir);
                $self->debug(
                    "discovered root directories from $type object: $paths / ", 
                    $self->dump_data_inline($paths), "\n"
                ) if DEBUG;
                unshift(@paths, ref $paths eq ARRAY ? @$paths : $paths);
                next;
            }
        }

        $self->error( bad_root => $dir );
    }

    # anything left in @paths means we must have blown the max_roots limit
    return $self->error_msg( max_roots => $self->{ max_roots } )
        if @paths;

    # we can cache roots if all are static and the dynamic flag isn't set
    $self->{ roots } = \@roots
        unless $self->{ dynamic };
    
    $self->debug("resolved roots: [\n  ", join("\n  ", @roots), "\n]\n") if DEBUG;
    
    return wantarray
        ?  @roots
        : \@roots;
}

sub definitive_paths {
    my $self  = shift;
    my $path  = $self->absolute(@_);
    my @paths = map { $self->merge_paths($_, $path) } $self->roots;
    return wantarray
        ?  @paths
        : \@paths;
}

sub definitive_write {
    my $self = shift;
    $self->debug("definitive_write(", join(', ', @_), ")\n") if DEBUG;
    my $path = $self->absolute(@_);
    return $self->join_directory($self->roots->[0], $path);
}

sub definitive_read {
    my $self = shift;
    my $path = $self->absolute(@_);
    my ($base, $full);

    foreach $base ($self->roots) {
        $full = $self->merge_paths($base, $path);
        $self->debug("looking for [$base] + [$path] => $full\n") if DEBUG;
        return $full if -e $full;
    }
    return undef;
}

sub read_directory {
    my $self = shift;
    my $path = $self->absolute(shift);
    my $all  = shift;
    my ($base, $full, $dirh, $item, @items, %seen);

    require IO::Dir;

    foreach $base ($self->roots) {
        $full = $self->join_directory($base, $path);
        $self->debug("Opening directory: $full\n") if DEBUG;
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

=head2 Dynamic Root Directories

TODO: we now support code refs and objects as root directories which are
evaluated dynamically to generate a list of root directories.  An object
should have a C<path()>, C<paths()> or C<roots()> method which returns a 
single path or refererence to a list of path.  Any of those can be further
dynamic components which will be evaluated recursively until all have been
resolved or the C<max_roots> limit has been reached.

=head1 METHODS

L<Badger::Filesystem::Virtual> inherits all the methods of
L<Badger::Filesystem>.  The following methods are added or amended.

=head2 init(\%config)

This custom initialisation method allows one or more C<root> (or C<rootdir>)
directories to be specified as the base of the virtual filesystem.

=head2 roots()

This method returns a list (in list context) or reference to a list (in
scalar context) of the root directories for the virtual filesystem.  Any
dynamic components in the roots will be evaluated and expanded.  This
include subroutine references and objects implementing a C<path()>, 
C<paths()> or C<roots()> method.  Dynamic components can return a single
items or reference to a list of items, any of which can be a static directory
or dynamic component.

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

=head2 definitive_paths($path)

Returns a list (in list context) or reference to a list (in scalar context) of
all the definitive paths that the file path could be mapped to. This is
generating by adding the C<$path> argument onto each of the L<root>
directories.

=head2 read_directory($path)

Custom method to read a directory in a virtual filesystem.  This returns
a composite index of all entries in a particular directory across all 
roots of the virtual filesystem.

=head1 OPTIONS

=head2 root

The root directory or directories of the virtual filesystem.  

=head2 max_roots

A limit to the maximum number of root directories allowed.  This is used 
to prevent potential runaways when evaluating dynamic root components.
See L<Dynamic Root Directories> for further information.

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
