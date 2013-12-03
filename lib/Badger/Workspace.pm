package Badger::Workspace;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Base',
    import      => 'class',
    utils       => 'resolve_uri Dir self_params',
    accessors   => 'root superspace config_dir urn type',
#    config      => "directory|dir! type|method:WORKSPACE_TYPE",
    constants   => 'SLASH ARRAY', # :config DOT DELIMITER HASH  CODE',
    constant    => {
        CACHE          => 'cache',
        CACHE_MANAGER  => 'Badger::Cache',
        CONFIG_DIR     => 'config',
        CONFIG_FILE    => 'workspace',
        CONFIG_MODULE  => 'Badger::Config::Directory',
        WORKSPACE_TYPE => 'workspace',
        #DIRS           => 'dirs',
        #DEFAULT_SCHEMA => '_default_',
        #COMMON_SCHEMA  => '_common_',
    },
    messages => {
    };


#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    $self->init_workspace($config);
    $self->init_config($config);

    # from this point on, all configuration is read from the config object
    # so we don't really need to pass $config, but it can't hurt, right?
    $self->init_cache($config);

    return $self;
}

sub init_workspace {
    my ($self, $config) = @_;
    my $class = $self->class;
    my $type  = $config->{ type      } || $self->WORKSPACE_TYPE;
    my $dir   = $config->{ directory } || $config->{ dir } || return $self->error_msg( missing => 'directory' );

    # must have a root directory
    my $root = Dir($dir);

    return $self->error_msg( invalid => directory => $dir )
        unless $root->exists;

    $self->{ root   } = $root;
    $self->{ type   } = $type;
    $self->{ urn    } = $config->{ urn } || $root->name;
    $self->{ uri    } = $config->{ uri } || sprintf("%s:%s", $self->type, $self->urn);
    $self->{ type   } = $type;
    $self->{ parent } = $config->{ parent };

    return $self;
}

sub init_config {
    my ($self, $config) = @_;
    my $class  = $self->class;
    my $cspec  = $config->{ config } || { };
    my $cmod   = delete $cspec->{ config_module } 
              || $self->CONFIG_MODULE;
    my $cdir   = delete $cspec->{ directory  } 
              || delete $cspec->{ dir        } 
              || $config->{ config_dir       }
              || $config->{ config_directory }
              || $self->CONFIG_DIR;
    my $cfile  = delete $cspec->{ file }
              || $config->{ config_file } 
              || $self->CONFIG_FILE;
    my $cdata  = delete $cspec->{ data }
              || $config->{ config_data }
              || $config;
    my $parent = $self->{ parent };

    # load the configuration module (e.g. Badger::Config::Directory)
    class($cmod)->load;

    # config directory and filesystem
    my $config_dir = $self->dir($cdir);
    my $config_obj = $cmod->new({
        %$cspec,
        directory => $config_dir,
        file      => $cfile,
        data      => $cdata,
        # mask any cache config parameters
        $parent
            ? (parent => $parent->config)
            : ( )
    });

    # Hmmm... what about other stuff that's in the $config?  Can we ignore
    # it or do we need to pass it to the config module?  I think in most, if
    # not all cases, we can ignore it because the $config will usually only
    # contain the root directory reference and leave all the config data to
    # be defined in the config dir/file.

    $self->{ config_dir } = $config_dir;
    $self->{ config     } = $config_obj;

    return $self;
}


sub init_cache {
    my ($self, $config) = @_;
    my $cache_config  = $self->config(CACHE) || return $self->warn('no cache');
    my $cache_manager = delete $config->{ cache_manager } 
        || $cache_config->{ manager }
        || $self->CACHE_MANAGER;

    class($cache_manager)->load;

    $self->debug(
        "cache manager config for $cache_manager: ", 
        $self->dump_data($cache_config)
    ) if DEBUG;

    my $cache = $cache_manager->new(
        uri => $self->uri,
        %$cache_config,
    );

    $self->debug("created new cache manager: $cache") if DEBUG;
    $self->{ cache } = $cache;

    # we must notify the config object that it has a cache to work with
    $self->config->configure( cache => $cache );
}


sub configure {
    my ($self, $config) = self_params(@_);
    my $item;

    if ($item = $config->{ parent }) {
        # if we change the parent workspace we must also re-attach the 
        # workspace config manager to the parent workspace config manager
        $self->{ parent } = $item;
        $self->{ config }->configure(
            parent => $item->config
        );
        $self->debug("attached workspace to new parent workspace @", $item->uri) if DEBUG;
    }
}

sub OLD_configure_workspace {
    my ($self, $config) = @_;
    my $base    = delete($config->{ base         }) || delete($config->{ superspace });
    my $dirs    = delete($config->{ dirs         });
    my $schemas = delete($config->{ schemas      });
    my $meta    = delete($config->{ metadata     });
    my $cfile   = delete($config->{ config_file  });
    my $cfiles  = delete($config->{ config_files });

    if ($dirs)      { $self->dirs($dirs);                }
    if ($meta)      { $self->metadata($meta);            }
    if ($cfile)     { $self->init_config_file($cfile);   }
    if ($cfiles)    { $self->init_config_files($cfiles); }

    if (%$config) {
        $self->debug(
            "things left over in $config: ", 
            $self->dump_data($config)
        ) if DEBUG;
        my $saved = $self->{ config };
        @$saved{ keys %$config } = values %$config; 
    }
}

#-----------------------------------------------------------------------------
# config data
#-----------------------------------------------------------------------------

sub config {
    my $self   = shift;
    my $config = $self->{ config }; return $config unless @_;
    my @names  = map { ref $_ eq ARRAY ? @$_ : split /\./ } @_;
    my $name   = shift @names;
    my $data   = $config->get($name) || return;

    if ($data) {
        $self->dump_data("got data for $name: ", $self->dump_data($data));
    }

    return @names
        ? $config->dot($name, $data, \@names)
        : $data;
}

#-----------------------------------------------------------------------------
# Subspaces
#-----------------------------------------------------------------------------

sub subspace {
    my ($self, $params) = self_params(@_);
    my $class = ref $self;
    $params->{ parent } = $self;
    return $class->new($params);
}

#-----------------------------------------------------------------------------

sub uri {
    my $self = shift;
    return @_
        ? sprintf("%s%s", $self->{ uri }, resolve_uri(SLASH, @_))
        : $self->{ uri };
}

sub dir {
    my $self = shift;

    return @_
        ? $self->root->dir(@_)
#        ? $self->resolve_dir(@_)
        : $self->root;
}


1;
