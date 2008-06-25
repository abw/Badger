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
        FILESPEC   => 'File::Spec',
        type       => 'File',
        is_file    => 1,
    };

use Badger::Filesystem::Path ':fields';

sub init {
    my ($self, $config) = @_;
    my ($path, $vol, $dir, $name);

    if ($path = $config->{ path }) {
        $path = FILESPEC->catdir(@$path) if ref $path eq ARRAY;
        $path = FILESPEC->canonpath($path);
        @$self{@VDN_FIELDS} = map { defined($_) ? $_ : '' } FILESPEC->splitpath($path);
        $self->{ path } = $path;
    }
    elsif ($self->{ name } = $config->{ name }) {
        @$self{@VD_FIELDS} = ($vol, $dir) = map { defined($_) ? $_ : '' } @$config{@VD_FIELDS};
        $self->{ path } = FILESPEC->catpath($vol, $dir, $self->{ name });
    }
    else {
        $self->error_msg( missing => 'path or name' );
    }
    return $self;
}

sub directory {
    $_[0]->parent;
}

1;

