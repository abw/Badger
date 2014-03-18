package Badger::Config::Filesystem;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    base      => 'Badger::Config Badger::Workplace',
    utils     => 'split_to_list extend VFS join_uri resolve_uri',
    accessors => 'root filespec encoding codecs extensions quiet',
    words     => 'ENCODING CODECS',
    constants => 'DOT NONE TRUE FALSE YAML JSON UTF8 ARRAY HASH SCALAR',
    constant  => {
        ABSOLUTE => 'absolute',
        RELATIVE => 'relative',
    },
    messages  => {
        no_config      => 'Missing configuration file: %s',
        load_fail      => 'Failed to load data from %s: %s',
        merge_mismatch => 'Cannot merge items for %s: %s and %s',
    };

our $EXTENSIONS = [YAML, JSON];
our $ENCODING   = UTF8;
our $CODECS     = { };


#-----------------------------------------------------------------------------
# Initialisation methods called at object creation time
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;

    # First call Badger::Config base class method to handle any 'items' 
    # definitions and other general initialisation
    $self->init_config($config);

    # Then our own custom init method
    $self->init_filesystem($config);
}

sub init_filesystem {
    my ($self, $config) = @_;
    my $class = $self->class;

    # The filespec can be specified as a hash of options for file objects 
    # created by the top-level directory object.  If unspecified, we construct 
    # it using any encoding option, or falling back on a $ENCODING package 
    # variable.  This is then passed to init_workplace().
    my $encoding = $config->{ encoding } 
                || $class->any_var(ENCODING);

    my $filespec = $config->{ filespec } ||= {
        encoding => $encoding
    };

    # now initialise the workplace root directory
    $self->init_workplace($config);

    # Configuration files can be in any data format which Badger::Codecs can
    # handle (e.g. JSON, YAML, etc).  The 'extensions' configuration option 
    # and any $EXTENSIONS defined in package variables (for the current class
    # and all base classes) will be tried in order
    my $exts = $class->list_vars( 
        EXTENSIONS => $config->{ extensions } 
    );
    $exts = [
        map { @{ split_to_list($_) } }
        @$exts
    ];

    # Construct a regex to match any of the above
    my $qm_ext = join('|', map { quotemeta $_ } @$exts);
    my $ext_re = qr/.($qm_ext)$/i;

    $self->debug(
        "extensions: ", $self->dump_data($exts), "\n",
        "extension regex: $ext_re"
    ) if DEBUG;

    # The 'codecs' option can provide additional mapping from filename extension
    # to codec for any that Badger::Codecs can't grok automagically
    my $codecs = $class->hash_vars( 
        CODECS => $config->{ codecs } 
    );

    my $data = $config->{ data } || { };

    $self->{ data       } = $data;
    $self->{ extensions } = $exts;
    $self->{ match_ext  } = $ext_re;
    $self->{ codecs     } = $codecs;
    $self->{ encoding   } = $encoding;
    $self->{ filespec   } = $filespec;
    $self->{ quiet      } = $config->{ quiet    } || FALSE;
    $self->{ dir_tree   } = $config->{ dir_tree } // TRUE;

    # Add any item schemas
    $self->items( $config->{ schemas } )
        if $config->{ schemas };

    # Configuration file allows further data items (and schemas) to be defined
    $self->init_file( $config->{ file } )
        if $config->{ file };

    return $self;
}

sub init_file {
    my ($self, $file) = @_;
    my $data = $self->get($file);

    if ($data) {
        # must copy data so as not to damage cached version
        $data = { %$data };

        $self->debug(
            "config file data from $file: ",
            $self->dump_data($data)
        ) if DEBUG;

        # file can contain 'items' or 'schemas' (I don't love this, but it'll do for now)
        $self->items(
            delete $data->{ items   },
            delete $data->{ schemas }
        );

        # anything else is config data
        extend($self->{ data }, $data);

        $self->debug("merged data: ", $self->dump_data($self->{ data })) if DEBUG;
    }
    elsif (! $self->{ quiet }) {
        $self->warn_msg( no_config => $file );
    }

    return $self;
}


#-----------------------------------------------------------------------------
# Redefine head() method in Badger::Config to hook into fetch() to load data
#-----------------------------------------------------------------------------

sub head {
    my ($self, $name) = @_;
    return $self->{ data }->{ $name }
        // $self->fetch($name);
}

sub tail {
    my ($self, $name, $data) = @_;
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
        return $self->config_tree($uri, $file, $dir);
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
    my $self    = shift;
    my $name    = shift;
    my $file    = shift || $self->config_file($name);
    my $dir     = shift || $self->dir($name);
    my $do_tree = $self->{ dir_tree };
    my $data    = undef; #{ };
    my ($file_data, $binder, $more);

    unless ($file && $file->exists || $dir->exists) {
        return $self->decline_msg( not_found => 'file or directory' => $name );
    }

    # start by looking for a data file
    if ($file && $file->exists) {
        $file_data = $file->try->data;
        return $self->error_msg( load_fail => $file => $@ ) if $@;
        $self->debug("Read metadata from file '$file':", $self->dump_data($file_data)) if DEBUG;
    }

    # fetch a schema for this data item constructed from the default schema
    # specification, any named schema for this item, any arguments, then any 
    # local schema defined in the data file
    my $schema = $self->item(
        $name, 
        $file_data ? delete $file_data->{ schema } : ()
    );
    $self->debug(
        "combined schema for $name: ", 
        $self->dump_data($schema)
    ) if DEBUG;

    if ($more = $schema->{ tree_type }) {
        $self->debug("schema.tree_type: $more") if DEBUG;
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
        $data   ||= { };
        $binder ||= $self->tree_binder('nest');
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

    $self->debug("Metadata: ", $self->dump_data($meta)) if DEBUG;

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
# Binder methods for combining multiple data sources (e.g. files in sub-
# directories) into a single tree.
#-----------------------------------------------------------------------------

sub tree_binder {
    my $self = shift;
    my $name = shift 
        || $self->{ tree_type } 
        || return $self->error_msg( missing => 'tree_type' );

    return $self->can("${name}_tree_binder")
        || return $self->decline_msg( invalid => binder => $name );
}

sub nest_tree_binder {
    my ($self, $parent, $path, $child, $schema) = @_;
    my $data = $parent;
    my $uri  = join('/', @$path);
    my @bits = @$path;
    my $last = pop @bits;

    $self->debug("Adding [$uri] as ", $self->dump_data($child))if DEBUG;

    foreach my $key (@bits) {
        $data = $data->{ $key } ||= { };
    }

    if ($last) {
        my $tail = $data->{ $last };

        if ($tail) {
            my $tref = ref $tail  || SCALAR;
            my $cref = ref $child || SCALAR;

            if ($tref eq HASH && $cref eq HASH) {
                $self->debug("Merging into $last") if DEBUG;
                @$tail{ keys %$child } = values %$tail;
            }
            else {
                return $self->error_msg( merge_mismatch => $uri, $tref, $cref );
            }
        }
        else {
            $self->debug("setting $last in data to $child") if DEBUG;
            $data->{ $last } = $child;
        }
    }
    else {
        $self->debug("No path, simple merge of child into parent") if DEBUG;
        @$data{ keys %$child } = values %$child;
    }

    $self->debug("New parent: ", $self->dump_data($parent)) if DEBUG;
}

sub flat_tree_binder {
    my ($self, $parent, $path, $child, $schema) = @_;

    while (my ($key, $value) = each %$child) {
        $parent->{ $key } = $value;
    }
}

sub join_tree_binder {
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

sub uri_tree_binder {
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
        my $uri = $base ? resolve_uri($base, $key) : $key;
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
# Internal methods
#-----------------------------------------------------------------------------

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

sub write_config_file {
    my ($self, $name, $data) = @_;
    my $root = $self->root;
    my $exts = $self->extensions;
    my $ext  = $exts->[0];
    my $path = $name.DOT.$ext;
    my $file = $self->file($path);

    $file->codec($self->codec($ext));
    $file->data($data);
}


sub codec {
    my ($self, $name) = @_;
    return $self->codecs->{ $name } 
        || $name;
}


#-----------------------------------------------------------------------------
# item schema management
#-----------------------------------------------------------------------------

sub items {
    return extend(
        shift->{ item }, 
        @_
    );
}

sub item {
    my ($self, $name) = @_;

    return  $self->{ item }->{ $name }
        ||= $self->lookup_item($name);
}

sub lookup_item {
    # hook for subclasses
    return undef;
}


sub has_item {
    my $self = shift->prototype;
    my $name = shift;
    my $item = $self->{ item }->{ $name };

    # This is all the same as in the base class up to the final test which 
    # looks for $self->config_file($name) as a last-ditch attempt

    if (defined $item) {
        # A 1/0 entry in the item tells us if an item categorically does or
        # doesn't exist in the config data set (or allowable set - it might 
        # be a valid configuration option that simply hasn't been set yet)
        return $item;
    }
    else {
        # Otherwise the existence (or not) of an item in the data set is 
        # enough to satisfy us one way or another
        return 1
            if exists $self->{ data }->{ $name };

        # Special case for B::C::Filesystem which looks to see if there's a
        # matching config file.  We cache the existence in $self->{ item }
        # so we know if it's there (or not) for next time
        return $self->{ item }->{ $name }
            =  $self->config_file($name);
    }
}


1;

__END__

=head1 NAME

Badger::Config::Filesystem - reads configuration files in a directory

=head1 SYNOPSIS

    use Badger::Config::Filesystem;
    
    my $config = Badger::Config::Filesystem->new(
        root => 'path/to/some/dir'
    );

    # Fetch the data in user.[yaml|json] in above dir
    my $user = $config->get('user')
        || die "user: not found";

    # Fetch sub-data items using dotted syntax
    print $config->get('user.name');
    print $config->get('user.emails.0');

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

We can create a L<Badger::Config::Filesystem> object to read the configuration
data from the files in this directory like so:

    my $config = Badger::Config::Filesystem->new(
        root => 'config'
    );

Reading the data from C<site.yaml> is as simple as this:

    my $site = $config->get('site');

Note that the file extension is B<not> required.  You can have either a 
C<site.yaml> or a C<site.json> file in the directory and the module will 
load whichever one it finds first.  It's possible to add other data codecs
if you want to use something other than YAML or JSON.

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

Note how the C<admin> and C<developer> items have been nested into the data.
The filename base (e.g. C<admin>, C<developer>) is used to define an entry
in the "parent" hash array containing the data in the "child" data file.

The C<tree_type> option can be used to change the way that this data is merged. 
To use this option, put it in a C<schema> section in the top level 
configuration file, e.g. the C<pages.yaml>:

F<pages.yaml>:

    one:        Page One
    two:        Page Two
    schema:
      tree_type: flat

If you don't want the data nested at all then specify a C<flat> value for
C<tree_type>.  This would return the following data:

    {
        one   => 'Page One',
        two   => 'Page Two',
        three => 'Page Three',
        four  => 'Page Four',
        five  => 'Page Five',
    }

The C<join> type collapses the nested data files by joining the file path
(without extension) onto the data items contain therein. e.g.

    {
        one             => 'Page One',
        two             => 'Page Two',
        admin_three     => 'Page Three',
        admin_four      => 'Page Four',
        developer_five  => 'Page Five',
    }

You can specify a different character sequence to join paths via the 
C<tree_joint> option, e.g.

    schema:
      tree_type:  join
      tree_joint: '-'

That would producing this data structure:

    {
        one             => 'Page One',
        two             => 'Page Two',
        admin-three     => 'Page Three',
        admin-four      => 'Page Four',
        developer-five  => 'Page Five',
    }

The C<uri> type is a slightly smarter version of the C<join> type.
It joins path elements with the C</> character to create URI paths.

    {
        one             => 'Page One',
        two             => 'Page Two',
        admin/three     => 'Page Three',
        admin/four      => 'Page Four',
        developer/five  => 'Page Five',
    }

What makes it special is that it follows the standard rules for URI resolution
and recognises a path with a leading slash to be absolute rather than relative
to the current location.

For example, the F<pages/admin.yaml> file could contain something like this:

F<pages/admin.yaml>:

    three:      Page Three
    /four:      Page Four

The C<three> entry is considered to be relative to the C<admin> file so results
in a final path of C<admin/three> as before.  However, C</four> is an absolute
path so the C<admin> path is ignored.  The end result is a data structure like 
this:

    {
        one             => 'Page One',
        two             => 'Page Two',
        admin/three     => 'Page Three',
        /four           => 'Page Four',
        developer/five  => 'Page Five',
    }

In this example we've ended up with an annoying inconsistency in that our
C</four> path has a leading slash when the other items don't.  The 
C<uri_paths> option can be set to C<relative> or C<absolute> to remove or add
leading slashes respectively, effectively standardising all paths as one or
the other.

    schema:
      tree_type:  uri
      uri_paths:  absolute

The data would then be returned like so:

    {
        /one            => 'Page One',
        /two            => 'Page Two',
        /admin/three    => 'Page Three',
        /four           => 'Page Four',
        /developer/five => 'Page Five',
    }

=head1 CONFIGURATION OPTIONS

=head2 root / directory / dir

The C<root> (or C<directory> or C<dir> if you prefer) option must be provided
to specify the directory that the module should load configuration files 
from.  Directories can be specified as absolute paths or relative to the
current working directory.

    my $config = Badger::Config::Filesystem->new(
        dir => 'path/to/config/dir'
    );

=head2 data

Any additional configuration data can be provided via the C<data> named 
parameter:

    my $config = Badger::Config::Filesystem->new(
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

    my $config = Badger::Config::Filesystem->new(
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

    my $config = Badger::Config::Filesystem->new(
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

=head2 schemas

TODO: document specification of item schemas.  The items below (tree_type 
through uri_paths) must now be defined in a schema.  Support for a default
schema has temporarily been disabled/broken.

=head2 tree_type

This option can be used to sets the default tree type for any configuration 
items that don't explicitly declare it by other means.  The default tree
type is C<nest>.  

NOTE: this has been changed.  Don't trust these docs.

The following tree types are supported:

=head3 nest

This is the default tree type, creating nested hash arrays of data.

=head3 flat

Creates a flat hash array by merging all nested hash array of data into one.

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

This option can be used to set the default character sequence for joining
paths

=head2 uri_paths

This option can be used to set the default C<uri_paths> option for joining
paths as URIs.  It should be set to C<relative> or C<absolute>.  It can 
be over-ridden in a C<schema> section of a top-level configuration file.

=head1 METHODS

The module inherits all methods defined in the L<Badger::Config> and 
L<Badger::Workplace> base classes.

=head1 INTERNAL METHODS

The following methods are defined for internal use.

=head2 init($config)

This overrides the default initialisation method inherited from 
L<Badger::Config>.  It calls the L<init_config()|Badger::Config/init_config()>
method to perform the base class L<Badger::Config> initialisation and then 
the L<init_filesystem()> method to perform initialisation specific to the 
L<Badger::Config::Filesystem> module.

=head2 init_filesystem($config)

This performs the initialisation of the object specific to the filesystem 
object.

=head2 head($item)

This redefines the L<head()|Badger::Config/head()> method in the 
L<Badger::Config> base class.  The method is called by 
L<get()|Badger::Config/get()> to fetch a top-level data item
(e.g. C<user> in C<$config-E<gt>get('user.name')>).  This implementation 
looks for existing data items as usual, but additionally falls back on a 
call to L<fetch($item)> to load additional data (or attempt to load it).

=head2 tail($item, $data)

This is a do-nothing stub for subclasses to redefine.  It is called after
a successful call to L<fetch()>.

=head2 fetch($item)

This is the main method called to load a configuration file (or tree of 
files) from the filesystem.  It looks to see if a configuration file 
(with one of the known L<extensions> appended, e.g. C<"$item.yaml">, 
C<"$item.json">, etc) exists and/or a directory named C<$item>.

If the file exists but the directory doesn't then the configuration data 
is read from the file.  If the directory exists

=head2 config_tree($item, $file, $dir)

This scans a configuration tree comprising of a configuration file and/or
a directory.  The C<$file> and C<$dir> arguments are optional and are only
supported as an internal optimisation.  The method can safely be called with
a single C<$item> argument and the relevant file and directory will be 
determined automatically.

The configuration file is loaded (via L<scan_config_file()>).  If the 
directory exists then it is also scanned (via L<scan_config_dir()>) and the
files contained therein are loaded.

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

=head2 nest_tree_binder($parent, $path, $child, $schema)

This handles the merging of data for the L<nest> L<tree_type>.

=head2 flat_tree_binder($parent, $path, $child, $schema)

This handles the merging of data for the L<flat> L<tree_type>.

=head2 uri_tree_binder($parent, $path, $child, $schema)

This handles the merging of data for the L<uri> L<tree_type>.

=head2 join_tree_binder($parent, $path, $child, $schema)

This handles the merging of data for the L<join> L<tree_type>.

=head2 config_file($name)

This method returns a L<Badger::Filesystem::File> object representing a 
configuration file in the configuration directory.  It will automatically
have the correct filename extension added (via a call to L<config_filename>)
and the correct C<codec> and C<encoding> parameters set (via a call to 
L<config_filespec>) so that the data in the configuration file can be 
automatically loaded (see L<config_data($name)>).

=head2 config_file_data($name)

This method fetches a configuration file via a call to L<config_file()>
and then returns the data contained therein.

=head2 config_filespec($params)

Returns a reference to a hash array containing appropriate initialisation
parameters for L<Badger::Filesystem::File> objects created to read general
and resource-specific configuration files.  The parameters are  constructed
from the C<codecs> (default: C<yaml>) and C<encoding> (default: C<utf8>) 
configuration options.  These can be overridden or augmented by extra
parameters passed as arguments.


=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

