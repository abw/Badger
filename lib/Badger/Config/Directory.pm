# TODO:
#  [X] allow schemas to be added after init
#  [X] allow master config file to contain schemas, etc.

package Badger::Config::Directory;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    base      => 'Badger::Config',
    utils     => 'Dir VFS Now Duration join_uri resolve_uri split_to_list 
                  extend params truelike falselike',
    constants => 'UTF8 YAML JSON DOT NONE TRUE FALSE',
    accessors => 'root extensions codecs schemas',
    messages  => {
        load_fail => 'Failed to load data from %s: %s',
    };

our $EXTENSIONS   = [YAML, JSON];
our $ENCODING     = UTF8;
our $CODECS       = { };
our $TREE_TYPE    = 'nest';
our $TREE_JOINT   = '_';


#-----------------------------------------------------------------------------
# Initialisation methods called at object creation time
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    $self->init_data($config);
    $self->init_directory($config);
    $self->init_schemas($config);
    $self->configure($config);
    return $self;
}

sub init_data {
    my ($self, $config) = @_;
    $self->{ data } = $config->{ data } || { %$config };
}

sub init_directory {
    my ($self, $config) = @_;
    my $class = $self->class;

    # create hash of options for file objects created by directory object
    my $encoding = $config->{ encoding }
        || $class->any_var('ENCODING');
    my $filespec = {
        encoding => $encoding,
    };

    # we must have a root directory
    my $dir  = $config->{ directory } || $config->{ dir }
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

    return $self;
}

sub init_schemas {
    my ($self, $config) = @_;
    my $class   = $self->class;
    my $schema  = $config->{ schema  } || { };
    my $schemas = $config->{ schemas };

    $self->{ schema  } = { };
    $self->{ schemas } = { };

    $schema->{ uri_paths  } 
        ||= $config->{ uri_paths }
        ||  $class->any_var('URI_PATHS');

    $schema->{ tree_type  } 
        ||= $config->{ tree_type }
        ||  $class->any_var('TREE_TYPE');

    $schema->{ tree_joint } 
        ||= $config->{ tree_joint }
        ||  $class->any_var('TREE_JOINT');

    $self->configure_schema($schema);
    $self->configure_schemas($schemas) if $schema;
}

#-----------------------------------------------------------------------------
# Configuration methods called at initialisation time or some time after
#-----------------------------------------------------------------------------

sub configure {
    my ($self, $config) = @_;

    $self->configure_schema($config->{ schema }) 
        if $config->{ schema };

    $self->configure_schemas($config->{ schemas })
        if $config->{ schemas };

    $self->configure_file($config->{ file })
        if $config->{ file };
}

sub configure_file {
    my ($self, $name) = @_;
    my $data = $self->config_file_data($name)
        || return $self->error_msg( invalid => file => $name );

    $self->debug(
        "Config file data: ",
        $self->dump_data($data)
    ) if DEBUG;

    $self->configure($data);
}

sub configure_schema {
    my ($self, $more) = @_;
    my $schema = $self->{ schema } ||= { };
    @$schema{ keys %$more } = values %$more;
}

sub configure_schemas {
    my ($self, $more) = @_;
    my $schemas = $self->{ schemas } ||= { };
    @$schemas{ keys %$more } = values %$more;
}


#-----------------------------------------------------------------------------
# head() method replacing that in the Badger::Config base class
#-----------------------------------------------------------------------------

sub head {
    my ($self, $name) = @_;
    return $self->cache_fetch($name)
        || $self->fetch($name);
}


# tail() is called when data is found.  Any schema in effect is passed
# as the third argument in case we need to do something with it.

sub tail {
    my ($self, $name, $data, $schema) = @_;
    $schema ||= $self->schema($name);
    $self->debug(
        "tail($name)\n  DATA: ", $self->dump_data($data), 
        "\n SCHEMA: ", $self->dump_data($schema)
    ) if DEBUG;

    my $duration = $schema->{ cache };
    if ($duration) {
        $self->debug("found cache duration option: $duration") if DEBUG;
        $self->cache_store($name, $data, $duration, $schema);
    }
    return $data;
}

#-----------------------------------------------------------------------------
# Caching via a Cache::* module
#-----------------------------------------------------------------------------

sub cache {
    my $self  = shift;

    return $self->{ cache } 
        unless @_;

    return @_ > 1
        ? $self->cache_store(@_)
        : $self->cache_fetch(@_);
}

sub cache_fetch {
    my ($self, $name) = @_;
    my $cache = $self->cache || return;
    return $cache->get($name);
}

sub cache_store {
    my ($self, $name, $data, $expires) = @_;
    my $cache = $self->cache || return;

    if (falselike($expires)) {
        $self->debug("cache never");
        return;
    }

    # see if we need to set an expiry timestamp
    if (truelike($expires)) {
        $self->debug("memory cache forever") if DEBUG or 1;
        $cache->set($name, $data);
    }
    else {
        $self->debug("caching for $expires") if DEBUG or 1;
        $cache->set($name, $data, $expires);
    }
}

# This is being fed back upstream from Contentity::Workspace - may not be 
# relevant, not sure yet.

sub head_with_caching_EXAMPLE {
    my ($self, $uri) = @_;

    # this is problematic as we end up creating two separate schemas,
    # furthermore, schema data defined as _schema_ in a file won't be read
    # until after the file has been read....
    my $schema = $self->schema($uri);

    # ...but we need some kind of schema to see if it might be in the cache
    my $cache  = $schema->{ cache };

    if ($cache) {
        $self->fetch_cached_data($uri, $schema) && return;
    }

    my $data = $self->fetch($uri);

    if ($schema) {
        # look to see if the schema says we should inherit some or all of 
        # this data from the parent superspace
        my $inherit = $schema->{ inherit };
        $data = $self->inherit_metadata($uri, $data, $inherit)
            if $inherit;
    }

    $self->store_cached_data($uri, $data, $schema) 
        if $cache && $data;

    return $data;
}


#-----------------------------------------------------------------------------
# Filesystem-specific fetch methods
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
        return $self->config_tree($uri);
    }

    if ($fok) {
        $self->debug("Found file for $uri, loading file data") if DEBUG;
        my $data = $file->try->data;
        return $self->error_msg( load_fail => $file => $@ ) if $@;
        return $self->tail(
            $uri, $data
        );
    }

    $self->debug("No file or directory found for $uri") if DEBUG;
    return undef;
}


#-----------------------------------------------------------------------------
# Tree walking
#-----------------------------------------------------------------------------

sub config_tree {
    my ($self, $name) = @_;
    my $root    = $self->root;
    my $file    = $self->config_file($name);
    my $dir     = $root->dir($name);
    my $do_tree = TRUE;
    my $data    = { };
    my ($file_data, $binder, $more);

    unless ($file && $file->exists || $dir->exists) {
        return $self->decline_msg( not_found => 'file or directory' => $name );
    }

    # start by looking for a data file
    if ($file && $file->exists) {
        $file_data = $file->try->data;
        return $self->error_msg( load_fail => $file => $@ ) if $@;
        $self->debug("Read metadata from file '$file':", $self->dump_data($data)) if DEBUG;
    }

    # fetch a schema for this data item constructed from the default schema
    # specification, any named schema for this item, any arguments, then any 
    # local _schema_ defined in the data file
    my $schema = $self->schema(
        $name, 
        $file_data ? delete $file_data->{ _schema_ } : ()
    );
    $self->debug(
        "combined schema for $name: ", 
        $self->dump_data($schema)
    ) if DEBUG;

    if ($more = $schema->{ tree_type }) {
        $self->debug("_schema_.tree_type: $more") if DEBUG;
        if ($more eq NONE) {
            $do_tree = FALSE;
        }
        elsif ($binder = $self->tree_binder($more)) {
            $do_tree = TRUE;
        }
        else {
            return $self->error_msg( invalid => tree_type => $more );
        }
    }

    if ($do_tree) {
        # merge file data using binder
        $binder->($self, $data, [ ], $file_data, $schema);
 
        if ($dir->exists) {
            # create a virtual file system rooted on the metadata directory
            # so that all file paths are resolved relative to it
            my $vfs = VFS->new( root => $dir );
            $self->debug("Reading metadata from dir: ", $dir->name) if DEBUG;
            $self->scan_config_dir($vfs->root, $data, [ ], $schema, $binder);
        }
    }
    else {
        $data = $file_data;
    }

    $self->debug("$name config: ", $self->dump_data($data)) if DEBUG;

    return $self->tail(
        $name, $data, $schema
    );
}

sub scan_config_dir {
    my ($self, $dir, $data, $path, $schema, $binder) = @_;
    my $files  = $dir->files;
    my $dirs   = $dir->dirs;
    $path   ||= [ ];
    $binder ||= $self->tree_binder;

    $self->debug(
        "scan_config_dir($dir, $data, ", 
        $self->dump_data_inline($path), ", ",
        $self->dump_data_inline($schema), ", ", 
        $binder, ")"
    ) if DEBUG;

    $data ||= { };

    foreach my $file (@$files) {
        next unless $file->name =~ $self->{ match_ext };
        $self->debug("found file: ", $file->name, ' at ', $file->path) if DEBUG;
        $self->scan_config_file($file, $data, $path, $schema, $binder);
    }
    foreach my $subdir (@$dirs) {
        $self->debug("found dir: ", $subdir->name, ' at ', $subdir->path) if DEBUG;
        # if we don't have a data binder then we need to create a sub-hash
        my $name = $subdir->name;
        #my $more = $binder ? $data : ($data->{ $name } = { });
        push(@$path, $name);
        #$self->scan_config_dir($subdir, $more, $path, $schema, $binder);
        $self->scan_config_dir($subdir, $data, $path, $schema, $binder);
        pop(@$path);
    }
}

sub scan_config_file {
    my ($self, $file, $data, $path, $schema, $binder) = @_;
    my $base = $file->basename;
    my $ext  = $file->extension;

    $self->debug(
        "scan_config_file($file, $data, ", 
        $self->dump_data_inline($path), ", ",
        $self->dump_data_inline($schema), ", ", 
        $binder, ")"
    ) if DEBUG;

    # set the codec to match the extension (or any additional mapping)
    # and set the data encoding
    $file->codec( $self->codec($ext) );
    $file->encoding( $self->{ encoding } );

    my $meta = $file->try->data;
    return $self->error_msg( load_fail => $file => $@ ) if $@;

    if ($binder) {
        $path ||= [ ];
        push(@$path, $base);
        $binder->($self, $data, $path, $meta, $schema);
        pop(@$path);
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
    my $self = shift;
    my $name = shift 
        || $self->{ tree_type } 
        || return $self->error_msg( missing => 'tree_type' );

    return $self->can("${name}_binder")
        || return $self->decline_msg( invalid => binder => $name );
}

sub nest_binder {
    my ($self, $parent, $path, $child, $schema) = @_;
    my $data = $parent;

    foreach my $key (@$path) {
        $data = $data->{ $key } ||= { };
    }
    while (my ($key, $value) = each %$child) {
        $data->{ $key } = $value;
    }
}

sub flat_binder {
    my ($self, $parent, $path, $child, $schema) = @_;

    while (my ($key, $value) = each %$child) {
        $parent->{ $key } = $value;
    }
}

sub join_binder {
    my ($self, $parent, $path, $child, $schema) = @_;
    my $joint = $schema->{ tree_joint } || $self->{ tree_joint };
    my $base  = join($joint, @$path);

    $self->debug(
        "join_binder path is set: ", 
        $self->dump_data($path),
        "\nnew base is $base"
    ) if DEBUG;

    # Similar to the above but this joins items with underscores
    # e.g. an entry "foo" in site/bar.yaml will become "bar_foo"
    while (my ($key, $value) = each %$child) {
        if ($key =~ s/^\///) {
            # if the child item has a leading '/' then we want to put it in 
            # the root so we leave $key unchanged
        }
        elsif (length $base) {
            # otherwise the $key is appended onto $base
            $key = join($joint, $base, $key);
        }
        $parent->{ $key } = $value;
    }
}

sub uri_binder {
    my ($self, $parent, $path, $child, $schema) = @_;
    my $opt  = $schema->{ uri_paths } || $self->{ uri_paths };
    my $base = join_uri(@$path);

    $self->debug("uri_paths option: $opt") if DEBUG;

    $self->debug(
        "uri_binder path is set: ", 
        $self->dump_data($path),
        "\nnew base is $base"
    ) if DEBUG;

    # This resolves base items as URIs relative to the parent
    # e.g. an entry "foo" in the site/bar.yaml file will be stored in the parent 
    # site as "bar/foo", but an entry "/bam" will be stored as "/bam" because 
    # it's an absolute URI rather than a relative one (relative to the $base)
    while (my ($key, $value) = each %$child) {
        my $uri = resolve_uri($base, $key);
        if ($opt) {
            $uri = $self->fix_uri_path($uri, $opt);
        }
        $parent->{ $uri } = $value;
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


#-----------------------------------------------------------------------------
# schema management
#-----------------------------------------------------------------------------

sub schema {
    my $self = shift;
    my $name = shift || return $self->{ schema };
    my $full = $self->{ merged_schemas } ||= { };
    delete $full->{ $name } if @_;
    return $full->{ $name } ||= extend(
        { },
        $self->{ schema  },
        $self->lookup_schema($name),
        @_
    );
}

sub lookup_schema {
    my $self    = shift;
    my $name    = shift;
    my $schemas = $self->{ schemas };
    my $schema  = $schemas->{ $name };

    while (! $schema && length $name) {
        # keep chopping bits off the end of the name to find a more generic
        # schema, e.g. forms/user/login -> forms/user -> forms
        last unless $name =~ s/\W\w+\W?$//;
        $self->debug("trying $name") if DEBUG;
        $schema = $schemas->{ $name };
    }
    return $schema;
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

sub config_file_data {
    my $self = shift;
    my $file = $self->config_file(@_) || return;
    my $data = $file->try->data;
    return $self->error_msg( load_fail => $file => $@ ) if $@;
    return $data;
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


1;

__END__

=head1 NAME

Badger::Config::Directory - reads configuration files in a directory

=head1 SYNOPSIS

    use Badger::Config::Directory;
    
    my $config = Badger::Config::Directory->new(
        dir => 'config'
    );

    # Fetch the data in config/lost.[yaml|json]
    my $lost = $config->get('lost')
        || die "lost: not found";

=head1 DESCRIPTION

This module is a subclass of L<Badger::Config> for reading data from 
configuration files in a directory.

Consider a directory that contains the following files and sub-directories:

    config/
        site.yaml
        style.yaml
        pages.yaml
        pages/
            admin.yaml
            developer.yaml

We can create a L<Badger::Config::Directory> object to read the configuration
data from the files in this directory like so:

    my $config = Badger::Config::Directory->new(
        dir => 'config'
    );

Reading the data from C<site.yaml> is as simple as this:

    my $site = $config->get('site');

Note that the file extension is B<not> required.  You can have either a 
C<site.yaml> or a C<site.json> file in the directory and the module will 
load whichever one it finds first.  It's possible to add other data codecs
if you want to use something other than YAML or JSON, but that's not 
documented yet.  Use the source, Luke.

You can also access data from within a configuration file.  If the C<site.yaml>
file contains the following:

    name:    My Site
    version: 314
    author:
      name:  Andy Wardley
      email: abw@wardley.org

Then we can read the version and author name like so:

    print $config->get('site.version');
    print $config->get('author.name');

If the configuration directory contains a sub-directory with the same name
as the data file being loaded (minus the extension) then any files under 
that directory will also be loaded.  Going back to our earlier example, 
the C<pages> item is such a case:

    config/
        site.yaml
        style.yaml
        pages.yaml
        pages/
            admin.yaml
            developer.yaml

There are three files relevant to C<pages> here.  Let's assume the content
of each is as follow:

F<pages.yaml>:

    one:        Page One
    two:        Page Two

F<pages/admin.yaml>:

    three:      Page Three
    four:       Page Four

F<pages/developer.yaml>:

    five:       Page Five

When we load the C<pages> data like so:

    my $pages = $config->get('pages');

We end up with a data structure like this:

    {
        one   => 'Page One',
        two   => 'Page Two',
        admin => {
            three => 'Page Three',
            four  => 'Page Four',
        },
        developer => {
            five  => 'Page Five',
        },
    }

Note how the C<admin> and C<developer> items have been loaded into the data.

The C<tree_type> option can be used to determine how this data is merged. 
To use this option, put it in a C<_schema_> section in a top level 
configuration file, e.g. the C<pages.yaml>:

F<pages.yaml>:

    one:        Page One
    two:        Page Two
    _schema_:
      tree_type: uri

This collapses the nested data files by combining the paths as URIs.

    {
        one             => 'Page One',
        two             => 'Page Two',
        admin/three     => 'Page Three',
        admin/four      => 'Page Four',
        developer/five  => 'Page Five',
    }

A C<tree_type> of C<join> will produce this instead:

    {
        one             => 'Page One',
        two             => 'Page Two',
        admin_three     => 'Page Three',
        admin_four      => 'Page Four',
        developer_five  => 'Page Five',
    }

You can specify a different character sequence to join paths via the 
C<tree_joint> option, e.g.

    _schema_:
      tree_type:  uri
      tree_joint: '-'

That would producing this data structure:

    {
        one             => 'Page One',
        two             => 'Page Two',
        admin-three     => 'Page Three',
        admin-four      => 'Page Four',
        developer-five  => 'Page Five',
    }

If you don't want the data nested at all then specify a C<flat> value for
C<tree_type>:

    {
        one   => 'Page One',
        two   => 'Page Two',
        three => 'Page Three',
        four  => 'Page Four',
        five  => 'Page Five',
    }

=head1 CONFIGURATION OPTIONS

=head2 directory / dir

The C<directory> (or C<dir> if you prefer) option must be provided to
specify the directory that the module should load configuration files 
from.  Directories can be specified as absolute paths or relative to the
current working directory.

    my $config = Badger::Config::Directory->new(
        dir => 'path/to/config/dir'
    );

=head2 data

Any additional configuration data can be provided via the C<data> named 
parameter:

    my $config = Badger::Config::Directory->new(
        dir  => 'path/to/config/dir'
        data => {
            name  => 'Arthur Dent',
            email => 'arthur@dent.org',
        },
    );

=head2 encoding

The character encoding of the configuration files.  Defaults to C<utf8>.

=head2 extensions

A list of file extensions to try in addition to C<yaml> and C<json>.
Note that you may also need to define a C<codecs> entry to map the 
file extension to a data encoder/decoder module.

    my $config = Badger::Config::Directory->new(
        dir        => 'path/to/config/dir'
        extensions => ['str'],
        codecs     => {
            str    => 'storable',
        }
    );

=head2 codecs

File extensions like C<.yaml> and C<.json> are recognised by L<Badger::Codecs>
which can then provide the appropriate L<Badger::Codec> module to handle the
encoding and decoding of data in the file.  The L<codecs> options can be used 
to provide mapping from other file extensions to L<Badger::Codec> modules.  

    my $config = Badger::Config::Directory->new(
        dir        => 'path/to/config/dir'
        extensions => ['str'],
        codecs     => {
            str    => 'storable',   # *.str files loaded via storable codec
        }
    );

You may need to write a simple codec module yourself if there isn't one for 
the data format you want, but it's usually just a few lines of code that are 
required to provide the L<Badger::Codec> wrapper module around whatever other 
Perl module or custom code you've using to load and save the data format.

=head2 tree_type

This option can be used to sets the default tree type for any configuration 
items that don't explicitly declare it by other means.  The default tree
type is C<nest>.  

The following tree types are supported:

=head3 nest

This is the default tree type, creating nested hash arrays of data.

=head3 join

Joins data paths together using the C<tree_joint> string which is C<_> by
default.

=head3 uri

Joins data paths together using slash characters to create URI paths.
An item in a sub-directory can have a leading slash (i.e. an absolute path)
and it will be promoted to the top-level data hash.

e.g.

    foo/bar + baz  = foo/bar/baz
    foo/bar + /bam = /bam

=head3 none

No tree is created.  No sub-directories are scanned.   You never saw me.
I wasn't here.

=head2 tree_joint

This option can be used to sets the default character sequence for joining
paths

=head1 METHODS

The following methods are implemented in addition to those inherited from
the L<Badger::Config> base class.

=head1 INTERNAL METHODS

=head2 init_directory($config)

=head2 head($item)

=head2 fetch($item)

=head2 config_tree()

=head2 scan_config_file($file, $data, $path, $schema, $binder)

Loads the data in a configuration C<$file> and merges it into the common 
C<$data> hash under the C<$path> prefix (a reference to an array).  The
C<$schema> contains any schema rules for this data item.  The C<$binder>
is a reference to a L<tree_binder()> method to handle the data merge.

=head2 scan_config_dir($dir, $data, $path, $schema, $binder)

Scans the diles in a configuration directory, C<$dir> and recursively calls
L<scan_config_dir()> for each sub-directory found, and L<scan_config_file()>
for each file.

=head2 tree_binder($name)

This method returns a reference to one of the binder methods below based
on the C<$name> parameter provided.

    # returns a reference to the nest_binder() method
    my $binder = $config->tree_binder('nest');

If no C<$name> is specified then it uses the default C<tree_type> of C<nest>.
This can be changed via the L<tree_type> configuration option.

=head2 nest_binder($parent, $path, $child, $schema)

This handles the merging of data for the L<nest> L<tree_type>.

=head2 flat_binder($parent, $path, $child, $schema)

This handles the merging of data for the L<flat> L<tree_type>.

=head2 uri_binder($parent, $path, $child, $schema)

This handles the merging of data for the L<uri> L<tree_type>.

=head2 join_binder($parent, $path, $child, $schema)

This handles the merging of data for the L<join> L<tree_type>.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2013 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
