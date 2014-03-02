package Badger::Workspace;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Workplace',
    import      => 'class',
    utils       => 'extend',
    accessors   => 'root config_dir urn type',
    constants   => 'ARRAY HASH SLASH DELIMITER NONE',
    constant    => {
        # configuration directory and file
        CONFIG_MODULE  => 'Badger::Config::Filesystem',
        CONFIG_DIR     => 'config',
        CONFIG_FILE    => 'workspace',
    };


#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    $self->init_workplace($config);
    $self->init_workspace($config);
}

sub init_workspace {
    my ($self, $config) = @_;
    $self->init_config(@_);
}

sub init_config {
    my ($self, $config) = @_;
    my $conf_mod  = (
            delete $config->{ config_module } 
        ||  $self->CONFIG_MODULE
    );
    my $conf_dir  = $self->dir(
            delete $config->{ config_dir       }
        ||  delete $config->{ config_directory }
        ||  $self->CONFIG_DIR
    );
    my $conf_file = (
            delete $config->{ config_file } 
        ||  $self->CONFIG_FILE
    );

    # load the configuration module
    class($conf_mod)->load;

    # config directory and filesystem
    $self->{ config } = $conf_mod->new(
        directory => $conf_dir,
        file      => $conf_file,
    );

    $self->{ parent } = $config->{ parent };

    return $self;
}


#-----------------------------------------------------------------------------
# fetch config data from the config object
#-----------------------------------------------------------------------------

sub config {
    my $self   = shift;
    my $config = $self->{ config };
    return $config unless @_;
    return $config->get(@_);    
}


#-----------------------------------------------------------------------------
# Cleanup methods
#-----------------------------------------------------------------------------

sub destroy {
    my $self = shift;
    delete $self->{ parent    };
#    delete $self->{ uberspace };
}

sub DESTROY {
    shift->destroy;
}

1;

__END__


use Badger::Rainbow ANSI => 'cyan yellow magenta bold';
our $DEBUG_FORMAT = 
    cyan('[').
    bold(magenta('<uri> ')).
    bold(yellow('<where> ')).
    bold(cyan('line <line>')).
    cyan(']').
    "\n<msg>";

sub debug_magic {
    my $self = shift;
    return { 
        format => $DEBUG_FORMAT,
        uri    => $self->uri,
    };
}


1;

__END__

=head1 NAME

Badger::Workspace - an object representing a project workspace

=head1 DESCRIPTION

This module implements an object for representing a Badger workspace.

NOTE: this documentation was cut-n-pasted from Badger::Project which 
is in the process of being refactored.  Don't trust it to be accurate or
up to date.  The documentation will be updated when the refactoring is 
complete and the architecure more stable.

=head1 CLASS METHODS

=head2 new(\%config)

This is the constructor method to create a new C<Badger::Project> object.

    use Badger::Workspace;
    
    my $space = Badger::Workspace->new(
        directory => '/path/to/workspace'
    );

=head3 CONFIGURATION OPTIONS

=head4 directory

This mandatory parameter must be provided to indicate the filesystem path
to the project directory.  It can be also specified as either of the aliases
C<dir> or C<root>

=head4 config_dir

This optional parameter can be used to specify the name of the configuration
direction under the L<root> project directory.  The default configuration 
directory name is C<config>.

=head4 config_file

This optional parameter can be used to specify the name of the main 
configuration file (without file extension) that should reside in the 
L<config_dir> directory under the C<root> project directory.  The default 
configuration file name is C<Badger>.

=head1 GENERAL PURPOSE OBJECT METHODS

=head2 uri($path)

When called without any arguments this method returns the base URI for the 
project.

    print $project->uri;            # e.g. foo

When called with a relative URI path as an argument, it returns the URI
resolved relative to the project base URI. 

    print $project->uri;

=head2 dir($path)

Returns a L<Badger::Filesystem::Directory> object representing a directory
under the project root directory denoted by the C<$path> argument (or 
arguments).  Returns the root directory object when called without any 
arguments.

    my $root   = $project->dir;
    my $images = $project->dir('images');

=head2 resources_dir($path)

Returns a L<Badger::Filesystem::Directory> object for the directory in 
which resource data files are stored.  This is defined via the 
C<resources_dir> configuration option and is usually specified relative 
to the project root directory (C<resources> by default).  If one or more
C<$path> arguments are specified then it returns a directory underneath 
the resources directory, in a similar fashion to L<dir()>.

    my $resources = $project->resources_dir;
    my $forms     = $project->resources_dir('forms');
    my $widgets   = $project->resources_dir('ui/widgets');

=head2 resource_dir($type,$spec)

This is a more strict wrapper around L<resources_dir()> which provides
additional configuration parameters (from L<config_filespec()>) and asserts 
that the directory exists.  It caches the directory object for subequent use.
This should generally be used in preference to L<resources_dir()>.

    my $forms = $project->resource_dir('forms');

=head1 OBJECT METHODS FOR READING CONFIGURATION FILES

=head2 config_dir($path)

When called without any arguments this returns a L<Badger::Filesystem::Directory>
object representing the configuration directory for the project.

    my $dir = $project->config_dir;

When called with a relative directory path as argument it returns a 
L<Badger::Filesystem::Directory> representing the directory relative to
configuration directory. 

    my $dir = $project->config_dir('forms');

=head2 config_filename($name)

This method is used to construct the name of configuration files under the 
configuration directory.  It automatically appends the correct file extension.

    my $filename = $project->config_filename('foo');

=head2 config_filespec($params)

Returns a reference to a hash array containing appropriate initialisation
parameters for L<Badger::Filesystem::File> objects created to read general
and resource-specific configuration files.  The parameters are  constructed
from the C<config_codec> (default: C<yaml>) and C<config_encoding> (default:
C<utf8>) configuration options.  These can be overridden or augmented by extra
parameters passed as arguments.

=head2 config_file($name)

This method returns a L<Badger::Filesystem::File> object representing a 
configuration file in the configuration directory.  It will automatically
have the correct filename extension added (via a call to L<config_filename>)
and the correct C<codec> and C<encoding> parameters set (via a call to 
L<config_filespec>) so that the data in the configuration file can be 
automatically loaded (see L<config_data($name)>).

EDIT: Hmmm... it appear it doesn't add the filename extension, etc.  You 
have to do that via an additional call to L<config_filename()>.  This may
get changed RSN.  Watch this space.

=head2 config_data($name)

This method fetches a configuration file via a call to L<config_file()>
and then returns the data contained therein.

=head2 config_tree($name)

This method constructs a tree of configuration data from one or more 
configuration files under the configuration directory.  For example,
suppose there are F<config/urls.yaml> and F<config/urls/admin.yaml>
files that look like this:

Example F<config/urls.yaml>

    foo: /path/to/foo

Example F<config/urls/admin.yaml>

    bar: /path/to/bar

Then call the C<config_tree()> method like so:

    my $tree = $project->config_tree('urls');

The returned tree will contain the items defined in both files:

    {
        foo   => '/path/to/foo',
        admin => {
            bar => '/path/to/bar',
        }
    }

=head2 config_uri_tree($name)

This method works in a similar way to L<config_tree> but it merges nested
configuration files into a flat structure, using the file name (without the
file extension) as an intermediate URI component.  Consider the following
configuration files:

Example F<config/urls.yaml>

    foo: /path/to/foo

Example F<config/urls/admin.yaml>

    bar:  /path/to/bar
    /baz: /path/to/baz

Calling the C<config_uri_tree()> method like so:

    my $tree = $project->config_uri_tree('urls');

Will return a hash array like this:

    {
        foo         => '/path/to/foo',
        /admin/bar  => '/path/to/bar',
        /baz        => '/path/to/baz',
    }

Note that relative URIs (e.g. C<bar>) in nested files get appended to the 
file basename (e.g. C</admin/bar>) whereas those that are absolute (starting
with a C</> do not).  At present all resultant URIs from nested files are
absolute (i.e. C</admin/bar> instead of C<admin/bar>).  I'm not sure that's
necessarily correct but that's how it is for now.

=head2 scan_config_dir()

This method is used internally by L<config_tree()> to scan the files in a 
configuration directory.

=head2 scan_config_file()

This method is used internally by L<config_tree()> to load an individual 
files in a configuration directory.

=head2 uri_binder()

This method is used internally by L<config_uri_tree()> for resolving for 
constructing composite URIs.

=head1 OBJECT METHODS FOR LOADING COMPONENTS

Components are one-off (singleton) objects that can be loaded into a Badger
project.  For example, a database can be implemented as a component.  You 
generally only ever need to load one database component into a project and 
all other internal components and external code using the project can share it.

=head2 component($name)

Returns a cached instance of a named component or loads (and caches) it via
a call to L<load_component()>.

=head2 has_component($name)

Return a boolean value to indicate if this project has a named component

=head2 load_component($name)

=head2 component_config($name)

=head2 component_factory()



=head1 OBJECT METHODS FOR LOADING RESOURCES

=head1 INITIALISATION METHODS

These methods are used internally to initialise the C<Badger::Project>
object.

=head2 init(\%config)

This is the main initialisation method.  It performs some object initalisation,
sets sensible defaults for any missing values in the C<\%config> parameters 
and loads the configuration data defined in the main configuration file.  It 
then calls each of the following initialisation methods passing a reference 
to a hash array of merged configuration parameters.

=head2 init_project(\%merged_config)

This doesn't do anything much at present but is provided as a stub for 
future expansion.

=head2 init_components(\%merged_config)

This calls the L<prepare_components()> method to initialise all C<components>
defined in the merged configuration.

=head2 init_resources(\%merged_config)

This calls the L<prepare_components()> method to initialise all C<resources>
defined in the merged configuration.

=head2 prepare_components(\%components)

This initialises the configuration data for a set of plugin components.


=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2013 Andy Wardley.  All Rights Reserved.

=cut
