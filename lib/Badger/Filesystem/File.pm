#========================================================================
#
# Badger::Filesystem::File
#
# DESCRIPTION
#   OO representation of a file in a filesystem.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Filesystem::File;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Filesystem::Path',
    constants   => 'ARRAY',
    constant    => {
        type    => 'File',
        is_file => 1,
    };

use Badger::Filesystem::Path ':fields';

*base = \&directory;

sub init {
    my ($self, $config) = @_;
    my ($path, $vol, $dir, $name);
    my $fs = $self->filesystem;

    if ($config->{ path }) {
        $path = $self->{ path } = $fs->join_dir($config->{ path });
        @$self{@VDN_FIELDS} = $fs->split_path($path);
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

sub directory {
    my $self = shift;
    return @_
        ? $self->filesystem->directory( $self->relative(@_) )
        : $self->parent;
}

sub file {
    my $self = shift;
    return @_
        ? $self->filesystem->file( $self->relative(@_) )
        : $self;
}

sub exists {
    my $self = shift;
    $self->filesystem->file_exists($self->{ path });
}

sub create {
    my $self = shift;
    $self->filesystem->create_file($self->{ path }, @_);
}

sub touch {
    my $self = shift;
    $self->filesystem->touch_file($self->{ path });
}

sub open {
    my $self = shift;
    $self->filesystem->open_file($self->{ path }, @_);
}

sub text {
    my $text = shift->read(@_);
    # TODO: bless?
    return $text;
}

sub read {
    my $self = shift;
    $self->filesystem->read_file($self->{ path }, @_);
}

sub write {
    my $self = shift;
    $self->filesystem->write_file($self->{ path }, @_);
}

sub append {
    my $self = shift;
    $self->filesystem->append_file($self->{ path }, @_);
}

sub delete {
    my $self = shift;
    $self->filesystem->delete_file($self->{ path }, @_);
}

1;

