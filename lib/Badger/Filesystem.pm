#========================================================================
#
# Badger::Filesystem
#
# DESCRIPTION
#   OO representation of a filesystem.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Filesystem;

use File::Spec;
use Cwd 'getcwd';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Prototype Badger::Exporter',
    import    => 'class',
    constants => 'HASH ARRAY TRUE',
    constant  => {
        NO_FILENAME => 1,
        FILESPEC    => 'File::Spec',
        ROOTDIR     =>  File::Spec->rootdir,
        CURDIR      =>  File::Spec->curdir,
        UPDIR       =>  File::Spec->updir,
        DIRECTORY   => 'Badger::Filesystem::Directory',
        PATH        => 'Badger::Filesystem::Path',
        FILE        => 'Badger::Filesystem::File',
    },
    exports   => {
        tags  => { 
            types   => 'Path File Dir Directory',
            dirs    => 'ROOTDIR UPDIR CURDIR',
        },
    },
    messages  => {
        open_failed   => 'Failed to open %s %s: %s',
        delete_failed => 'Failed to delete %s %s: %s',
    };

use Badger::Filesystem::File;
use Badger::Filesystem::Directory;


#-----------------------------------------------------------------------
# aliases
#-----------------------------------------------------------------------

*DIR          = \&DIRECTORY;              # constant class name
*Dir          = \&Directory;              # constructor sub
*dir          = \&directory;              # object methods
*split_dir    = \&split_directory;
*join_dir     = \&join_directory;
*collapse_dir = \&collapse_directory;
*create_dir   = \&create_directory;
*delete_dir   = \&delete_directory;
*open_dir     = \&open_directory;
*read_dir     = \&read_directory;
*dir_children = \&directory_children;
*mkdir        = \&create_directory;
*rmdir        = \&delete_directory;


#-----------------------------------------------------------------------
# factory subroutines
#-----------------------------------------------------------------------

sub Path      { return @_ ?       PATH->new(@_) : PATH      }
sub File      { return @_ ?       FILE->new(@_) : FILE      }
sub Directory { return @_ ?  DIRECTORY->new(@_) : DIRECTORY }


#-----------------------------------------------------------------------
# generated methods
#-----------------------------------------------------------------------

class->methods(
    # define methods for path/root/updir/curdir that access a prototype 
    # object when called as class methods.
    map {
        my $name = $_;      # fresh copy of lexical for binding in closure
        $name => sub {
            $_[0]->prototype->{ $name };
        }
    }
    qw( root rootdir updir curdir separator virtual )
);


#-----------------------------------------------------------------------
# constructor methods
#-----------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;

    # A virtual root directory can be specified to effectively chroot
    # the filesystem to a sub-directory.  For example, you can create a
    # filesystem with a root directory set to wherever your web pages
    # are (e.g. /path/to/your/web/pages).  Then any "absolute" paths
    # will be resolved relative to that root, e.g. /index.html is an
    # absolute path in a virtual file system with a definitive path of
    # /path/to/your/web/pages/index.html.  If we do have a virtual root
    # then cwd() should always return '/'.  This is so that the absolute()
    # method will resolve a relative path like 'index.html' as '/index.html'
    # rather than whatever the real cwd is.
    if (my $root = $config->{ root }) {
        $root = $self->join_dir(@$root) if ref $root eq ARRAY;
        $self->{ root    } = $root;
        $self->{ cwd     } = $config->{ cwd } || ROOTDIR;
        $self->{ virtual } = 1;
    }
    else {
        $self->{ root    } = ROOTDIR;
        $self->{ cwd     } = $config->{ cwd };  # may be undef
        $self->{ virtual } = 0;
    }
    
    # TODO: have filsystem "styles", e.g. URI/URL style provides defaults
    # for rootdir, updir, curdir, separator.  But this requires us to bypass
    # File::Spec, so we'll leave it for now.  KISS.
    
    # The tokens used to represent the root directory ('/'), the 
    # parent directory ('..') and current directory ('.') default to
    # constants grokked from File::Spec.  To determine the path separator
    # we have to resort to an ugly hack.  The File::Spec module hard-codes 
    # the path separator in the catdir() method so we have to make a round-
    # trip through catdir() to grok the separator in a cross-platform manner
    $self->{ rootdir   } = $config->{ rootdir   } || ROOTDIR;
    $self->{ updir     } = $config->{ updir     } || UPDIR;
    $self->{ curdir    } = $config->{ curdir    } || CURDIR;
    $self->{ separator } = $config->{ separator } || do {
        my $sep = FILESPEC->catdir(('badger') x 2);
        $sep =~ s/badger//g;
        $sep;
    };

    # flag to indicate if directory scans should return all entries
    $self->{ all_entries } = $config->{ all_entries } || 0;
    
    return $self;
}

sub path {
    Path->new( shift->_child_args( path => @_ ) );
}

sub file {
    File->new( shift->_child_args( file => @_ ) );
}

sub directory {
    my $self = shift;
    my $args = $self->_child_args( directory => @_ );
    
    # default directory is the current working directory
    $args->{ path } = $self->cwd
        if exists $args->{ path } && ! defined $args->{ path };
    
    Directory->new($args);
}

sub cwd {
    my $self = shift->prototype;
    # if we have a hard-coded cwd set then return that, otherwise call 
    # getcwd to return the real current working directory.  NOTE: we don't
    # cache the dynamically resolved cwd as it'll change if chdir() is called
    $self->{ cwd } || getcwd;
}


#-----------------------------------------------------------------------
# path manipulation methods
#-----------------------------------------------------------------------

sub join_path {
    my $self = shift;
    my @args = map { defined($_) ? $_ : '' } @_[0..2];
    FILESPEC->canonpath( FILESPEC->catpath(@args) );
}

sub join_directory {
    my $self = shift;
    my $dir  = @_ == 1 ? shift : [ @_ ];
    $self->debug("join_dir($dir)\n") if $DEBUG;
    ref $dir eq ARRAY
        ? FILESPEC->catdir(@$dir)
        : FILESPEC->canonpath($dir);
}

sub split_path {
    my $self  = shift;
    my $path  = $self->join_directory(@_);
    my @split = map { defined($_) ? $_ : '' } FILESPEC->splitpath($path);
    $self->debug("split_path($path) => ", join(', ', @split), "\n") if $DEBUG;
    return wantarray ? @split : \@split;
}

sub split_directory {
    my $self  = shift;
    my $path  = $self->join_directory(@_);
    my @split = FILESPEC->splitdir($path);
    return wantarray ? @split : \@split;
}

sub collapse_directory {
    my $self = shift->prototype;
    my @dirs = $self->split_directory(shift); 
    my ($up, $cur) = @$self{qw( updir curdir )};
    my ($node, @path);
    while (@dirs) {
        $node = shift @dirs;
        if ($node eq $cur) {
            # do nothing
        }
        elsif ($node eq $up) {
            pop @path if @path;
        }
        else {
            push(@path, $node);
        }
    }
    $self->join_directory(@path);
}


#-----------------------------------------------------------------------
# absolute, relative and definitive path tests and transmogrifiers
#-----------------------------------------------------------------------

sub is_absolute {
    my $self = shift;
    FILESPEC->file_name_is_absolute($self->join_directory(@_)) ? 1 : 0;
}

sub is_relative {
    shift->is_absolute(@_) ? 0 : 1;
}

sub definitive {
    my $self = shift;
    my $path = $self->absolute(@_);
    return ref $self && $self->{ virtual }
        ? FILESPEC->catdir($self->{ root }, $path)
        : $path;
}

sub absolute {
    my $self = shift;
    my $path = $self->join_directory(shift);
    return $path if FILESPEC->file_name_is_absolute($path);
    FILESPEC->catdir(shift || $self->cwd, $path);
}

sub relative {
    my $self = shift;
    FILESPEC->abs2rel($self->join_directory(shift), shift || $self->cwd);
}


#-----------------------------------------------------------------------
# file manipulation methods
#-----------------------------------------------------------------------

sub create_file {
    my $self = shift;
    my $path = $self->definitive(shift);
    unless (-e $path) {
        $self->write_file($path);
    }
    return 1;
}

sub touch_file {
    my $self = shift;
    my $path = $self->definitive(shift);
    if (-e $path) {
        my $now = time();
        utime $now, $now, $path;
    } 
    else {
        $self->write_file($path);
    }
}

sub delete_file {
    my $self = shift;
    my $path = $self->definitive(shift);
    unlink($path)
        || return $self->error_msg( delete_failed => file => $path => $! );
}

sub open_file {
    my $self = shift;
    my $path = $self->definitive(shift);
    require IO::File;
    $self->debug("about to open file $path (", join(', ', @_), ")\n") if $DEBUG;
    return IO::File->new($path, @_)
        || $self->error_msg( open_failed => file => $path => $! );
}

sub read_file {
    my $self = shift;
    my $fh   = $self->open_file(shift, 'r');
    return wantarray
        ? <$fh>
        : do { local $/ = undef; <$fh> };
}

sub write_file {
    my $self = shift;
    my $fh   = $self->open_file(shift, 'w');
    return $fh unless @_;           # return handle if no args
    print $fh @_;                   # or print args and close
    $fh->close;
    return 1;
}

sub append_file {
    my $self = shift;
    my $fh   = $self->open_file(shift, 'a');
    return $fh unless @_;           # return handle if no args
    print $fh @_;                   # or print args and close
    $fh->close;
    return 1;
}


#-----------------------------------------------------------------------
# directory manipulation methods
#-----------------------------------------------------------------------

sub create_directory { 
    my $self = shift;
    my $path = $self->definitive(shift);
    require File::Path;
    eval { 
        local $Carp::CarpLevel = 1;
        File::Path::mkpath($path, @_) 
    } || return $self->error($@);
} 
    
sub delete_directory { 
    my $self = shift;
    my $path = $self->definitive(shift);
    require File::Path;
    File::Path::rmtree($path, @_)
}

sub open_directory {
    my $self = shift;
    my $path = $self->definitive(shift);
    $self->debug("Opening directory: $path\n") if $DEBUG;
    require IO::Dir;
    return IO::Dir->new($path, @_)
        || $self->error_msg( open_failed => directory => $path => $! );
}

sub read_directory {
    my $self = shift;
    my $dirh = $self->open_directory(shift);
    my $all  = shift;
    my ($path, @paths);
    while (defined ($path = $dirh->read)) {
        push(@paths, $path);
    }
    @paths = FILESPEC->no_upwards(@paths)
        unless $all || ref $self && $self->{ all_entries };

    $dirh->close;
    return wantarray ? @paths : \@paths;
}

# TODO: this is clumsy.  Can we integrate it with read_directory() like we do
# for read_file(), and/or provide a way of just getting files or dirs, or other
# matches (but we don't want to duplicate File::Find::Rule - can we integrate?)

sub directory_children {
#    local $DEBUG = 1;
    my $self  = shift;
    my $dir   = shift;
    my @paths = $self->read_directory($dir, @_);
    my $base  = $self->{ root } if $self->{ virtual };
    my $path;
    

    @paths = map {
        $path = $self->join_directory($dir, $_);
        $self->debug("$dir + $_ => $path") if $DEBUG;
        
        # if we're using a virtual root then we need to tack that on to
        # the start of the path for the directory entry
        stat($base ? $self->join_directory($base, $path) : $path);
        -d _ ? $self->directory($path) : 
        -f _ ? $self->file($path) :
               $self->path($path);
    } @paths;
    
    return wantarray ? @paths : \@paths;
}


#-----------------------------------------------------------------------
# internal methods
#-----------------------------------------------------------------------

sub _child_args {
    my $self = shift->prototype;
    my $type = shift;
    my $args;
    
    if (! @_) {
        $args = { path => undef };
    }
    elsif (@_ == 1) {
        $args = ref $_[0] eq HASH ? shift : { path => shift };
#            : ! ref $_[0] ? { path => shift }
#            : return $self->error_msg( unexpected => "$type arguments" => $_[0], 'hash ref' )
    }
    else {
        $args = { path => [@_] };
    }
    $args->{ filesystem } = $self;
    return $args;
}


# TODO: move file?


1;

__END__

=head1 NAME

Badger::Filesystem - filesystem functionality

=head1 SYNOPSIS

    # using Path/File/Dir subroutines
    use Badger::Filesystem 'Path File Dir';
    
    # use native OS-specific paths:
    $path = Path('/path/to/file/or/dir');
    $file = File('/path/to/file');
    $dir  = Dir('/path/to/directory');           # short name
    $dir  = Directory('/path/to/directory');     # long name
    
    # or generic OS-independant paths
    $path = File('path', 'to', 'file', 'or', 'dir');
    $file = File('path', 'to', 'file');
    $dir  = Dir('path', 'to', 'directory');
    $dir  = Directory('path', 'to', 'directory');

    # using class methods
    use Badger::Filesystem;
    
    # we'll just show native paths from now on for brevity
    $path = Badger::Filesystem->path('/path/to/file/or/dir');
    $file = Badger::Filesystem->file('/path/to/file');
    $dir  = Badger::Filesystem->dir('/path/to/directory');

    # using object methods
    my $fsys = Badger::Filsystem->new;
    
    $path = $fsys->path('/path/to/file/or/dir');
    $file = $fsys->file('/path/to/file');
    $dir  = $fsys->dir('/path/to/directory');

    # filesystem options
    my $fsys = Badger::Filsystem->new(
        root      => '/path/to/my/web/site',
        separator => '/',     # path separator
        rootdir   => '/',     # root directory
        curdir    => '.',     # current directory
        updir     => '..',    # parent directory
    );
    
    $path = $fsys->path('/index.html');   # relative to f/s root
    print $path->absolute;                # /index.html
    print $path->definitive;              # /path/to/my/web/site/index.html

=head1 DESCRIPTION

The C<Badger::Filesystem> module defines an object class for accessing and
manipulating files and directories in a file system.  It provides a number
of methods that encapsulate the behaviours of various other filesystem
related modules, including L<File::Spec>, L<File::Path> and L<Cwd>.  For
example:

    # path manipulation
    my $dir  = Badger::Filesystem->join_dir('foo', 'bar', 'baz');
    my @dirs = Badger::Filesystem->split_dir('foo/bar/baz');

    # path inspection
    Badger::Filesystem->is_relative('foo/bar/baz');     # true
    Badger::Filesystem->is_absolute('foo/bar/baz');     # false

    # path conversion (relative to cwd)
    Badger::Filesystem->relative('/foo/bar/baz');       # true
    Badger::Filesystem->absolute('foo/bar/baz');     # false

It defines the L<Path()>, L<File()> and L<Directory()> subroutines to easily
create L<Badger::Filesystem::Path>, L<Badger::Filesystem::File> and
L<Badger::Filesystem::Directory> objects, respectively. The L<Dir> subroutine
is provided as an alias for L<Directory>.

    use Badger::Filesystem 'Path File Dir';

    my $path = Path('/any/generic/path');
    my $file = File('/path/to/file');
    my $dir  = Dir('/path/to/dir');

These subroutines are provided as a convenient way to call the L<path()>,
L<file()> and L<dir()> class methods. The above examples are functionally
equivalent to those shown below.

    use Badger::Filesystem;
    
    my $path = Badger::Filesystem->path('/any/generic/path');
    my $file = Badger::Filesystem->file('/path/to/file');
    my $dir  = Badger::Filesystem->dir('/path/to/dir');

You can also create a C<Badger::Filesystem> object and call object methods
against it.

    use Badger::Filesystem;

    my $fsys = Badger::Filesystem->new;
    my $file = $fsys->file('/path/to/file');
    my $dir  = $fsys->dir('/path/to/dir');

Creating an object allows you to define additional configuration parameters
for the filesystem.  At present, the only configuration item of interest is
C<root> which allows you to define a virtual root directory for a filesystem.

    my $fsys = Badger::Filesystem->new( root => '/my/web/site' );

This allows you to work with "absolute" paths that really aren't absolute at
all. This is particular useful when dealing with "absolute" and "relative"
paths in a web site.

    my $home = $fsys->file('index.html');      # /my/web/site/index.html
    print $home->relative;                     # index.html
    print $home->absolute;                     # /index.html
    print $home->definitive;                   # /my/web/site/index.html

You can open, read, write and generally perform any kind of operation on a
file or directory in a virtual file system the same way as you would for a
real file system (i.e. one without a virtual C<root> directory defined).
Behind the scenes, the filesystem object handles the mapping of paths in the
virtual file system to their physical counterparts via the L<definitive>
method. 

=head1 CONSTRUCTOR SUBROUTINES

The C<Badger::Filesystem> module defines the L<Path>, L<File> and L<Directory>
subroutines which can be used to create L<Badger::Filesystem::Path>,
L<Badger::Filesystem::File> and L<Badger::Filesystem::Directory> objects,
respectively. The L<Dir> subroutine is provided as an alias for L<Directory>.

To use these subroutines you must import them explicitly when you 
C<use Badger::Filesystem>.

    use Badger::Filesystem 'File Dir';
    my $file = File('/path/to/file');
    my $dir  = Dir('/path/to/dir');

You can specify multiple items in a single string as shown in the example
above, or as multiple items in more traditional Perl style, as shown below.

    use Badger::Filesystem qw(File Dir);

You can pass multiple arguments to these subroutines if you want to specify
your path in a platform-agnostic way.

    my $file = File('path', 'to, 'file');
    my $dir  = Dir('path', 'to', 'dir');

If you don't provide any arguments then the subroutines return the class name
associated with the object. For example, the L<File()> subroutine returns
L<Badger::Filesystem::File>. This allows you to use them as virtual classes,
(i.e. short-cuts) for the longer class names, if doing things the Object
Oriented way is your thing.

    my $file = File->new('path/to/file');
    my $dir  = Dir->new('path/to/dir');

The above examples are functionally identical to:

    my $file = Badger::Filesystem::File->new('path/to/file');
    my $dir  = Badger::Filesystem::Directory->new('path/to/dir');

=head1 CONSTRUCTOR METHODS

=head2 new()

This is a constructor method to create a new C<Badger::Filesystem> object.

    my $fs = Badger::Filesystem->new;

In most cases there's no need to create a C<Badger::Filesystem> object at
all.  You can either call class methods, like this:

    my $file = Badger::Filesystem->file('/path/to/file');

Or use the constructor subroutines like this:

    use Badger::Filesystem 'File';
    my $file = File('/path/to/file');

However, you might want to create a filesystem object to pass to some other
method or object to work with.  In that case, the C<Badger::Filesystem> 
methods work equally well being called as object or class methods.

=head3 Configuration Options

The other reason you might want to create a filesystem object is to provide
configuration options.  There is only one interesting option at present.

=head4 root

This allows you to define a virtual root for the filesystem.  

    my $fsys = Badger::Filesystem->new( root => '/my/web/site' );

A filesystem object with a virtual root directory works in a similar way
to the C<chroot> command.  Any absolute paths specified for this file 
system are then assumed to be relative to the virtual root.  For example,
we can create an object to represent a file in our virtual file system.

    my $home = $fsys->file('index.html');

This file as a relative path of C<index.html>.

    print $home->relative;                     # index.html

The absolute path is </index.html>.

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

=head2 path()

Creates a new L<Badger::Filesystem::Path> object. This is typically used for
manipulating paths that don't relate to a specific file or directory in a real
filesystem.

=head2 file()

Creates a new L<Badger::Filesystem::File> object to represent a file in a 
filesystem.

=head2 dir($path) / directory($path)

Creates a new L<Badger::Filesystem::Directory> object to represent a file in a
filesystem.  L<dir()> is an alias for L<directory()> to save on typing.

    my $dir = $fs->dir('/path/to/directory');           # native path
    my $dir = $fs->dir('path', 'to', 'directory');      # generic path

If you don't specify a directory path explicitly then it will default to 
the current working directory, as returned by L<cwd()>.

    my $cwd = $fs->dir;

=head1 PATH MANIPULATION METHODS

=head2 join_path($volume, $dir, $file)

Combines a filesystem volume (where applicable), directory name and file
name into a single path.  This is a wrapper around the 
L<catpath()|File::Spec/catpath()> and L<canonpath()|File::Spec/canonpath()> 
functions.

    my $path = $fs−>join_path($volume, $directory, $file);

=head2 join_dir(@dirs) / join_directory(@dirs)

Combines multiple directory names into a single path.  This is a wrapper
around the L<catdir()|File::Spec/catdir()> function in L<File::Spec>.

    my $dir = $fs−>join_dir('path', 'to', 'my', 'dir');

The final element can also be a file name.

    my $dir = $fs−>join_dir('path', 'to', 'my', 'file');

NOTE: The names of C<join_path()> and C<join_dir()> are slightly confusing
because C<join_dir()> is really joining a path (i.e. dir or file).  They're
chosen to mimic C<catpath()> and C<catdir()> in L<File::Spec>, but I might
rename them at some point in the near future.

=head2 split_path($path)

Splits a composite path into volume, directory name and file name components.
This is a wrapper around the L<splitpath()|File::Spec/splitpath()> function 
in L<File::Spec>.

    ($vol, $dir, $file) = $fs->split_path($path);

=head2 split_dir($dir) / split_directory($dir)

Splits a directory path into individual directory names.  This is a wrapper
around the L<splitdir()|File::Spec/splitdir()> function in L<File::Spec>.

    @dirs = $fs->split_dir($dir);

=head2 collapse_dir($dir) / collapse_directory($dir)

Reduces a directory to its simplest form by resolving and removing any C<.>
(current directory) and C<..> (parent directory) components (or whatever the
corresponding tokens are for the current and parent directories of your
filesystem). 

    print $fs->collapse_dir('/foo/bar/../baz');   # /foo/baz

The reduction is purely syntactic. No attempt is made to verify that the
directories exist, or to intelligently resolve parent directory where symbolic
links are involved.

C<collapse_dir()> is a direct alias of C<collapse_directory()> to save on 
typing.

=head1 PATH INSPECTION METHODS

=head2 is_relative($path)

Returns true if the path specified is relative. That is, if it does not start
with a C</>, or whatever the corresponding token for the root directory is for
your file system.

    $fs->is_relative('/foo');               # false
    $fs->is_relative('foo');                # true

=head2 is_absolute($path)

Returns true if the path specified is absolute.  That is, if it starts
with a C</>, or whatever the corresponding token for the root directory is
for your file system.

    $fs->is_absolute('/foo');               # true
    $fs->is_absolute('foo');                # false

=head1 PATH CONVERSION METHODS

=head2 absolute($path)

Converts a relative path to an absolute one.  The path passed as an argument
is assumed to be relative to the current working directory.

    $fs->cwd;                               # /foo/bar
    $fs->absolute('wam/bam');               # /foo/bar/wam/bam

=head2 relative($path)

Converts an absolute path to one that is relative to the current working
directory.

    $fs->cwd;                               # /foo/bar
    $fs->relative('/foo/bar/wam/bam');      # wam/bam

=head2 definitive($path)

Converts an absolute or relative path to a definitive one.  In most cases,
a definitive path is identical to an absolute one.

    $fs->definitive('/foo/bar');            # /foo/bar

However, if you're using a filesystem with a virtual root directory, then 
a I<definitive> path I<will> include the virtual root directory, whereas a 
an I<absolute> path will I<not> include it.

    my $fs= Badger::Filesystem->new( root => '/my/vfs' );
    $fs->absolute('/foo/bar');              # /foo/bar
    $fs->definitive('/foo/bar');            # /my/vfs/foo/bar

The C<Badger::Filesystem> module uses definitive paths when performing any
operations on the file system (e.g. opening and reading files and
directories). You can think of absolute paths as being like conceptual URIs
(identifiers) and definitive paths as being like concrete URLs (locators). In
practice, they'll both have the same value unless unless you're using a
virtual root directory.

=head1 FILE MANIPULATION METHODS

=head2 create_file($path)

Creates an empty file if it doesn't already exist.  Returns a true value
if the file is created and a false value if it already exists.  Errors are
thrown as exceptions.

    $fs->create_file('/path/to/file');

=head2 touch_file($path)

Creates a file if it doesn't exists, or updates the timestamp if it does.

    $fs->touch_file('/path/to/file');

=head2 delete_file($path)

Deletes a file.

    $fs->delete_file('/path/to/file');

=head2 open_file($path, $mode, $perms)

Opens a file for reading (by default) or writing/appending (by passing
C<$mode> and optionally C<$perms>). Accepts the same parameters as for the
L<IO::File::open()|IO::File> method and returns an L<IO::File> object.

    my $fh = $fs->open_file('/path/to/file');
    my $fh = $fs->open_file('/path/to/file', 'w');      
    my $fh = $fs->open_file('/path/to/file', 'w', 0644);

=head2 read_file($path)

Reads the content of a file, returning it as a list of lines (in list context)
or a single text string (in scalar context).

    my $text  = $fs->read_file('/path/to/file');
    my @lines = $fs->read_file('/path/to/file');

=head2 write_file($path, $content)

When called with a single C<$path> argument, this method opens the specified 
file for writing and returns an L<IO::File> object.

    my $fh = $fs->write_file('/path/to/file');
    $fh->print("Hello World!\n");
    $fh->close;

If any additional C<$content> argument(s) are passed then they will be 
written to the file.  The file is then closed and a true value returned 
to indicate success.  Errors are thrown as exceptions.

    $fs->write_file('/path/to/file', "Hello World\n", "Regards, Badger\n");

=head2 append_file($path)

This method is similar to L<write_file()>, but opens the file for appending
instead of overwriting.  When called with a single C<$path> argument, it opens 
the file for appending and returns an L<IO::File> object.

    my $fh = $fs->append_file('/path/to/file');
    $fh->print("Hello World!\n");
    $fh->close;

If any additional C<$content> argument(s) are passed then they will be 
appended to the file.  The file is then closed and a true value returned 
to indicate success.  Errors are thrown as exceptions.

    $fs->append_file('/path/to/file', "Hello World\n", "Regards, Badger\n");

=head1 DIRECTORY MANIPULATION METHODS

=head2 create_dir($path) / create_directory($path)

Creates the directory specified by C<$path>. Errors are thrown as exceptions.

    $fs->create_dir('/path/to/directory');

Additional arguments can be specified as per the L<File::Path> C<mkpath()> 
method.  NOTE: this may be subject to change.  Better to use C<File::Path>
directly for now if you're relying on this.

=head2 open_dir(@path) / open_directory(@path)

Returns an L<IO::Dir> handle opened for reading a directory or throws
an error if the open failed.

    my $dh = $fs->open_dir('/path/to/directory');

=head2 read_dir($dir, $all) / read_directory($dir, $all)

Returns a list (in list context) or a reference to a list (in scalar context)
containing the entries in the directory. 

    my @paths = $fs->read_dir('/path/to/directory');

By default, this excludes the current and parent entries (C<.> and C<..> or
whatever the equivalents are for your filesystem. Pass a true value for the
optional second argument to include these items.

    my @paths = $fs->read_dir('/path/to/directory', 1);

=head2 dir_children($dir, $all) / directory_children($dir, $all)

Returns a list (in list context) or a reference to a list (in scalar
context) of objects to represent the contents of a directory.  As per
L<read_dir()>, the current (C<.>) and parent (C<..>) directories
are excluded unless you set the C<$all> flag to a true value.  Files are
returned as L<Badger::Filesystem::File> objects, directories as
L<Badger::Filesystem::File> objects.  Anything else is returned as a
generic L<Badger::Filesystem::Path> object.

=head1 MISCELLANEOUS METHODS

=head2 cwd()

Returns the current working directory. This is a text string rather than a
L<Badger::Filesystem::Directory> object. Call the L<directory()> method
without an argument if you want a L<Badger::Filesystem::Directory> object
instead.

    my $cwd = $fs->cwd;

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2005-2008 Andy Wardley. All rights reserved.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
# TextMate: rocks my world
