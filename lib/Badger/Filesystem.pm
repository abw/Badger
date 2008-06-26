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
    FILESPEC->catdir($self->{ root }, $path);
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

sub open_file {
    shift;
    require IO::File;
    IO::File->new(@_);
}

sub open_directory {
    shift;
    require IO::Dir;
    IO::Dir->new(@_);
}

sub _child_args {
    my $self = shift->prototype;
    my $type = shift;
    my $args;
    
    if (! @_) {
        $args = { path => undef };
    }
    elsif (@_ == 1) {
        $args = ref $_[0] eq HASH ? shift
            : ! ref $_[0] ? { path => shift }
            : return $self->error_msg( unexpected => "$type arguments" => $_[0], 'hash ref' )
    }
    else {
        $args = { path => [@_] };
    }
    $args->{ filesystem } = $self;
    return $args;
}

1;

