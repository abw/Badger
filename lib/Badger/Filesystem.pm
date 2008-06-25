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
        File        => 'Badger::Filesystem::File',
        Dir         => 'Badger::Filesystem::Directory',
        Directory   => 'Badger::Filesystem::Directory',
    },
    exports => {
        tags    => { 
            types   => 'File Dir Directory',
            dirs    => 'ROOTDIR UPDIR CURDIR SLASH DOTDOT DOT',
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
    qw( path root updir curdir path_separator )
);

# aliases for the above
*slash     = \&root;
*SLASH     = \&ROOTDIR;
*dotdot    = \&updir;
*DOTDOT    = \&UPDIR;
*dot       = \&curdir;
*DOT       = \&CURDIR;
*path_sep  = \&path_separator;
*separator = \&path_separator;
*dir       = \&directory;
*dot       = \&curdir;

sub new {
    my $class = shift; $class = ref $class || $class;
    my $args;
    
    if (@_ == 1) {
        $args = ref $_[0] eq HASH ? shift
            : ! ref $_[0] ? { path => shift }
            : return $class->error_msg( bad_args => $_[0] )
    }
    elsif (@_ == 0) {
        $args = { path => ROOTDIR };
    }
    else {
        $args = { @_ };
    }

    my $self = bless { }, $class;
    $self->init($args);
}

sub init {
    my ($self, $config) = @_;

    $self->{ path } = $config->{ path }
        || return $self->error_msg( missing => 'path' );

    $self->{ root   } = $config->{ root   } || $config->{ slash  } || ROOTDIR;
    $self->{ updir  } = $config->{ updir  } || $config->{ dotdot } || UPDIR;
    $self->{ curdir } = $config->{ curdir } || $config->{ dot    } || CURDIR;

    # this is an ugly hack, but the File::Spec modules hard-code the path
    # separator in the catdir() method so we have to make this round-trip
    # to determine the path separator in a cross-platform fashion
    my $sep = FILESPEC->catdir(('badger') x 2);
    $sep =~ s/badger//g;
    $self->{ path_separator } = $sep;
    
    return $self;
}

sub file {
    File->new( _child_args(@_) );
}

sub directory {
    Directory->new( _child_args(@_) );
}

sub cwd {
    $_[0]->directory(getcwd);
}

sub _child_args {
    my $self = shift->prototype;
    my $args;
    
    if (@_ == 1) {
        $args = ref $_[0] eq HASH ? shift
            : ! ref $_[0] ? { path => shift }
            : return $self->error_msg( unexpected => 'file arguments' => $_[0], 'hash ref' )
    }
    else {
        $args = { @_ };
    }
    $args->{ filesystem } = $self;
    return $args;
}

sub join_path {
    my $self = shift;
    my @args = map { defined($_) ? $_ : '' } @_[0..2];
    FILESPEC->canonpath( FILESPEC->catpath(@args) );
}

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
    my $self = shift;
    my @dirs = $self->split_dir(shift); 
    my ($up, $cur) = @$self{ updir curdir };
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

sub path_is_absolute {
    my $self = shift;
    FILESPEC->file_name_is_absolute($self->join_dir(@_));
}

sub make_relative {
    my $self = shift;
    FILESPEC->abs2rel($self->join_dir(@_));
}

sub make_absolute {
    my $self = shift;
    FILESPEC->rel2abs($self->join_dir(@_));
}


1;

