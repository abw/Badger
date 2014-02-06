package Badger::Workplace;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Base',
    import      => 'class',
    utils       => 'Dir', # resolve_uri truelike falselike params self_params extend',
    accessors   => 'root urn',
    alias       => {
        directory => \&dir,
    };


#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    $self->init_workplace($config);
    return $self;
}

sub init_workplace {
    my ($self, $config) = @_;

    # The neophyte flag is used to indicate the special case where the root 
    # directory (and perhaps other support files, data, etc) don't yet exist
    # because some other bit of code is in the process of creating it anew.
    my $neophyte = $config->{ nephyte } || 0;

    # The root directory must exist unless this is a neophyte in which case 
    # we can create the directory.
    my $dir  = $config->{ root      }
            || $config->{ dir       } 
            || $config->{ directory }
            || return $self->error_msg( missing => 'root directory' );
    my $root = Dir($dir, $config->{ filespec });

    if (! $root->exists) {
        if ($self->{ neophyte }) {
            $root->mkdir;
        }
        else {
            return $self->error_msg( invalid => root => $dir );
        }
    }

    $self->{ root } = $root;
    $self->{ urn  } = $config->{ urn } // $root->name;
    $self->{ uri  } = $config->{ uri } // $self->{ urn };

    return $self;
}

#-----------------------------------------------------------------------------
# Methods for accessing directories and files relative to the workplace root
#-----------------------------------------------------------------------------

sub dir {
    my $self = shift;
    return @_
        ? $self->root->dir(@_)
        : $self->root;
}

sub file {
    my $self = shift;
    return $self->root->file(@_);
}

1;
