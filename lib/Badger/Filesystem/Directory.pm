#========================================================================
#
# Badger::Filesystem::Directory
#
# DESCRIPTION
#   OO representation of a file in a filesystem.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Filesystem::Directory;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Filesystem::Path',
    constants   => 'ARRAY',
    constant    => {
        is_directory => 1,
        type         => 'Directory',
    };

use Badger::Filesystem::Path ':fields';

*dir    = \&directory;
*is_dir = \&is_directory;

sub init {
    my ($self, $config) = @_;
    my ($path, $name, $vol, $dir, @dirs);
    my $fs = $self->filesystem;

    $self->debug("init(", $self->dump_data_inline($config), ")\n") if $DEBUG;
    
    if ($path = $config->{ path }) {
        $path = $self->{ path } = $fs->join_directory($path);
        @$self{@VDN_FIELDS} = $fs->split_path($path);
        $self->debug("path: $self->{ path }  vol: $self->{ volume }  dir: $self->{ directory }  name: $self->{ name }\n") if $DEBUG;
    }
    elsif ($self->{ name } = $config->{ name }) {
        @$self{@VD_FIELDS} = ($vol, $dir) = map { defined($_) ? $_ : '' } @$config{@VD_FIELDS};
        $self->{ path } = $fs->join_path($vol, $dir, $self->{ name });
        $self->debug("name: $self->{ name }  vol: $self->{ volume }  dir: $self->{ directory }  name: $self->{ name }  path: $self->{ path }\n") if $DEBUG;
    }
    else {
        $self->error_msg( missing => 'path or name' );
    }
    return $self;
}

sub base {
    $_[0];
}

sub directory {
    my $self = shift;
    return @_
        ? $self->filesystem->directory( $self->relative(@_) )
        : $self->{ directory };
}

sub file {
    my $self = shift;
    return @_
        ? $self->filesystem->file( $self->relative(@_) )
        : $self->error( missing => 'file name' );
}

sub create { 
    my $self = shift;
    $self->filesystem->create_directory($self->{ path }, @_);
}

sub delete { 
    my $self = shift;
    $self->filesystem->delete_directory($self->{ path }, @_);
}

sub open { 
    my $self = shift;
    $self->filesystem->open_directory($self->{ path }, @_);
}

sub read {
    my $self = shift->must_exist;
    $self->filesystem->read_directory($self->{ path }, @_);
}

sub children {
    my $self = shift;
    $self->debug("asking for $self->{ path } children\n") if $DEBUG;
    return $self->filesystem->directory_children($self->{ path }, @_);
}

sub files {
    my $self  = shift;
    my @files = grep { $_->is_file } $self->children;
    return wantarray ? @files : \@files;
}

1;

