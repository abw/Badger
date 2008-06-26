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
        is_dir  => 1,
        type    => 'Directory',
    };

use Badger::Filesystem::Path ':fields';

*is_directory = \&is_dir;

sub init {
    my ($self, $config) = @_;
    my ($path, $name, $vol, $dir, @dirs);
    my $fs = $self->filesystem;

    $self->debug("init(", $self->dump_data_inline($config), ")\n") if $DEBUG;
    
    if ($path = $config->{ path }) {
        $path = $self->{ path } = $fs->join_dir($path);
        @$self{@VDN_FIELDS} = $fs->split_path($path);
        $self->debug("** path: $self->{ path }  vol: $self->{ volume }  dir: $self->{ directory }  name: $self->{ name }\n") if $DEBUG;
    }
    elsif ($self->{ name } = $config->{ name }) {
        @$self{@VD_FIELDS} = ($vol, $dir) = map { defined($_) ? $_ : '' } @$config{@VD_FIELDS};
        $self->{ path } = $fs->join_path($vol, $dir, $self->{ name });
    }
    else {
        $self->error_msg( missing => 'path or name' );
    }
    return $self;
}

sub base {
    $_[0];
}

sub open { 
    my $self = shift;
    $self->filesystem->open_directory($self->{ path }, @_);
}

sub directory {
    my $self = shift;
    return @_
        ? $self->filesystem->directory( $self->relative(@_) )
        : $self;
}

sub file {
    my $self = shift;
    return @_
        ? $self->filesystem->file( $self->relative(@_) )
        : $self->error( missing => 'file name' );
}

sub children {
    my $self = shift->must_exist;
    
    $self->todo;
}

1;

