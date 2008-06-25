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
        FILESPEC     => 'File::Spec',
        NO_FILENAME  => 1,
        is_directory => 1,
        type         => 'Directory',
    };

use Badger::Filesystem::Path ':fields';

*is_dir = \&is_directory;

sub init {
    my ($self, $config) = @_;
    my ($path, $name, $vol, $dir, @dirs);

    if ($path = $config->{ path }) {
        $path = FILESPEC->catdir(@$path) if ref $path eq ARRAY;
        $path = $self->{ path } = FILESPEC->canonpath($path);
        ($vol, $dir) = map { defined($_) ? $_ : '' } FILESPEC->splitpath($path, NO_FILENAME);
        @dirs = FILESPEC->splitdir($dir);
        $name = pop @dirs;
        $dir  = FILESPEC->catdir(@dirs);
        $self->debug("path: $path  vol: $vol  dir: $dir  name: $name\n") if $DEBUG;
        @$self{@VDN_FIELDS} = ($vol, $dir, $name);
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
    $_[0];
}

#sub open { 
#    IO::Dir->new(@_) 
#}

sub children {
    my $self = shift->must_exist;

}

1;

