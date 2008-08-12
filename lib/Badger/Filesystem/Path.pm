#========================================================================
#
# Badger::Filesystem::Path
#
# DESCRIPTION
#   OO representation of a path in a filesystem, serving as a base class
#   for file and directories.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Filesystem::Path;

use File::Spec;
use Badger::Class
    version      => 0.01,
    debug        => 0,
    base         => 'Badger::Base Badger::Exporter',
    import       => 'class',
    constants    => 'HASH ARRAY TRUE',
    get_methods  => 'path name volume directory',
    utils        => 'blessed',
    constant     => {
        is_file      => 0,
        is_directory => 0,
        type         => 'Path',
    },
    exports      => {
        tags     => { fields => '@VDN_FIELDS @VD_FIELDS @STAT_FIELDS' },
    },
    messages     => {
        no_exist => '%s does not exist: %s',
        bad_stat => '%s cannot be scanned: %s',
        bad_look => 'No path specified to look %s',
        missing  => 'No %s specified',
    };

use overload
    '""'     => \&path,
    bool     => \&TRUE,
    fallback => 1;

use Badger::Filesystem;
use Badger::Filesystem::Directory;

our $FILESYSTEM  = 'Badger::Filesystem';
our @VDN_FIELDS  = qw( volume directory name );
our @VD_FIELDS   = qw( volume directory );
our @STAT_FIELDS = qw( device inode mode links user group device_type 
                       size accessed modified created block_size blocks 
                       readable writeable executable owner );

# generate methods to access stat fields
my $n = 0;
class->methods(
    map { 
        my $m = $n++;       # new lexical variable to bind in closure
        $_ => sub { $_[0]->stats->[$m] }
    } @STAT_FIELDS
);

# define some aliases
*is_dir = \&is_directory;
*dir    = \&directory;
*vol    = \&volume;     # goes up to 11
*up     = \&parent;


sub new {
    my $class = shift; $class = ref $class || $class;
    my $args;
    
    if (@_ == 1) {
        $args = ref $_[0] eq HASH ? shift
              : ref $_[0] eq ARRAY || ! ref $_[0] ? { path => shift }
              : return $class->error_msg( unexpected => arguments => $_[0] => 'hash ref' )
    }
    else {
        $args = { @_ };
    }
    
    # allow short aliases for various configuration options, including
    # those of directory/file subclasses to make life easy for them.
    $args->{ filesystem } ||= $args->{ fs  } if $args->{ fs  };
    $args->{ directory  } ||= $args->{ dir } if $args->{ dir };
    $args->{ volume     } ||= $args->{ vol } if $args->{ vol };
    my $self = bless { }, $class;
    
    # maintain a reference to the filesystem that created us, if available,
    # but don't bother if we didn't get one - we can use the default
    $self->{ filesystem } = $args->{ filesystem } if $args->{ filesystem };
    $self->init($args);
}

sub init {
    my ($self, $config) = @_;
    my $path = $config->{ path } || return $self->error_msg( missing => 'path' );
    my $fs   = $self->filesystem;
    $path = $self->{ path } = $fs->join_directory($path);
    return $self;
}

sub is_absolute {
    my $self = shift;
    $self->{ absolute } = $self->filesystem->is_absolute($self->{ path })
        unless defined $self->{ absolute };
    return $self->{ absolute };
}

sub is_relative {
    shift->is_absolute ? 0 : 1;
}

sub absolute {
    my $self = shift;
    return $self->is_absolute
         ? $self
         : $self->filesystem->absolute($self->{ path });
}

sub relative {
    my $self = shift;
    my $fs   = $self->filesystem;
    my $path = $fs->join_directory(@_);
    # If the path isn't already absolute then we merge it onto our 
    # directory or path if directory is undefined.  By calling the 
    # base() method, we allow the file subclass to return its
    # parent directory so that things Just Work[tm]
#    $self->debug("relative path: $path   is_absolute?\n");
    return $fs->is_absolute($path)
         ? $path
         : $fs->collapse_directory( $fs->join_directory($self->base, $path) );
}

sub definitive {
    my $self = shift;
    $self->filesystem->definitive($self->{ path });
}

sub collapse {
    my $self = shift->absolute;
    my $fs   = $self->filesystem;
    $self->{ directory } = $fs->collapse_directory($self->{ directory });
    $self->{ path      } = $fs->join_path(@$self{@VDN_FIELDS});
    return $self;
}

sub above {
    my $self = shift;
    my $this = quotemeta $self->collapse->path;
    my $that = shift || return $self->error_msg( bad_look => 'above' );
    $that = $self->new("$that") unless blessed $that && $that->isa(__PACKAGE__);
    $that = $that->collapse->path;
    $self->debug("does $that match /^$this/ ??\n") if $DEBUG;
    $that =~ /^$this/;
}

sub below {
    my $self = shift;
    my $that = shift || return $self->error_msg( bad_look => 'above' );
    $that = $self->new("$that") unless blessed $that && $that->isa(__PACKAGE__);
    $that->above($self);
}

sub base {
    my $self = shift;
    return $self->{ directory } || $self->{ path };
}

sub parent {
    my $self   = shift;
    my $skip   = shift || 0;
    my $parent = $self->{ parent } 
             ||= $self->filesystem->directory( 
                 $self->{ directory } ||= $self->path_up
             );

    return 
        # don't return parents above the root
        $self->{ path } eq $parent->{ path } ? $self
        # delegate to parent if there are generations to skip
      : $skip ? $parent->parent($skip - 1)
        # otherwise we've found the parent we're looking for
      : $parent;
}

sub path_up {
    my $self = shift;
    my $fs   = $self->filesystem;
    my $path = $fs->split_directory($self->{ path });

    $self->debug("split path [$path] into [", join(', ', @$path), "]\n")
        if $DEBUG;

    if (@$path > 1) {
        # multiple items in path can be relative or absolute - we're not 
        # fussed.  e.g. /foo/bar ==> /foo  or  foo/bar ==> foo
        pop(@$path);
    }
    elsif (@$path == 1) {
        # if there's a single item in a path then it's either a single
        # relative path item (e.g. 'foo' ==> ['foo']), in which case we 
        # return the current working directory, or it's an empty item 
        # indicating the root directory (e.g. '/' => ['']) in which case we
        # do nothing, because you can't go up from the root directory.
        if (length $path->[0]) {
            return $fs->cwd;
        }
        $self->not_implemented("going up from relative paths");
    }
    else {
        $self->error("Invalid path (no elements)\n");
    }
    
    return $fs->join_directory($path);
}

sub exists {
    my $self = shift;
    $self->filesystem->path_exists($self->{ path });
}

sub must_exist {
    my $self = shift;
    return $self->exists
        ? $self
        : $self->error_msg( no_exist => $self->type, $self->{ path } );
}

sub stat {
    my $self  = shift->must_exist;
    my @stats = (CORE::stat($self->{ path }), -r _, -w _, -x _, -o _);
    return $self->error_msg( bad_stat => $self->type, $self->{ path } )
        unless @stats;
    $self->{ stats } = \@stats;
    return wantarray 
        ?  @stats
        : \@stats;
}

sub stats {
    my $stats = $_[0]->{ stats } || $_[0]->stat;
    return wantarray 
        ? @$stats
        :  $stats;
}

sub filesystem {
    my $self = shift;
    return $self->class->any_var('FILESYSTEM')->prototype
        unless ref $self;
    $self->{ filesystem } 
        ||= $self->class->any_var('FILESYSTEM')->prototype;
}



1;

=head1 NAME

Badger::Filesystem::Path - generic fileystem path object

=head1 SYNOPSIS

    # using Badger::Filesytem constructor subroutine
    use Badger::Filesystem 'Path';
    
    # use native OS-specific paths:
    $path = Path('/path/to/something');
    
    # or generic OS-independant paths
    $path = File('path', 'to', 'something');

    # manual object construction
    use Badger::Filesystem::Path;
    
    # positional arguments
    $path = Badger::Filesystem::Path->new('/path/to/something');
    $path = Badger::Filesystem::Path->new(['path', 'to', 'something']);
    
    # named parameters
    $path = Badger::Filesystem::Path->new(
        path => '/path/to/something'
    );
    $path = Badger::Filesystem::Path->new(
        path => ['path', 'to', 'something']
    );
    
    # path inspection methods
    $path->path;                    # current path
    $path->base;                    # parent directory or path itself
    $path->parent;                  # directory object for base
    $path->is_absolute;             # path is absolute
    $path->is_relative;             # path is relative
    $path->exists;                  # returns true/false
    $path->must_exist;              # throws error if not
    @stats = $path->stat;           # returns list
    $stats = $path->stat;           # returns list ref

    # path translation methods
    $path->relative;                # relative to cwd
    $path->relative($base);         # relative to $base
    $path->absolute;                # relative to filesystem root
    $path->definitive;              # physical file location
    $path->collapse;                # resolve '.' and '..' in $path
    
    # path comparison methods
    $path->above($another_path);    # $path is ancestor of $another_path
    $path->below($another_path);    # $path is descendant of $another_path

=head1 INTRODUCTION

This is the documentation for the C<Badger::Filesystem::Path> module. 
It defines a base class object for the L<Badger::Filesystem::File> and
L<Badger::Filesystem::Directory> objects which inherit (and in some cases
redefine) the methods described below.

In other words, you should read this documentation first if you're working
with L<Badger::Filesystem::File> or L<Badger::Filesystem::Directory> objects.

=head1 DESCRIPTION

The C<Badger::Filesystem::Path> module defines a base class object for
representing paths in a real or virtual file system. 

You can create a generic path object (e.g. to represent a path that doesn't
relate to a specific file or directory in a file system), using the C<Path>
constructor method in L<Badger::Filesystem>.

    use Badger::Filesystem 'Path';
    
    my $path = Path('/path/to/something');

However in most cases you'll want to create a file or directory subclass
object. The easiest way to do that is like this:

    use Badger::Filesystem 'File Path';
    
    my $file = File('/path/to/file');
    my $dir  = Dir('/path/to/dir');

If you're concerned about portability to other operating systems and/or
file systems, then you can specify paths as a list or reference to a list 
of component names.

    my $file = File('path', 'to', 'file');
    my $dir  = Dir(['path', 'to', 'dir']);

=head1 METHODS

=head2 new($path)

Constructor method to create a new C<Badger::Filesystem::Path> object.
The path can be specified as a single positional argument, either as a
text string or reference to list of path components.

    # single text string
    $path = Badger::Filesystem::Path->new('/path/to/something');
    
    # reference to list
    $path = Badger::Filesystem::Path->new(['path', 'to', 'something']);

It can also be specified as a C<path> named parameter.

    # named parameter list
    $path = Badger::Filesystem::Path->new(
        path => '/path/to/something'
    );

    # reference to hash of named parameter(s)
    $path = Badger::Filesystem::Path->new({
        path => '/path/to/something'
    });

The constructor method also recognises the C<filesystem> named parameter which
can contain a reference to the L<Badger::Filesystem> object or class that
created it. In most cases you can rely on the L<Badger::Filesystem> to create
path objects for you, using either the L<path()|Badger::Filesystem/path()>
method, or the L<Path()|Badger::Filesystem/Path()> subroutine.

    use Badger::Filesystem 'FS Path';
    
    # FS is alias for 'Badger::Filesystem'
    # Path() is constructor subrooutine
    my $path;
    
    # using the path() method
    $path = FS->path('/path/to/something');
    $path = FS->path('path', 'to', 'something');
    $path = FS->path(['path', 'to', 'something']);
    
    # using the Path() subroutine
    $path = Path('/path/to/something');
    $path = Path('path', 'to', 'something');
    $path = Path(['path', 'to', 'something']);

The examples that follow will use the C<Path()> constructor subroutine.

=head2 init(\%config)

Default initialisation method which subclasses (e.g.
L<Badger::Filesystem::Directory> and L<Badger::Filesystem::File>) can 
redefine.

=head2 is_absolute()

Returns true if the path is absolute, false if not.

=head2 is_relative()

Returns true if the path is relative, false if not.

=head2 absolute($base)

Returns an absolute representation of the path, relative to the C<$base>
path passed as an argument, or the current working directory if C<$base>
is not specified.

    # assume cwd is /foo/bar, 
    my $path = Path('/baz/bam');
    
    print $path->absolute;                  # /foo/bar/baz/bam
    print $path->absolute('/wiz');          # /wiz/baz/bam

=head2 relative($base)

Returns a relative representation of the path, relative to the C<$base>
path passed as an argument, or the current working directory if C<$base>
is not specified.

    # assume cwd is /foo/bar, 
    my $path = Path('/foo/bar/baz/bam');
    
    print $path->relative;                  # /baz/bam
    print $path->relative('/foo');          # /bar/baz/bam

=head2 definitive()

Returns the definitive representation of the path which in most cases will
be the same as the L<absolute()> path.

However, if you're using a L<Badger::Filesystem> with a virtual root 
directory, then the I<definitive> path I<will> include the virtual root 
directory, whereas a the I<absolute> path will I<not>.

    my $fs = Badger::Filesystem->new( root => '/my/vfs' );
    $fs->absolute('/foo/bar');              # /foo/bar
    $fs->definitive('/foo/bar');            # /my/vfs/foo/bar

=head2 collapse

Reduces the path to its simplest form by resolving and removing any C<.>
(current directory) and C<..> (parent directory) components (or whatever the
corresponding tokens are for the current and parent directories of your
filesystem). 

    my $path = Path('/foo/bar/../baz')->collapse;
    print $path;   # /foo/baz

See the L<collapse_dir()|Badger::Filesystem/collapse()> method in 
L<Badger::Filesystem> for further information.

=head2 above($child)

Returns true if the path is "above" the C<$child> path passed as an argument.
Formally, we say that the path is an I<ancestor> of C<$child> meaning that it
is the parent directory, or grand-parent, or great-grand-parent, and so on.

    my $parent = Path('/foo/bar');
    my $child  = Path('/foo/bar/baz');
    $parent->above($child);                 # true

This is implemented as a simple prefix match. That is, the parent path must
appear at the start of the child path. Consequently, this method will not
account for symbolic links or other similar filesystem features, and it may
not work properly on systems that don't follow this convention (although there
are none that I'm aware of).

=head2 below($parent)

Returns true if the path is "below" the C<$parent> path passed as an argument.
Formally, we say that the path is a I<descendant> of C<$parent> meaning that it
is an immediate sub-directory, or sub-sub-directory, and so on.

    my $parent = Path('/foo/bar');
    my $child  = Path('/foo/bar/baz');
    $child->below($parent);                 # true

Like L<above()>, this is implemented using a simple prefix match.

=head2 base()

Returns the base directory of a path. For L<Badger::Filesystem::Path> and
L<Badger::Filesystem::Directory> objects, this method will return the complete
path.

    print Path('/foo/bar')->base;           # /foo/bar
    print Directory('/foo/bar')->base;      # /foo/bar

However the L<Badger::Filesystem::File> module returns the parent directory in
which the file is located.

    print File('/foo/bar')->base;           # /foo

=head2 parent($skip_generations)

Returns a L<Badger::Filesystem::Directory> object representing the parent
directory for a path.

    Path->('/foo/bar')->parent;             # path object for /foo

A numerical argument can be provided to indicate the number of generation
you want to skip.  A value of C<0> is the same as providing no argument - it
returns the parent.  A value of C<1> skips the parent and returns the 
grand-parent, and so on. 

    Path->('/foo/bar/baz/bam')->parent(2);  # path object for /foo

The root directory will be returned if you try to skip too many generations.

    Path->('/foo/bar/baz/bam')->parent(20); # path object for /

=head2 exists

Returns true if the path exists in the filesystem (e.g. as a file, directory,
or some other entry), or false if not.

    if ($path->exists) {
        print "$path already exists\n";
    }
    else {
        print "Creating $path\n";
        # ...etc...
    }

TODO: File and Directory subclasses should redefine this to also check
that it is of the right type.  e.g. a file should tests -f, a dir -d.
What to do if path exists but is of wrong type?  Throwing an error seems
too aggressive, but returning false too passive.

=head2 must_exist

Checks that the path exists (by calling L<exists()>) and throws an error
if it doesn't.

    $path->must_exist;                      # no need to check return value

=head2 stat

Performs a filesystem C<stat> on the path and returns a list (in list
context), or a reference to a list (in scalar context) containing the 13 
information elements.  See C<perldoc -f stat> for further details on what
they are.

    @list = $path->stat;                    # list context
    $list = $path->stat;                    # scalar context

=head2 stats

A wrapper around the L<stat()> method which caches the results to avoid 
making repeated filesystem calls.

    @list = $path->stats;                   # list context
    $list = $path->stats;                   # scalar context

=head2 filesystem

Returns a reference to a L<Badger::Filesystem> object, or the name of the
filesystem class (e.g. L<Badger::Filesystem> or a subclass) that created
the path object.  If this is undefined then the default value defined in 
the L<$FILESYSTEM> class variable is returned.   Unless you've changed it,
or re-defined it in a subclass, this value will be C<Badger::Filesystem>.

The end result is that you can use the C<filesystem> method to access a 
L<Badger::Filesystem> object or class through which you can perform other
filesystem related operations.  This is used internally by a number of 
method.

    # access filesystem via existing path
    $path->filesystem->dir('/a/new/directory/object');
    
    # same as
    Badger::Filesystem->dir('/a/new/directory/object');

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

L<Badger::Filesystem>, L<Badger::Filesystem::Directory>,
L<Badger::Filesystem::File>

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
# TextMate: should support split pane editing

