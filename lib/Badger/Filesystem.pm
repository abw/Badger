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
use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Prototype Badger::Exporter',
    import      => 'class',
    constants   => 'HASH ARRAY TRUE',
    constant    => {
        NO_FILENAME => 1,
        FILESPEC    => 'File::Spec',
        ROOTDIR     =>  File::Spec->rootdir,
        UPDIR       =>  File::Spec->updir,
        CURDIR      =>  File::Spec->curdir,
        Path        => 'Badger::Filesystem::Path',
        File        => 'Badger::Filesystem::File',
        Directory   => 'Badger::Filesystem::Directory',
    },
    exports => {
        tags    => { 
            types   => 'File Dir Directory',
            dirs    => 'ROOTDIR UPDIR CURDIR',
        },
    },
    messages => {
        open_failed   => 'Failed to open %s %s: %s',
        delete_failed => 'Failed to delete %s %s: %s',
    };

use Badger::Filesystem::File;
use Badger::Filesystem::Directory;
use Cwd 'getcwd';

# define methods for path/root/updir/curdir that access a prototype object
# when called as class methods.

class->methods(
    map {
        my $name = $_;      # fresh copy of lexical for binding in closure
        $_ => sub {
            $_[0]->prototype->{ $name };
        }
    }
    qw( root rootdir updir curdir separator virtual )
);

*dir       = \&directory;
*open_dir  = \&open_directory;

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
        $self->{ virtual } = 0;
    }
    
    # the tokens used to represent the root directory ('/'), the 
    # parent directory ('..') and current directory ('.') default to
    # constants grokked from File::Spec
    $self->{ rootdir } = $config->{ rootdir } || ROOTDIR;
    $self->{ updir   } = $config->{ updir   } || UPDIR;
    $self->{ curdir  } = $config->{ curdir  } || CURDIR;

    # this is an ugly hack, but the File::Spec modules hard-code the path
    # separator in the catdir() method so we have to make this round-trip
    # to determine the path separator in a cross-platform manner
    my $sep = FILESPEC->catdir(('badger') x 2);
    $sep =~ s/badger//g;
    $self->{ separator } = $sep;

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
    # if we have a hard-code cwd set then return that, otherwise call 
    # getcwd to return the real current working directory.  NOTE: we don't
    # cache the dynamically resolved cwd as it'll change if chdir() is called
    $self->{ cwd } || getcwd;
}

# I don't like calling this path.  Path implies directory path to me, 
# not volume/dir/name

sub join_path {
    my $self = shift;
    my @args = map { defined($_) ? $_ : '' } @_[0..2];
    FILESPEC->canonpath( FILESPEC->catpath(@args) );
}

# and this works with files, too.  this one should be join_path

sub join_dir {
    my $self = shift;
    my $dir  = @_ == 1 ? shift : [ @_ ];
    $self->debug("join_dir($dir)\n") if $DEBUG;
    ref $dir eq ARRAY
        ? FILESPEC->catdir(@$dir)
        : FILESPEC->canonpath($dir);
}

sub split_path {
    my $self  = shift;
    my $path  = $self->join_dir(@_);
    my @split = map { defined($_) ? $_ : '' } FILESPEC->splitpath($path);
    return wantarray ? @split : \@split;
}

sub split_dir {
    my $self  = shift;
    my $path  = $self->join_dir(@_);
    my @split = FILESPEC->splitdir($path);
    return wantarray ? @split : \@split;
}

sub collapse_dir {
    my $self = shift->prototype;
    my @dirs = $self->split_dir(shift); 
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
    $self->join_dir(@path);
}

sub is_absolute {
    my $self = shift;
    FILESPEC->file_name_is_absolute($self->join_dir(@_)) ? 1 : 0;
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
    my $path = $self->join_dir(@_);
    return $path if FILESPEC->file_name_is_absolute($path);
    FILESPEC->catdir($self->cwd, $path);
}

sub relative {
    my $self = shift;
    FILESPEC->abs2rel($self->join_dir(@_), $self->cwd);
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

sub create_directory { 
    my $self = shift;
    my $path = $self->definitive(shift);
    require File::Path;
    File::Path::mkpath($path, @_)
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

sub directory_children {
    my $self  = shift;
    my $dir   = shift;
    my @paths = $self->read_directory($dir, @_);
    my $base  = $self->{ root } if $self->{ virtual };
    my $path;

    @paths = map {
        $path = $self->join_dir($dir, $_);
        $self->debug("$dir + $_ => $path") if $DEBUG;
        
        # if we're using a virtual root then we need to tack that on to
        # the start of the path for the directory entry
        stat($base ? $self->join_dir($base, $path) : $path);
        -d _ ? $self->directory($path) : 
        -f _ ? $self->file($path) :
               $self->path($path);
    } @paths;
    
    return wantarray ? @paths : \@paths;
}

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

1;

__END__
=head1 METHODS

=head2 open_directory(@path)

Returns an L<IO::Dir> handle opened for reading a directory or throws
an error if the open failed.

=head2 read_directory($dir,$all)

Returns a list (in list context) or a reference to a list (in scalar context)
containing the entries in the directory. 

    my @paths = $filesystem->read_directory('/path/to/dir');

By default, this excludes the current and parent entries (C<.> and C<..> or
whatever the equivalents are for your filesystem. Pass a true value for the
optional second argument to include these items.

    my @paths = $filesystem->read_directory('/path/to/dir', 1);

=head2 directory_children($dir,$all)

Returns a list (in list context) or a reference to a list (in scalar
context) of objects to represent the contents of a directory.  As per
L<read_directory()>, the current (C<.>) and parent (C<..>) directories
are excluded unless you set the C<$all> flag to a true value.  Files are
returned as L<Badger::Filesystem::File> objects, directories as
L<Badger::Filesystem::File> objects.  Anything else is returned as a
generic L<Badger::Filesystem::Path> object.
