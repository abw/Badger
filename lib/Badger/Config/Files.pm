package Badger::Config::Files;

use Badger::Filesystem::Virtual;
use Badger::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    base      => 'Badger::Config',
    utils     => 'Dir VFS extend join_uri resolve_uri split_to_list params',
    constants => 'UTF8 YAML JSON DOT NONE TRUE FALSE',
    accessors => 'root extensions codecs schemas',
    messages  => {
        load_fail => 'Failed to load data from %s: %s',
    };

our $EXTENSIONS   = [YAML, JSON];
our $ENCODING     = UTF8;
our $CODECS       = { };


#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    $self->init_config($config);
    $self->init_files($config);
}

sub init_files {
    my ($self, $config) = @_;
    my $class = $self->class;

    # create hash of options for file objects created by directory object
    my $encoding = $config->{ encoding }
        || $class->any_var('ENCODING');

    my $filespec = {
        encoding => $encoding,
    };

    # we must have a root directory
    my $dir = $config->{ directory } || $config->{ dir }
        || return $self->error_msg( missing => 'directory' );

    my $root = Dir($dir, $filespec);

    unless ($root->exists) {
        return $self->error_msg( invalid => directory => $dir );
    }

    # a list of file extensions to try in order
    my $exts = $class->list_vars( 
        EXTENSIONS => $config->{ extensions } 
    );
    $exts = [
        map { @{ split_to_list($_) } }
        @$exts
    ];

    # construct a regex to match any of the above
    my $qm_ext = join('|', map { quotemeta $_ } @$exts);
    my $ext_re = qr/.($qm_ext)$/i;

    $self->debug("extensions: ", $self->dump_data($exts)) if DEBUG;
    $self->debug("extension regex: $ext_re") if DEBUG;

    # a mapping of file extensions to codecs, for any that Badger::Codecs 
    # can't grok automagically
    my $codecs = $class->hash_vars( 
        CODECS => $config->{ extensions } 
    );

    $self->{ root       } = $root;
    $self->{ uri        } = $config->{ uri } || $root->name;
    $self->{ extensions } = $exts;
    $self->{ match_ext  } = $ext_re;
    $self->{ codecs     } = $codecs;
    $self->{ encoding   } = $encoding;
    $self->{ filespec   } = $filespec;
    $self->{ uri_paths  } = $config->{ uri_paths };

    return $self;
}

#-----------------------------------------------------------------------------
# head() method replacing that in the Badger::Config base class
#-----------------------------------------------------------------------------


sub head {
    my ($self, $name) = @_;
#    $self->todo;
    return $self->fetch($name);
}

sub HEAD_CACHED_TODO {
    my ($self, $uri) = @_;
    my $schema = $self->schema($uri);
    my $cache  = $schema->{ cache };
    my $cdata  = $self->fetch_cached_data($uri, $schema) if $cache;
    my $data   = $cdata || $self->config_filesystem($uri, $schema);

    $self->debug(
        "metadata for $uri\nSCHEMA: ", 
        $self->dump_data($schema), 
        "\nDATA: ", 
        $self->dump_data($data)
    )  if DEBUG;

    if ($cdata) {
        # got data from the cache, that's cool
        $self->debug(
            "Got data from cache for $uri: ", 
            $self->dump_data($cdata)
        ) if DEBUG;
        return $cdata;
    }

    if ($schema) {
        # look to see if the schema says we should inherit some or all of 
        # this data from the parent superspace
        my $inherit = $schema->{ inherit };
        $self->debug("inherit option: $inherit") if DEBUG;
        $data = $self->inherit_metadata($uri, $data, $inherit)
            if $inherit;
    }

    $self->store_cached_data($uri, $data, $schema) 
        if $cache && $data;

    return $data;
}


#-----------------------------------------------------------------------------
# Public fetch/store methods
#-----------------------------------------------------------------------------

sub fetch {
    my ($self, $uri) = @_;

    my $file = $self->config_file($uri);
    my $dir  = $self->dir($uri);
    my $fok  = $file && $file->exists;
    my $dok  = $dir  && $dir->exists;

    $self->debugf(
        "fetch($uri)\n= [file:$fok:$file]\n= [dir:$dok:$dir]", 
    ) if DEBUG;

    if ($dok) {
        $self->debug("Found directory for $uri, loading tree") if DEBUG;
        return $self->fetch_tree($uri);
    }

    if ($fok) {
        $self->debug("Found file for $uri, loading file data") if DEBUG;
        my $data = $file->try->data;
        return $self->error_msg( load_fail => $file => $@ ) if $@;
        return $data;
    }

    $self->debug("No file or directory found for $uri") if DEBUG;
    return undef;

}

sub fetch_file {
    my ($self, $uri) = @_;

    my $file = $self->config_file($uri) || return;
    my $data = $file->try->data;
    return $self->error_msg( load_fail => $file => $@ ) if $@;
 
    $self->debug(
        "loaded metadata for $uri from file: ", 
        $self->dump_data($data)
    ) if DEBUG;

    return $data;
}

sub fetch_tree {
    shift->config_tree(@_);
}

sub fetch_flat_tree {
    shift->config_flat_tree(@_);
}

sub fetch_uri_tree {
    shift->config_uri_tree(@_);
}

sub fetch_under_tree {
    shift->config_under_tree(@_);
}


#-----------------------------------------------------------------------------
# Internal methods
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

sub config_file {
    my ($self, $name) = @_;

    return  $self->{ config_file }->{ $name } 
        ||= $self->find_config_file($name);
}

sub config_filespec {
    my $self     = shift;
    my $defaults = $self->{ filespec };

    return @_ 
        ? extend({ }, $defaults, @_)
        : { %$defaults };
}

sub find_config_file {
    my ($self, $name) = @_;
    my $root = $self->root;
    my $exts = $self->extensions;

    foreach my $ext (@$exts) {
        my $path = $name.DOT.$ext;
        my $file = $self->file($path);
        if ($file->exists) {
            $file->codec($self->codec($ext));
            return $file;
        }
    }
    return $self->decline_msg(
        not_found => file => $name
    );
}

sub codec {
    my ($self, $name) = @_;
    return $self->codecs->{ $name } || $name;
}


#-----------------------------------------------------------------------------
# Tree walking
#-----------------------------------------------------------------------------

sub config_tree {
    my ($self, $name, @opts) = @_;
    my $root    = $self->root;
    my $file    = $self->config_file($name);
    my $dir     = $root->dir($name);
    my $opts    = params(@opts);
    my $schema  = $opts->{ schema } || $opts;
    my $binder  = $schema->{ binder };
    my $data    = { };
    my $do_tree = TRUE;
    my $more;

    $self->debug(
        "Config tree options: ", 
        $self->dump_data(\@opts)
    ) if DEBUG;

    unless ($file && $file->exists || $dir->exists) {
        return $self->decline_msg( not_found => 'file or directory' => $name );
    }

    if ($file && $file->exists) {
        # read data from file
        $more = $file->try->data;
        return $self->error_msg( load_fail => $file => $@ ) if $@;
        $self->debug("Read metadata from file '$file':", $self->dump_data($more)) if DEBUG;
        @$data{ keys %$more } = values %$more;
    }

    # TODO can we put an option in here to select a tree binder and other options?
    if ($more = $data->{ _schema_ }) {
        $self->debug("_schema_: ", $self->dump_data($more)) if DEBUG;
        @$schema{ keys %$more } = values %$more;
    }

    if ($more = $schema->{ tree_type }) {
        $self->debug("_schema_.tree_type: $more") if DEBUG;
        if ($more eq NONE) {
            $do_tree = FALSE;
        }
        elsif ($binder = $self->tree_binder($more)) {
            $schema->{ binder } = $binder;
        }
        else {
            return $self->error_msg( invalid => tree_type => $more );
        }
    }

    if ($dir->exists) {
        # TODO: add in multiple roots where project has a parent project?

        # create a virtual file system rooted on the metadata directory
        # so that all file paths are resolved relative to it
        my $vfs = VFS->new( root => $dir );
        $self->debug("Reading metadata from dir: ", $dir->name) if DEBUG;
        $self->scan_config_dir($vfs->root, $data, $schema, $binder);
    }

    $self->debug("$name config: ", $self->dump_data($data)) if DEBUG;

    return $data;
}

sub scan_config_dir {
    my ($self, $dir, $data, $opts, $binder, $path) = @_;
    my $files  = $dir->files;
    my $dirs   = $dir->dirs;

    $self->debug(
        "scan_config_dir($dir, $data, ", 
        $self->dump_data_inline($opts),
        ", ", $binder, ")"
    ) if DEBUG;

    $data ||= { };

    foreach my $file (@$files) {
        next unless $file->name =~ $self->{ match_ext };
        $self->debug("found file: ", $file->name, ' at ', $file->path) if DEBUG;
        $self->scan_config_file($file, $data, $opts, $binder, $path);
    }
    foreach my $subdir (@$dirs) {
        $self->debug("found dir: ", $subdir->name, ' at ', $subdir->path) if DEBUG;
        $path ||= [ ];
        # if we don't have a data binder then we need to create a sub-hash
        my $name = $subdir->name;
        my $more = $binder ? $data : ($data->{ $name } = { });
        push(@$path, $name);
        $self->scan_config_dir($subdir, $more, $opts, $binder, $path);
        pop(@$path);
    }
}

sub scan_config_file {
    my ($self, $file, $data, $opts, $binder, $path) = @_;
    my $base = $file->basename;
    my $ext  = $file->extension;

    $self->debug(
        "scan_config_file($file, $data, ", 
        $self->dump_data_inline($opts),
        ", ", $binder, "path => ", $self->dump_data_inline($path), "])"
    ) if DEBUG;

    # set the codec to match the extension (or any additional mapping)
    # and set the data encoding
    $file->codec($self->codec($ext));
    $file->encoding( $self->{ encoding } );

    my $meta = $file->try->data;
    return $self->error_msg( load_fail => $file => $@ ) if $@;

    if ($binder) {
        $binder->($self, $data, $base, $meta, $opts, $path);
    }
    else {
        $base =~ s[^/][];
        $data->{ $base } = $meta;
    }
}


#-----------------------------------------------------------------------------
# Special cases that bind data defined in sub-directories into the parent
#-----------------------------------------------------------------------------

sub tree_binder {
    my ($self, $name) = @_;
    return $self->can("${name}_binder")
        || return $self->decline_msg( invalid => binder => $name );
}

sub config_bind_tree {
    my ($self, $bind, $name, @opts) = @_;
    my $binder = $self->tree_binder($bind)
        || return $self->error_msg( invalid => binder => $bind );
    my $opts   = params(@opts);
    $opts->{ binder } = $binder;
    return $self->config_tree($name, $opts);
}

sub config_flat_tree {
    shift->config_bind_tree( flat => @_ );
}

sub config_uri_tree {
    shift->config_bind_tree( uri => @_ );
}

sub config_under_tree {
    shift->config_bind_tree( under => @_ );
}

sub flat_binder {
    my ($self, $data, $base, $meta, $opts, $path) = @_;

    while (my ($key, $value) = each %$meta) {
        $data->{ $key } = $value;
    }
}

sub uri_binder {
    my ($self, $data, $base, $meta, $opts, $path) = @_;
    my $opt  = $opts->{ uri_paths } || $self->{ uri_paths };

    $self->debug("uri_paths option: $opt") if DEBUG;

    if ($path && @$path) {
        $base = join_uri(@$path, $base);
        $self->debug(
            "uri_binder path is set: ", 
            $self->dump_data($path),
            "\nnew base is $base"
        ) if DEBUG;
    }

    # This resolves base items as URIs relative to the parent
    # e.g. an entry "foo" in the site/bar.yaml file will be stored in the parent 
    # site as "bar/foo", but an entry "/bam" will be stored as "/bam" because 
    # it's an absolute URI rather than a relative one (relative to the $base)
    while (my ($key, $value) = each %$meta) {
        my $uri = resolve_uri($base, $key);
        if ($opt) {
            $uri = $self->fix_uri_path($uri, $opt);
        }
        $data->{ $uri } = $value;
        $self->debug(
            "loaded metadata for [$base] + [$key] = [$uri]"
        ) if DEBUG;
    }
}

sub fix_uri_path {
    my ($self, $uri, $option) = @_;

    $option ||= $self->{ uri_paths } || return $uri;

    if ($option eq 'absolute') {
        $self->debug("setting absolute URI path") if DEBUG;
        $uri = "/$uri" unless $uri =~ /^\//;
    }
    elsif ($option eq 'relative') {
        $self->debug("setting relative URI path") if DEBUG;
        $uri =~ s/^\///;
    }
    else {
        return $self->error_msg( invalid => 'uri_paths option' => $option );
    }

    return $uri;
}

sub under_binder {
    my ($self, $data, $base, $meta, $opts, $path) = @_;

    if ($path && @$path) {
        $base = join('_', @$path, $base);
        $self->debug(
            "under_binder path is set: ", 
            $self->dump_data($path),
            "\nnew base is $base"
        ) if DEBUG;
    }

    # Similar to the above but this joins items with underscores
    # e.g. an entry "foo" in site/bar.yaml will become "bar_foo"
    while (my ($key, $value) = each %$meta) {
        my $uri = resolve_uri($base, $key);
        for ($uri) {
            s[^/+][]g;
            s[/+$][]g;
            s[/+][_]g;
        }
        $data->{ $uri } = $value;
    }
}


1;

