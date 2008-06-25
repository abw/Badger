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
    constants   => 'HASH TRUE',
    constant    => {
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

{
    # define methods for path/root/updir/curdir that access a prototype object
    # when called as class methods.

    class->methods(
        map {
            my $name = $_;      # fresh copy of lexical for binding in closure
            $_ => sub {
                $_[0]->prototype->{ $name };
            }
        }
        qw( path root updir curdir )
    );

    # aliases for the above
    *slash  = \&root;
    *SLASH  = \&ROOTDIR;
    *dotdot = \&updir;
    *DOTDOT = \&UPDIR;
    *dot    = \&curdir;
    *DOT    = \&CURDIR;
    
    # and another
    *dir    = \&directory;
}


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

1;

