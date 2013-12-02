package Badger::Workspace;

use Badger::Config::Directory;
use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Base',
    import      => 'class',
    utils       => 'resolve_uri Dir', #params extend weaken join_uri self_params Duration',
    accessors   => 'root superspace config_dir urn type',
#    config      => "directory|dir! type|method:WORKSPACE_TYPE",
    constants   => 'SLASH ARRAY', # :config DOT DELIMITER HASH  CODE',
    constant    => {
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
    # new config?
    $self->configure($config);
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

    $self->{ root } = $root;
    $self->{ type } = $type;
    $self->{ urn  } = $config->{ urn } || $root->name;
    $self->{ uri  } = $config->{ uri } || sprintf("%s:%s", $self->type, $self->urn);

    return $self;
}

sub init_config {
    my ($self, $config) = @_;
    my $class = $self->class;
    my $cspec = $config->{ config } || { };
    my $cdir  = delete $cspec->{ directory  } 
             || delete $cspec->{ dir        } 
             || $config->{ config_dir       }
             || $config->{ config_directory }
             || $self->CONFIG_DIR;
    my $cfile = delete $cspec->{ file }
             || $config->{ config_file } 
             || $self->CONFIG_FILE;
    my $cdata = delete $cspec->{ data }
             || $config->{ config_data };

    # config directory and filesystem
    my $config_dir = $self->dir($cdir);
    my $config_obj = $self->CONFIG_MODULE->new({
        %$cspec,
        directory => $config_dir,
        file      => $cfile,
        data      => $cdata,
    });

    # Hmmm... what about other stuff that's in the $config?  Can we ignore
    # it or do we need to pass it to the config module?  I think in most, if
    # not all cases, we can ignore it because the $config will usually only
    # contain the root directory reference and leave all the config data to
    # be defined in the config dir/file.

    # clean up anything else we don't want to store in the config
    delete $config->{ module };     # from hub/construct

    $self->{ config_dir } = $config_dir;
    $self->{ config     } = $config_obj;

    return $self;
}

sub configure {

}

sub configure_workspace {
    my ($self, $config) = @_;
    my $base    = delete($config->{ base         }) || delete($config->{ superspace });
    my $dirs    = delete($config->{ dirs         });
    my $schemas = delete($config->{ schemas      });
    my $meta    = delete($config->{ metadata     });
    my $cfile   = delete($config->{ config_file  });
    my $cfiles  = delete($config->{ config_files });

    if ($base)      { $self->init_superspace($base);     }
    if ($dirs)      { $self->dirs($dirs);                }
    if ($schemas)   { $self->schemas($schemas);          }
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
    my $cache  = $self->{ cache };
    my $data;#   = $self->fetch_cached_data($name) if $cache;

    if ($data) {
        $self->debug(
            "Got data from cache for $name: ", 
            $self->dump_data($data)
        ) if DEBUG or 1;
        return $data;
    }

    $data = $config->get($name);

    if ($data) {
        $self->dump_data("got data for $name: ", $self->dump_data($data));
    }
#        || return;

    #my $schema   = $config->schema($name);
    #my $cacheopt = $schema->{ shared_cache };

    # do other stuff... (like caching) - hmm on second thoughts, we should
    # cache it in the config - BUT that prevents us from adding in inherited
    # data... (unless we push it into the cache at the higher level of the 
    # workspace and read only in the config... nah, that's problematic...
    # could lead to data being merged/inherited over and over again... hmm)

    return @names
        ? $config->dot($name, $data, \@names)
        : $data;
}

#-----------------------------------------------------------------------------
# Shared memory cache
#-----------------------------------------------------------------------------

sub cache {
    # subclasses may define a cache
    return undef;
}

sub fetch_cached_data {
    my ($self, $key) = @_;
    my $cache    = $self->cache || return;
    my $uri      = $self->uri($key);
    my $data     = $cache->get($uri);

    $self->debug(
        "fetch_cached_data($key, [uri:$uri])\n",
        "Data loaded from cache: ",
        $self->dump_data($data)
    ) if (DEBUG || 1) && $data;

    return $data;
}

sub store_cached_data {
    my ($self, $key, $data, $schema) = @_;
    my $cache    = $self->cache       || return;
    my $duration = $schema->{ cache } || return;
    my $uri      = $self->uri($key);
    my $seconds  = $duration->seconds;

    # TODO: expiry times > 30 days are assumed to be unix timestamps
    $cache->set($uri, $data, $seconds);
    $self->debug(
        "store_cached_data($key [uri:$uri] [duration:$duration]): ", 
        $self->dump_data($data)
    ) if DEBUG or 1;

    return $data;
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
