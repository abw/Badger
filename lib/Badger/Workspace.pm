package Badger::Workspace;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Base',
    import      => 'class',
    utils       => 'resolve_uri truelike falselike Dir self_params',
    accessors   => 'root parent config_dir urn type',
    constants   => 'ARRAY HASH SLASH DELIMITER',
    constant    => {
        CACHE          => 'cache',
        CACHE_MANAGER  => 'Badger::Cache',
        CONFIG_DIR     => 'config',
        CONFIG_FILE    => 'workspace',
        CONFIG_MODULE  => 'Badger::Config::Directory',
        HUB            => 'hub',
        HUB_MODULE     => 'Badger::Hub',
        WORKSPACE_TYPE => 'workspace',
        COMPONENTS     => 'components',
        RESOURCES      => 'resources',
        DELEGATES      => 'delegates',
    },
    messages => {
        no_module  => 'No %s module defined.',
    };

our $LOADED      = { };
our $COLLECTIONS = [COMPONENTS, RESOURCES];


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
    $self->init_collections($config);
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
              || $config->{ config_data };
              #|| $config;
    my $parent = $self->{ parent };

    # load the configuration module (e.g. Badger::Config::Directory)
    class($cmod)->load;

    # config directory and filesystem
    my $config_dir = $self->dir($cdir);
    my $config_opt = {
        %$cspec,
        directory => $config_dir,
        file      => $cfile,
    };

    if ($cdata) {
        $config_opt->{ data } = $cdata;
    }
    if ($parent) {
        $config_opt->{ parent } = $parent->config;
    };
    my $config_obj = $cmod->new($config_opt);

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

sub init_collections {
    my ($self, $config) = @_;
    my $cols = $self->{ collections } = $self->class->list_vars(
        COLLECTIONS => $config->{ collections }
    );

    $self->debug(
        "COLLECTIONS: ", $self->dump_data($cols)
    ) if DEBUG;

    $self->init_collection($_) 
        for @$cols;
}

sub init_collection {
    my ($self, $type) = @_;

    # First look for any hashes defined in package variables for this module
    # or any of its subclasses, e.g. $COMPONENTS, $RESOURCES, etc.
    my $pkg_vars = $self->class->list_vars( uc $type );

    $self->configure_collection( $type => $_ )
        for @$pkg_vars;

    # Then read any additional configuration data from the config object
    # e.g. config/components.yaml
    $self->configure_collection(
        $type => $self->config($type)
    );

    $self->debug(
        "init_collection: $type => ", 
        $self->dump_data($self->{ $type })
    ) if DEBUG;
}

#-----------------------------------------------------------------------------
# Configuration methods that can be called at init() time or some time later
#-----------------------------------------------------------------------------

sub configure {
    my ($self, $config) = self_params(@_);
    my $item;

    if ($item = delete $config->{ parent }) {
        # if we change the parent workspace we must also re-attach the 
        # workspace config manager to the parent workspace config manager
        $self->{ parent } = $item;
        $self->{ config }->configure(
            parent => $item->config
        );
        $self->debug(
            "attached workspace to new parent workspace @", 
            $item->uri
        ) if DEBUG;
    }

    foreach my $collection ($self->collection_names) {
        if ($item = delete $config->{ $collection }) {
            $self->configure_collection( $collection => $item );
        }
    }

    # Other things in Contentity::Workspace that we might want to merge
    # back upstream at some point
    #   my $dirs    = delete($config->{ dirs         });
    #   my $cfile   = delete($config->{ config_file  });
    #   my $cfiles  = delete($config->{ config_files });
    #   if ($dirs)   { $self->dirs($dirs);                }
    #   if ($cfile)  { $self->init_config_file($cfile);   }
    #   if ($cfiles) { $self->init_config_files($cfiles); }
}

sub configure_components {
    shift->configure_collection(COMPONENTS, @_);
}

sub configure_resources {
    shift->configure_collection(RESOURCES, @_);
}

sub configure_collection {
    my ($self, $type, $source) = @_;
    my $collection = $self->{ $type } ||= { };
    my $components = $self->prepare_components($type, $source) || return;

    $self->debug(
        "OLD $type collection: ", $self->dump_data($collection), "\n",
        "ADD $type components: ", $self->dump_data($components)
    ) if DEBUG;

    @$collection{ keys %$components } = values %$components;

    if (DEBUG) {
        $self->debug("NEW $type collection: ", $self->dump_data($collection));
    }
}

sub prepare_components {
    my ($self, $type, $components) = @_;
    my $collection = { };
    my $component;

    return $collection
        unless $components;

    # text string is split to a list reference, 
    # e.g. 'database sitemap' => ['database','sitemap']
    $components = [ split(DELIMITER, $components) ]
        unless ref $components;

    # a list reference is mapped to a hash reference of hash refs
    # e.g. ['database','sitemap'] => { database => { }, sitemap => { } }
    $components = { 
        map { $_ => { } }
        @$components
    }   if ref $components eq ARRAY;

    # if it isn't a hash ref by this point then we can't handle it
    return $self->error_msg( invalid => components => $components )
        unless ref $components eq HASH;

    # Components can be set to any simple true value to enable them (e.g. 1) 
    # or a false value to explicitly disable them (e.g. 0).  Otherwise we 
    # expect them to be a module name (e.g. My::Component) or a hash reference
    # of configuration options, possibly including a 'module' item.
    while (my ($key, $value) = each %$components) {
        $component = $components->{ $key };

        if (! $component) {
            # ignore false values
            next;
        }
        elsif (ref $component eq HASH) {
            # reference to a hash is fine
        }
        elsif (ref $component) {
            # reference to anything else is not
            return $self->error_msg( invalid => "'$key' $type" => $component );
        }
        elsif (truelike $component) {
            # simple true value means yes, make it available
            $component = { };
        }
        else {
            # any other non-reference value is assumed to be a module name
            $component = {
                module => $component
            };
        }

        $collection->{ $key } = $component;

    }

    return $collection;
}


#-----------------------------------------------------------------------------
# tmp
#-----------------------------------------------------------------------------
#sub init_hub {
#    my ($self, $config) = @_;
#    my $hub = delete $config->{ hub } 
#        || $self->class->any_var(uc HUB)
#        || $self->HUB_MODULE;
#
#    $self->hub($hub);
#
#    return $self;
#}


#sub init_config_files {
#    my ($self, $files) = @_;
#    foreach my $file (@$files) {
#        $self->init_config_file($file);
#    }
#}

#sub init_config_file {
#    my ($self, $file) = @_;
#
#    # config file can have '?' suffix if it's optional
#    my $opt  = ($file =~ s/\?$//);
#
#    # only ever need to load an initialisation config file once (I think!)
#    my $done = $self->{ config_files_loaded } ||= { };
#    return if $done->{ $file };
#    $done->{ $file } = 1;
#
#    # load the config file, throw an error if it's not found and not optional
#    my $data = $self->config($file) 
#        || return $opt 
#            ? undef # $self->warn("Optional config file '$file' not found")
#            : $self->error( $self->reason );
#
#    $self->debug(
#        "Loaded config data from file '$file': ",
#        $self->dump_data($data)
#    ) if DEBUG;
#
#    $self->configure($data);
#}




#-----------------------------------------------------------------------------
# fetch config data from the config object
#-----------------------------------------------------------------------------

sub config {
    my $self   = shift;
    my $config = $self->{ config }; return $config unless @_;
    my @names  = map { ref $_ eq ARRAY ? @$_ : split /\./ } @_;
    my $name   = shift @names;
    my $data   = $config->get($name) 
        || return $self->decline_msg( not_found => 'configuration option' => $name );

    if ($data) {
        $self->dump_data("got data for $name: ", $self->dump_data($data));
    }

    return @names
        ? $config->dot($name, $data, \@names)
        : $data;
}

#-----------------------------------------------------------------------------
# components
#-----------------------------------------------------------------------------

sub component {
    my ($self, $name) = @_;
    my $config = $self->{ components }->{ $name }
        || return $self->error_msg( invalid => component => $name );

    $config = {
        module => $config,
    } unless ref $config;

    $self->debug("$name component config: ", $self->dump_data($config));

    # see if a module name is specified in $args, config hash or use $pkgmod
    my $module = $config->{ module }
        || return $self->error_msg( no_module => $name );

    # load the module
    $LOADED->{ $name } ||= class($module)->load;

    $self->debug(
        "$name module config: ", 
        $self->dump_data($config)
    ) if DEBUG;

    $config->{ workspace } = $self;

    return $module->new($config);
}

sub auto_component {
    my ($self, $name, $comp) = @_;
    my $class = ref $self || $self;


    return sub {
        my $self = shift;
        my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
        $self = $self->prototype unless ref $self;

        return $self->{ $name } 
            ||= $self->construct( 
                $name => { 
                    # TODO: figure out what's going on here in terms of
                    # possible combinations of configuration options
                    %$args, 
                    hub    => $self, 
                    module => $comp 
                } 
            );
    }
}


#-----------------------------------------------------------------------------
# relative workspaces
#-----------------------------------------------------------------------------

sub subspace {
    my ($self, $params) = self_params(@_);
    my $class = ref $self;
    $params->{ parent } = $self;
    return $class->new($params);
}

sub superspace {
    return shift->{ parent };
}

sub uberspace {
    my $self = shift;
    return $self->{ uberspace } 
       ||= $self->{ parent }
         ? $self->{ parent }->uberspace
         : $self;
}

#-----------------------------------------------------------------------------
# Miscellaneous methods
#-----------------------------------------------------------------------------

sub hub {
    my $self = shift;

    if (@_) {
        # got passed an argument (a new hub) which we connect $self to
        my $hub = shift;

        unless (ref $hub) {
            class($hub)->load;
            $self->debug("creating new hub, config is ", $self->config) if DEBUG;
            $hub = $hub->new(
                config => $self->config,
            );
        }
        $self->{ hub } = $hub;
    }

    return $self->{ hub };
}


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

sub collection_names {
    my $self = shift;
    my $cols = $self->{ collections } || [ ];
    return wantarray
        ? @$cols
        :  $cols;
}

sub destroy {
    my $self = shift;
    if ($self->{ hub }) {
        $self->debug("cleaning up hub") if DEBUG;
        $self->{ hub }->destroy;
        delete $self->{ hub };
    }
    delete $self->{ parent    };
    delete $self->{ uberspace };
}


sub DESTROY {
    shift->destroy;
}

1;
