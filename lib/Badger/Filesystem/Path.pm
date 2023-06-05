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
    base         => 'Badger::Filesystem::Base Badger::Exporter',
    import       => 'class',
    constants    => 'HASH ARRAY TRUE',
    get_methods  => 'path name volume directory',
    utils        => 'blessed',
    as_text      => 'path',
    is_true      => 1,
    constant     => {
        type         => 'Path',
        STAT_PATH    => 17,         # offset in extended stat fields
    },
    exports      => {
        tags     => { fields => '@STAT_FIELDS' },
    },
    messages     => {
        no_exist => '%s does not exist: %s',
        bad_stat => '%s cannot be scanned: %s',
        bad_look => 'No path specified to look %s',
        missing  => 'No %s specified',
    };

use Badger::Timestamp;
use Badger::Filesystem;
use Badger::Filesystem::Directory;


our $FILESYSTEM  = 'Badger::Filesystem';
our $TIMESTAMP   = 'Badger::Timestamp';
our $MATCH_EXT   = qr/\.([^\.]+)$/;       # TODO: is this filesystem-specific?
our @VDN_FIELDS  = @Badger::Filesystem::Base::VDN_FIELDS;
our @STAT_FIELDS = qw( device inode mode links user group device_type
                       size atime mtime ctime block_size blocks
                       readable writeable executable owner );
our $STAT_FIELD  = {
    # In here we'll store the map from stat field name to number
    #   device => 0,
    #   inode  => 1,
    #   ...etc...
};

our $TS_FIELD = {
    # On the left we have the timestamp methods we want to generate as
    # wrappers around the stat fields listed on the right.
    created  => 'ctime',
    accessed => 'atime',
    modified => 'mtime',
};

# generate methods to access stat fields: mode(), atime(), ctime(), etc.
my $n = 0;

class->methods(
    map {
        my $m = $n++;                       # new lexical variable for closure
        $STAT_FIELD->{ $_ } = $m;           # fill in $STAT_FIELD entry
        $_ => sub { $_[0]->stats->[$m] }    # generate subroutine
    }
    @STAT_FIELDS
);

# generate accessed(), created() and modified() methods which return
# Badger::Timestamp objects for the atime, ctime and mtime stat values

class->methods(
    map {
        my $method = $_;                    # new lexical variable for closure
        my $stat   = $TS_FIELD->{ $_ };
        my $statno = $STAT_FIELD->{ $stat };
        $method => sub {
            return $_[0]->{ $method }
                ||= $TIMESTAMP->new( $_[0]->stats->[$statno] )
        }
    }
    keys %$TS_FIELD
);


# define some aliases
*is_dir    = \&is_directory;
*dir       = \&directory;
*vol       = \&volume;     # goes up to 11
*ext       = \&extension;
*base_name = \&basename;
*up        = \&parent;
*meta      = \&metadata;
*canonical = \&absolute;
*perms     = \&permissions;


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

sub is_file {
    my $self = shift;
    my $defn = $self->filesystem->definitive_read($self->{ path }) || return;
    return -f $defn;
}

sub is_directory {
    my $self = shift;
    my $defn = $self->filesystem->definitive_read($self->{ path }) || return;
    return -d $defn;
}

sub absolute {
    my $self = shift;
    return $self->is_absolute
         ? $self->{ path }
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
    # use the definitive path from the last stat or fetch anew
    return
        ($self->{ stats } && $self->{ stats }->[STAT_PATH])
      || $self->filesystem->definitive($self->{ path });
}

sub collapse {
    my $self = shift;
    my $fs   = $self->filesystem;
    $self->{ directory } = $fs->collapse_directory( $self->{ directory } );
    $self->{ path      } = $fs->join_path( @$self{ @VDN_FIELDS } );
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
    shift->stat;
}

sub must_exist {
    my $self = shift;

    unless ($self->exists) {
        if (@_ && $_[0]) {
            my $flag = shift;
            # true flag indicates we should attempt to create it
            $self->create(@_);      # pass any other args, like dir file permission
        }
        else {
            return $self->error_msg( no_exist => $self->type, $self->{ path } );
        }
    }
    return $self;
}

sub create {
    shift->not_implemented;
}

sub stat {
    my $self  = shift->must_exist;
    my $stats = $self->filesystem->stat_path($self->{ path })
            ||  return $self->decline_msg( not_found => file => $self->{ path } );

    # the definitive path can be tagged on the end
#    $self->{ definitive } = $stats->[STAT_PATH]
#        if defined $stats->[STAT_PATH];

    return wantarray
        ? @$stats
        :  $stats;
}

sub stats {
    my $stats = $_[0]->{ stats } ||= $_[0]->stat;
    return wantarray
        ? @$stats
        :  $stats;
}

sub restat {
    my $self = shift;
    delete $self->{ stats };
    delete @$self{ keys %$TS_FIELD }; # timestamps for created, modified, etc.
    return $self->stats;
}

sub permissions {
    shift->mode & 0777;
}

sub chmod {
    my $self = shift;
    $self->filesystem->chmod_path($self->{ path }, @_);
    return $self;
}

sub basename {
    my $self = shift;
    my $name = $self->name;
    $name = $self->{ path } unless defined $name;
    $name =~ s/$MATCH_EXT//g;
    return $name;
}

sub extension {
    my $self = shift;
    return $self->{ path } =~ $MATCH_EXT
        ? $1
        : '';
}

sub filesystem {
    my $self = shift;
    return $self->class->any_var('FILESYSTEM')->prototype
        unless ref $self;
    $self->{ filesystem }
        ||= $self->class->any_var('FILESYSTEM')->prototype;
}

sub visit {
    my $self    = shift;
    my $visitor = $self->filesystem->visitor(@_);
    $visitor->visit($self);
    return $visitor;
}

sub collect {
    shift->visit(@_)->collect;
}

sub enter {
    # enter() is a custom accept() method for the entry point of a visitor
    shift->accept;
}

sub accept {
    $_[1]->visit_path($_[0]);
}

sub metadata {
    my $self = shift;
    my $meta = $self->{ metadata } ||= { };
    if (@_ == 1) {
        return $meta->{ $_[0] };
    }
    elsif (@_ > 1) {
        while (@_) {
            my $key = shift;
            $meta->{ $key } = shift;
        }
    }
    return $meta;
}

1;

=encoding utf8

=head1 NAME

Badger::Filesystem::Path - generic filesystem path object

=head1 SYNOPSIS

    # using Badger::Filesytem constructor subroutine
    use Badger::Filesystem 'Path';

    # use native OS-specific paths:
    $path = Path('/path/to/something');

    # or generic OS-independant paths
    $path = Path('path', 'to', 'something');

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
    $path->extension                # filename .XXX extension
    $path->basename                 # filename without .XXX extension
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

=head2 path()

This method returns the path as a text string.  It is called automatically
whenever the path object is stringified.

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

However, if you're using a L<virtual filesystem|Badger::Filesystem::Virtual>,
then the I<definitive> path I<will> include the virtual root directory,
whereas a the I<absolute> path will I<not>.

    my $vfs  = Badger::Filesystem::Virtual->new( root => '/my/vfs' );
    my $path = $vfs->file('/foo/bar');
    print $path->absolute;              # /foo/bar
    print $path->definitive;            # /my/vfs/foo/bar

=head2 canonical()

This method returns the canonical representation of the path. In most cases
this is the same as the absolute path (in fact the base class aliases the
C<canonical()> method directly to the L<absolute()> method).

    print Path('foo')->canonical;               # /your/current/path/foo
    print Path('/foo/bar')->canonical;          # /foo/bar
    print Path('/foo/bar/')->canonical;         # /foo/bar
    print Path('/foo/bar.txt')->canonical;      # /foo/bar.txt

Note that the C<Badger::Filesystem::Path> base class will I<remove> any
trailing slashes (or whatever the appropriate directory separator is for your
filesystem) from the end of an absolute path.

In the case of directories, implemented by the
L<Badger::Filesystem::Directory> subclass, a trailing slash (or relevant
separator for your filesystem) will be added.

    print Dir('/foo/bar')->canonical;          # /foo/bar/

This is done by delegation to the
L<slash_directory()|Badger::Filesystem/slash_directory()> method in
L<Badger::Filesystem>.

=head2 collapse()

Reduces the path to its simplest form by resolving and removing any C<.>
(current directory) and C<..> (parent directory) components (or whatever the
corresponding tokens are for the current and parent directories of your
filesystem).

    my $path = Path('/foo/bar/../baz')->collapse;
    print $path;   # /foo/baz

See the L<collapse_dir()|Badger::Filesystem/collapse_dir()> method in
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

=head2 parent($skip_generations) / up($skip_generations)

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

=head2 path_up()

This returns a text string representing the parent of a path.  If the path
contains multiple items (e.g. '/foo/bar' or 'foo/bar') then the last item
will be removed (e.g. resulting in '/foo' or 'foo' respectively).  If an
absolute path contains one item or none (e.g. '/foo' or '/') then the
root directory ('/') will be returned.  A relative path with only one item
(e.g. 'foo') is assumed to be relative to the current working directory
which will be returned (e.g. '/path/to/current/dir').

=head2 exists()

Returns true if the path exists in the filesystem (e.g. as a file, directory,
or some other entry), or false if not.

    if ($path->exists) {
        print "$path already exists\n";
    }
    else {
        print "Creating $path\n";
        # ...etc...
    }

=head2 must_exist($create)

Checks that the path exists (by calling L<exists()>) and throws an error
if it doesn't.

    $path->must_exist;                      # no need to check return value

The C<$create> flag can be set to have it attempt to L<create()> itself if it
doesn't already exist.  However, this only makes sense for file and directory
subclasses and not base class paths.

    $dir->must_exist(1);                    # create if it doesn't

=head2 create()

In the base class this will method will throw an error. You can't physically
create an abstract path unless you know what kind of concrete entity (e.g.
file or directory) it maps onto. In other words, the L<create()> method will
only work for the L<Badger::Filesystem::File> and
L<Badger::Filesystem::Directory> subclasses.

    $path->create;                          # FAIL
    $dir->create;                           # OK
    $file->create;                          # OK

=head2 chmod($perms)

This method changes the file permissions on a file or directory.

    $file->chmod(0775);

=head2 stat()

Performs a filesystem C<stat> on the path and returns a list (in list
context), or a reference to a list (in scalar context) containing the 13
information elements.

    @list = $path->stat;                    # list context
    $list = $path->stat;                    # scalar context

A summary of the fields is shown below. See C<perldoc -f stat> for complete
details. Each of the individual fields can also be accessed via their own
methods, also listed in the table.

    Field   Method          Description
    ------------------------------------------------------------------------
      0     device()        device number of filesystem
      1     inoode()        inode number
      2     mode()          file mode  (type and permissions)
      3     links()         number of (hard) links to the file
      4     user()          numeric user ID of file’s owner
      5     group()         numeric group ID of file’s owner
      6     device_type()   the device identifier (special files only)
      7     size()          total size of file, in bytes
      8     atime()         last access time in seconds since the epoch
      9     mtime()         last modify time in seconds since the epoch
     10     ctime()         inode change time in seconds since the epoch (*)
     11     block_size()    preferred block size for file system I/O
     12     blocks()        actual number of blocks allocated

In addition to those that are returned by Perl's inbuilt C<stat> function,
this method returns four additional flags.

     13     readable()      file is readable by current process
     14     writeable()     file is writeable by current process
     15     executable()    file is executable by current process
     16     owner()         file is owned by current process

=head2 stats()

A wrapper around the L<stat()> method which caches the results to avoid
making repeated filesystem calls.

    @list = $path->stats;                   # list context
    $list = $path->stats;                   # scalar context

Note that the L<accessed()>, L<created()> and L<modified()> methods also
cache the L<Badger::Timestamp> objects they create to represent the
access, creation and modification times respectively.

=head2 restat()

Clears any cached values stored by the L<stats()>, L<accessed()>,
L<created()> and L<modified()> methods and calls L<stats()> to reload
(and re-cache) the data from a L<stat()> call.

=head2 device()

Returns the device number for the file.  See L<stat()>.

=head2 inode()

Returns the inode number for the file.  See L<stat()>.

=head2 mode()

Returns the file mode for the file.  Note that this contains both the
file type and permissions.  See L<stat()>.

=head2 permissions() / perms()

Returns the file permissions.  This is equivalent to
C<< $file->mode & 0777 >>.

=head2 links()

Returns the number of hard links to the file.  See L<stat()>.

=head2 user()

Returns the numeric user ID of the file's owner.  See L<stat()>.

=head2 group()

Returns the numeric group ID of the file's group.  See L<stat()>.

=head2 device_type()

Returns the device identifier (for special files only).  See L<stat()>.

=head2 size()

Returns the total size of the file in bytes.  See L<stat()>.

=head2 atime()

Returns the time (in seconds since the epoch) that the file was last accessed.
See L<stat()>.

=head2 accessed()

Returns a L<Badger::Timestamp> object for the L<atime()> value.  This object
will auto-stringify to produce an ISO-8601 formatted date.  You can also
call various methods to access different parts of the time and/or date.

    print $file->accessed;              # 2009/04/20 16:25:00
    print $file->accessed->date;        # 2009/04/20
    print $file->accessed->year;        # 2009

=head2 mtime()

Returns the time (in seconds since the epoch) that the file was last modified.
See L<stat()>.

=head2 modified()

Returns a L<Badger::Timestamp> object for the L<mtime()> value.

    print $file->modified;              # 2009/04/20 16:25:00
    print $file->modified->time;        # 16:25:0
    print $file->modified->hour;        # 16

=head2 ctime()

Returns the time (in seconds since the epoch) that the file was created. See
L<stat()>.

=head2 created()

Returns a L<Badger::Timestamp> object for the L<ctime()> value.

    print $file->created;               # 2009/04/20 16:25:00
    print $file->created->date;         # 2009/04/20
    print $file->created->time;         # 16:25:00

=head2 block_size()

Returns the preferred block size for file system I/O on the file. See
L<stat()>.

=head2 blocks()

Returns the actual number of blocks allocated to the file. See L<stat()>.

=head2 readable()

Returns a true value if the file is readable by the current user (i.e. the
owner of the current process), false if not.  See L<stat()>.

=head2 writeable()

Returns a true value if the file is writeable by the current user (i.e. the
owner of the current process), false if not.  See L<stat()>.

=head2 executable()

Returns a true value if the file is executable by the current user (i.e. the
owner of the current process), false if not.  See L<stat()>.

=head2 owner()

Returns a true value if the file is owned by the current user (i.e. the
owner of the current process), false if not.  See L<stat()>.

=head2 filesystem()

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

=head2 visit($visitor)

Entry point for a filesystem visitor to visit a filesystem path.  A
reference to a L<Badger::Filesystem::Visitor> object (or subclass) should
be passed as the first argument.

    use Badger::Filesystem::Visitor;

    my $visitor = Badger::Filesystem::Visitor->new( recurse => 1 );
    $path->visit($visitor);

Alternately, a list or reference to a hash array of named parameters may be
provided. These will be used to instantiate a new
L<Badger::Filesystem::Visitor> object (via the L<Badger::Filesystem>
L<visitor()|Badger::Filesystem/visitor()> method) which will then be
applied to the path.  If no arguments are passed then a visitor is created
with a default configuration.

    # either list of named params
    $path->visit( recurse => 1 );

    # or reference to hash array
    $path->visit({ recurse => 1});

The method then calls the visitor
L<visit()|Badger::Filesystem::Visitor/visit()> passing C<$self> as an argument
to begin the visit.

=head2 accept($visitor)

This method is called to dispatch a visitor to the correct method for a
filesystem object. In the L<Badger::Filesystem::Path> base class, it calls the
visitor L<visit_path()|Badger::Filesystem::Visitor/visit_path()> method,
passing the C<$self> object reference as an argument. Subclasses redefine this
method to call other visitor methods.

=head2 enter($visitor)

This is a special case of the L<accept()> method which subclasses (e.g.
L<directory|Badger::Filesystem::Directory>) use to differentiate between the
initial entry point of a visitor and subsequent visits to directories
contained therein.  In the base class it simply delegates to the L<accept()>
method.

=head2 collect(\%params)

This is a short-cut to call the L<visit()> method and then the
L<collect()|Badger::Filesystem::Visitor/collect()> method on the
L<Badger::Filesystem::Visitor> object returned.

    # short form
    my @items = $path->collect( files => 1, dirs => 0 );

    # long form
    my @items = $path->visit( files => 1, dirs => 0 )->collect;

=head2 metadata() / meta()

This method allows you to associate metadata with a path.  The method
accepts multiple arguments to set metadata:

    $path->metadata( title => 'An Example', author => 'Arthur Dent' );

It also accepts a single argument to fetch a metadata item:

    print $path->metadata('author');        # Arthur Dent

You can also call it without arguments.  The method returns a reference
to a hash array of metadata items.

    my $meta = $path->metadata;
    print $meta->{ author };                # Arthur Dent

=head1 STUB METHODS

The following methods serve little or no purpose in the
C<Badger::Filesystem::Path> base class. They are redefined by the
C<Badger::Filesystem::Directory> and C<Badger::Filesystem::File> modules
to do the right thing.

=head2 is_file()

This method always returns false in the C<Badger::Filesystem::Path> base
class. The C<Badger::Filesystem::File> subclass redefines this to return
true.  NOTE: this may be changed to examine the filesystem and return true
if the path references a file.

=head2 is_directory() / is_dir()

This method always returns false in the C<Badger::Filesystem::Path> base
class. The C<Badger::Filesystem::Directory> subclass redefines this to return
true.  NOTE: this may be changed to examine the filesystem and return true
if the path references a file.

=head2 volume() / vol()

Returns any volume defined as part of the path. This method does nothing in
the C<Badger::Filesystem::Path> base class.

=head2 directory() / dir()

Returns the directory portion of a path. This method does nothing in the
C<Badger::Filesystem::Path> base class.

=head2 name()

Returns the file name portion of a path. This method does nothing in the
C<Badger::Filesystem::Path> base class.

=head2 extension() / ext()

Returns any file extension portion following the final C<.> in the path.
This works in the C<Badger::Filesystem::Path> base class by looking at the
full path.

    print Path('/foo/bar.txt')->extension;      # txt

=head2 basename() / base_name()

Returns the filename I<without> the file extension following the final
C<.> in the path.  This works (for some definition of "works") in the
C<Badger::Filesystem::Path> base class by looking at the path L<name()>,
if defined, or the full C<path> if not.  Note that this will produce
unexpected results in some cases due to the fact that the base class
does not define a value for L<name()>.  e.g.

    print Path('/foo/bar.txt')->basename;       # /foo/bar

However, in most cases you would be using this through a
L<Badger::Filesystem::File> subclass which will product the correct
results.

    print File('/foo/bar.txt')->basename;       # bar

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2005-2009 Andy Wardley. All rights reserved.

=head1 ACKNOWLEDGEMENTS

The C<Badger::Filesystem> modules are built around a number of existing
Perl modules, including L<File::Spec>, L<File::Path>, L<Cwd>, L<IO::File>,
L<IO::Dir> and draw heavily on ideas in L<Path::Class>.

Please see the L<ACKNOWLEDGEMENTS|Badger::Filesystem/ACKNOWLEDGEMENTS>
in L<Badger::Filesystem> for further information.

=head1 SEE ALSO

L<Badger::Filesystem>,
L<Badger::Filesystem::File>,
L<Badger::Filesystem::Directory>,
L<Badger::Filesystem::Visitor>.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
# TextMate: should support split pane editing
