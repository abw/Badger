package Badger::Workspace;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Workplace',
    import      => 'class',
    utils       => 'params',
    accessors   => 'config_dir',
    constants   => 'ARRAY HASH SLASH DELIMITER NONE',
    constant    => {
        # configuration directory and file
        CONFIG_MODULE  => 'Badger::Config::Filesystem',
        CONFIG_DIR     => 'config',
        CONFIG_FILE    => 'workspace',
        DIRS           => 'dirs',
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
    $self->init_config(@_);
    $self->init_dirs(@_);
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

    # config directory 
    $self->{ config_dir } = $conf_dir;

    # config directory manager
    $self->{ config } = $conf_mod->new(
        directory => $conf_dir,
        file      => $conf_file,
    );

    return $self;
}

sub init_dirs {
    my ($self, $config) = @_;
    my $dirs = $self->config(DIRS) || return;
    $self->dirs($dirs);
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

    $self->debug("[HEAD:$head] [TAIL:$tail]") if DEBUG;

    # the first element of a directory path can be an alias defined in dirs
    if ($alias = $dirs->{ $head }) {
        $self->debug(
            "resolve_dir($path) => [HEAD:$head=$alias] + [TAIL:$tail]"
        ) if DEBUG;
        return defined($tail)
            ? $alias->dir($tail)
            : $alias;
    }

    $self->debug("resolving: ", $self->dump_data(\@path)) if DEBUG;
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
    # nothing to be done here - subclasses may need to do stuff
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

=head2 dir($name)

=head2 dirs(\%dirmap)

=head2 resolve_dir($name)

=head2 file($path)

=head2 config($item)

When called without any arguments this returns a L<Badger::Config::Filesystem>
object which manages the configuration directory for the project.

    my $cfg = $workspace->config;

When called with a named item it returns the configuration data associated
with that item.  This will typically be defined in a master configuration 
file, or in a file of the same name as the item, with an appropriate file 
extension added.

    my $name = $workspace->config('name');

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

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2008-2014 Andy Wardley.  All Rights Reserved.

=cut
