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
    '""'     => \&text,
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
    $self->{ path } = $config->{ path }
        || return $self->error_msg( missing => 'path' );
    return $self;
}

sub filesystem {
    my $self = shift;
    $self->{ filesystem } 
        ||= $self->class->any_var('FILESYSTEM')->prototype;
}

sub parent {
    my $self   = shift;
    my $skip   = shift || 0;
    my $parent = $self->{ parent } 
        ||=  $self->{ directory }
            ? $self->filesystem->dir($self->{ directory })
            : $self->filesystem->cwd;

    return 
        # don't both returning parents above the root
        $self->{ path } eq $parent->{ path } ? $self
        # delegate to parent if there are generations to skip
      : $skip ? $parent->parent($skip - 1)
        # otherwise we've found the parent we're looking for
      : $parent;
}

sub is_absolute {
    my $self = shift;
    $self->{ absolute } = $self->filesystem->path_is_absolute($self->{ path })
        unless defined $self->{ absolute };
    return $self->{ absolute };
}

sub is_relative {
    ! $_[0]->is_absolute
}

sub absolute {
    my $self = shift;
    return $self->is_absolute
         ? $self
         : $self->new( $self->filesystem->make_absolute($self->{ path }) );
}

sub relative {
    my $self = shift;
    return $self->new( 
        $self->filesystem->make_relative($self->{ path }, shift) 
    )->collapse;
}

sub collapse {
    my $self = shift->absolute;
    my $fs   = $self->filesystem;
    $self->{ directory } = $fs->collapse_dir($self->{ directory });
    $self->{ path      } = $fs->join_path(@$self{@VDN_FIELDS});
    return $self;
}

sub exists {
    -e $_[0]->{ path };
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
    return $_[0]->{ stats } || $_[0]->stat;
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

sub text {
    $_[0]->{ path }
}

1;

