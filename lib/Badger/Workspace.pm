package Badger::Workspace;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Workplace',
    import      => 'class',
    utils       => 'params self_params Filter',
    accessors   => 'config_dir',
    constants   => 'ARRAY HASH SLASH DELIMITER NONE BLANK',
    constant    => {
        # configuration directory and file
        CONFIG_MODULE  => 'Badger::Config::Filesystem',
        CONFIG_DIR     => 'config',
        CONFIG_FILE    => 'workspace',
        DIRS           => 'dirs',
        SHARE          => 'share',      # parent to child
        INHERIT        => 'inherit',    # child from parent
        MERGE          => 'merge',      # child from parent with merging
    };


#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    $self->init_workplace($config);
    $self->init_workspace($config);
    return $self;
}

sub init_workspace {
    my ($self, $config) = @_;

    # Initialise any parent connection and bootstrap the configuration manager
    $self->init_parent($config);
    $self->init_config($config);

    # Everything after this point reads configuration values from the config
    # object which includes $config above and also allows local configuration
    # files to provide further configuration data.
    $self->init_dirs;

    return $self;
}

sub init_parent {
    my ($self, $config) = @_;
    $self->{ parent } = delete $config->{ parent };
    #$self->attach(delete $config->{ parent });
    return $self;
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
    my $parent  = $self->parent;
    my $pconfig = $parent && $parent->config;

    #$self->debug("parent config: ", $self->dump_data($pconfig));

    # load the configuration module
    class($conf_mod)->load;

    # config directory 
    $self->{ config_dir } = $conf_dir;

    # config directory manager
    $self->{ config } = $conf_mod->new(
        parent    => $pconfig,
        data      => $config,
        directory => $conf_dir,
        file      => $conf_file,
        quiet     => $config->{ quiet },
    );

    return $self;
}

sub init_inheritance_NOT_USED {
    my $self = shift;
    # Nope, I'm going to keep this simple for now.
    #$self->init_filter(SHARE);
    #$self->init_filter(INHERIT);
    #$self->init_filter(MERGE);
    return $self;
}

sub init_filter_NOT_USED {
    my ($self, $name) = @_;
    my $config = $self->config($name);

    if (! ref $config) {
        # $config can be a single word like 'all' or 'none', or a shorthand
        # specification string, e.g. foo +bar -baz
        $config = { 
            accept => $config
        };
    }
    elsif (ref $config ne HASH) {
        # $config can be a reference to a list of items to include
        $config = { 
            include => $config
        };
    }
    # otherwise $config must be a HASH ref

    $self->debug(
        "$self->{ uri } $name filter spec: ", 
        $self->dump_data($config),
    ) if DEBUG;

    $self->{ $name } = Filter($config);

    $self->debug("$self $name filter: ", $self->{ $name }) if DEBUG;

    return $self;
}


sub init_dirs {
    my $self = shift;
    my $dirs = $self->config(DIRS) || return;
    $self->dirs($dirs);
    return $self;
}



#-----------------------------------------------------------------------------
# Delegate method to fetch config data from the config object
#-----------------------------------------------------------------------------

sub config {
    my $self   = shift;
    my $config = $self->{ config };
    return $config unless @_;
    return $config->get(@_)
        // $self->parent_config(@_);
}

sub parent_config {
    my $self   = shift;
    my $parent = $self->{ parent } || return;
    return $parent->config(@_);
}

sub share_config_NOT_USED {
    my $self   = shift;

    if ($self->can_share(@_)) {
        $self->debug("$self->{ uri } can share $_[0]") if DEBUG;
        return $self->config(@_);
    }
    elsif (DEBUG) {
        $self->debug("$self->{ uri } cannot share $_[0]");
    }
    return undef;
}

sub inherit_config_NOT_USED {
    my $self   = shift;
    my $parent = $self->{ parent } || return undef;

    if ($self->can_inherit(@_)) {
        $self->debug("$self->{ uri } can inherit $_[0]") if DEBUG;
        return $parent->share_config(@_);
    }
    elsif (DEBUG) {
        $self->debug("$self->{ uri } cannot inherit $_[0]");
    }
    return undef;
}

sub can_share_NOT_USED {
    shift->can_filter(SHARE, @_);
}

sub can_inherit_NOT_USED {
    shift->can_filter(INHERIT, @_);
}

sub can_filter_NOT_USED {
    my ($self, $type, $name) = @_;
    my $filter = $self->{ $type } || return;
    $self->debug("$self filter for [$type] is $filter") if DEBUG;
    return $filter->item_accepted($name);
}


#-----------------------------------------------------------------------------
# A 'dirs' config file can provide mappings for local workspace directories in
# case that they're not 1:1, e.g. images => resource/images
#-----------------------------------------------------------------------------

sub dir {
    my $self = shift;

    return @_
        ? $self->resolve_dir(@_)
        : $self->root;
}

sub dirs {
    my $self = shift;
    my $dirs = $self->{ dirs } ||= { };

    if (@_) {
        # resolve all new directories relative to workspace directory
        my $root  = $self->root;
        my $addin = params(@_);

        while (my ($key, $value) = each %$addin) {
            my $subdir = $root->dir($value);
            if ($subdir->exists) {
                $dirs->{ $key } = $subdir;
            }
            else {
                return $self->error_msg( 
                    invalid => "directory for $key" => $value 
                );
            }
        }
        $self->debug(
            "set dirs: ", 
            $self->dump_data($dirs)
        ) if DEBUG;
    }

    return $dirs;
}

sub resolve_dir {
    my ($self, @path) = @_;
    my $dirs = $self->dirs;
    my $path = join(SLASH, @path);
    my @pair = split(SLASH, $path, 2); 
    my $head = $pair[0];
    my $tail = $pair[1];
    my $alias;

    $self->debug_data( dirs => $dirs ) if DEBUG;

    $self->debug(
        "[HEAD:$head] [TAIL:", $tail // BLANK, "]"
    ) if DEBUG;

    # the first element of a directory path can be an alias defined in dirs
    if ($alias = $dirs->{ $head }) {
        $self->debug(
            "resolve_dir($path) => [HEAD:$head=$alias] + [TAIL:",
            $tail // BLANK, "]"
        ) if DEBUG;
        return defined($tail)
            ? $alias->dir($tail)
            : $alias;
    }

    $self->debug(
        "resolving: ", $self->dump_data(\@path)
    ) if DEBUG;

    return $self->root->dir(@path);
}

sub file {
    my ($self, @path) = @_;
    my $path = join(SLASH, @path);
    my @bits = split(SLASH, $path);
    my $file = pop(@bits);

    if (@bits) {
        return $self->dir(@bits)->file($file);
    }
    else {
        return $self->dir->file($file);
    }
}



#-----------------------------------------------------------------------------
# Workspaces can be attached to parent workspaces.
#-----------------------------------------------------------------------------

sub attach {
    my ($self, $parent) = @_;
    $self->{ parent } = $parent;
}

sub detach {
    my $self = shift;
    delete $self->{ parent };
}

sub parent {
    my $self = shift;
    my $n    = shift || 0;
    my $rent = $self->{ parent } || return;
    return $n
        ? $rent->parent(--$n)
        : $rent;
}

sub ancestors {
    my $self = shift;
    my $list = shift || [ ];
    push(@$list, $self);
    return $self->{ parent }
        ?  $self->{ parent }->ancestors($list)
        :  $list;
}

sub heritage {
    my $self = shift;
    my $ancs = $self->ancestors;
    return [ reverse @$ancs ];
}

#-----------------------------------------------------------------------------
# Methods to create a sub-workspace attached to the current one
#-----------------------------------------------------------------------------

sub subspace {
    my ($self, $params) = self_params(@_);
    my $class = $self->subspace_module($params);

    $params->{ parent } = $self;

    if ($DEBUG) {
        $self->debug("subspace() class: $class");
        $self->debug("subspace() params: ", $self->dump_data($params));
    }

    class($class)->load->instance($params);
}

sub subspace_module {
    my ($self, $params) = self_params(@_);
    return ref $self || $self;
}


#-----------------------------------------------------------------------------
# Cleanup methods
#-----------------------------------------------------------------------------

sub destroy {
    my $self = shift;
    $self->detach;
}

sub DESTROY {
    shift->destroy;
}

1;

__END__

=head1 NAME

Badger::Workspace - an object representing a project workspace

=head1 DESCRIPTION

This module implements an object for representing a workspace, for example
the directory containing the source, configuration, resources and other files
for a web site or some other project.  It is a subclass of L<Badger::Workplace>
which implements the base functionality.

The root directory for a workspace is expected to contain a configuration 
directory, called F<config> by default, containing configuration files for
the workspace.  This is managed by delegation to a L<Badger::Config::Filesystem>
object.

=head1 CLASS METHODS

=head2 new(\%config)

This is the constructor method to create a new C<Badger::Workspace> object.

    use Badger::Workspace;
    
    my $space = Badger::Workspace->new(
        directory => '/path/to/workspace',
    );

=head3 CONFIGURATION OPTIONS

=head4 root / dir / directory 

This mandatory parameter must be provided to indicate the filesystem path
to the project directory.  It can be also specified using any of the names
C<root>, C<dir> or C<directory>, as per L<Badger::Workplace>

=head4 config_module

The name of the delegate module for managing the files in the configuration
directory.  This defaults to L<Badger::Config::Filesystem>.

=head4 config_dir / config_directory

This optional parameter can be used to specify the name of the configuration
direction under the L<root> project directory.  The default configuration 
directory name is C<config>.

=head4 config_file

This optional parameter can be used to specify the name of the main 
configuration file (without file extension) that should reside in the 
L<config_dir> directory under the C<root> project directory.  The default 
configuration file name is C<workspace>.

=head1 PUBLIC METHODS

=head2 config($item)

When called without any arguments this returns a L<Badger::Config::Filesystem>
object which manages the configuration directory for the project.

    my $cfg = $workspace->config;

When called with a named item it returns the configuration data associated
with that item.  This will typically be defined in a master configuration 
file, or in a file of the same name as the item, with an appropriate file 
extension added.

    my $name = $workspace->config('name');

=head2 inherit_config($item)

Attempts to fetch an inherited configuration from a parent namespace.
The workspace must have a parent defined and must have the C<inherit>
option set to any true value.

=head2 parent_config($item)

Attempts to fetch the configuration for a named item from a parent workspace.
Obviously this requires the workspace to be attached to a parent.  Note that
this method is not bound by the C<inherit> flag and will delegate to any
parent regardless.

=head2 dir($name)

=head2 dirs(\%dirmap)

=head2 resolve_dir($name)

=head2 file($path)

=head2 attach($parent)

Attaches the workspace to a parent workspace.

=head2 detach()

Detaches the workspace from any parent workspace.

=head2 parent($n)

Returns the parent workspace if there is one.  If a numerical argument is
passed then it indicates a number of parents to skip.  e.g. if C<$n> is C<1>
then it bypasses the parent and returns the grandparent instead.  Thus, passing
an argument of C<0> is the same as passing no argument at all.

=head2 ancestors($list)

Returns a list of the parent, grandparent, great-grandparent and so on, all 
the way up as far as it can go.  A target list reference can be passed as an 
argument.

=head2 heritage()

This returns the same items in the C<ancestors()> list but in reverse order,
from most senior parent to most junior.

=head1 PRIVATE METHODS

=head2 init(\%config)

This method redefines the default initialisation method.  It calls the 
L<init_workplace()|Badger::Workplace/init_workplace()> method inherited
from L<Badger::Workplace> and then calls the L<init_workspace()> method
to perform any workspace-specific initialisation.

=head2 init_workspace(\%config)

This method performs workspace-specific initialisation.  In this module it
simply calls L<init_config()>.  Subclasses may redefine it to do something 
different.

=head2 init_config(\%config)

This initialised the L<Badger::Config::Filesystem> object which manages the
F<config> configuration directory.

=head2 init_dirs(\%config)

=head2 init_parent(\%config)

=head1 TODO

Inheritance of configuration data between parent and child workspaces.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2014 Andy Wardley.  All Rights Reserved.

=cut
