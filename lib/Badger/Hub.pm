#========================================================================
#
# Badger::Hub
#
# DESCRIPTION
#   A hub provides a central configuration and management point for 
#   Badger components to access other Badger components.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Hub;

use Badger::Debug ':dump';
use Badger::Config;
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Prototype',
    import    => 'class',
    auto_can  => 'auto_can',
    constants => 'HASH ARRAY REFS PKG',
    utils     => 'blessed params is_object',
    words     => 'COMPONENTS DELEGATES COMP_CACHE DELG_CACHE',
    constant  => {
        CONFIG_MODULE => 'Badger::Config',
    },
    messages => {
        no_module  => 'No %s module defined.',
        bad_method => "Invalid method '%s' called on %s at %s line %s",
    };

our $COMPONENTS    = { };
our $RESOURCES     = { };
our $DELEGATES     = { };
our $LOADED        = { };
#our $COLLECTIONS = [qw( components resources delegates )];


sub init {
    my ($self, $config) = @_;
    $self->init_hub($config);
}

sub init_hub {
    my ($self, $config) = @_;
    $self->init_config($config);
    $self->init_items($config);
    # $self->init_collections($config);     # init on demand
}

sub init_config {
    my ($self, $args) = @_;
    my $class = $self->class;

    # We're looking for a specific 'config' item which the user can provide to
    # points to a master configuration object or class name.  We default to the 
    # value in the $CONFIG package variable, which in this case is Badger::Config,
    # but could be re-defined by a subclass to be something else.

    my $config = delete($args->{ config }) 
        || $self->class->any_var('CONFIG')
        || { };

    my $module = delete($args->{ config_module })
        || $class->any_var('CONFIG_MODULE')
        || $self->CONFIG_MODULE;

    if (is_object($module, $config)) {
        # $config is already a config module object of the right heritage
        $self->debug("config is already a $module object") if DEBUG;
    }
    else {
        if (ref $config eq HASH) {
            # cool
        }
        elsif (! ref $config) {
            # $config is a module name
            $module = $config;
            $config = { };
        }
        else {
            return $self->error_msg( invalid => config => $config );
        }
        $self->debug("loading and instantiating a custom $module config object") if DEBUG;
        class($module)->load;
        $config = $module->new($config);
    }

    $self->{ config } = $config;
    $self->debug("hub config: $self->{ config }\n") if DEBUG;
}

sub init_items {
    my ($self, $args) = @_;

    # merge all values in $CONFIG_ITEMS in with $args->{ items };
    $args->{ items } = $self->class->list_vars( 
        CONFIG_ITEMS => delete($args->{ config_items }), $args->{ items }
    );

    $self->debug(
        "hub config items: ", 
        $self->dump_data($args->{ items })
    ) if DEBUG;

    return $self;
}

sub init_collections {
    my ($self, $config) = @_;
    $self->init_components($config);
    $self->init_resource($config);
    $self->init_delegates($config);
}

sub init_components {
    shift->init_collection( components => @_ );
}

sub init_resources {
    shift->init_collection( resources => @_ );
}

sub init_delegates {
    shift->init_collection( delegates => @_ );
}

sub init_collection {
    my ($self, $type) = @_;
    my $TYPE = uc $type;
    my $cfg  = $self->config($type);
    my $bits = $self->{ $type } = $self->class->hash_vars( 
        $TYPE => $self->config($type)
    );
    $self->debug("init_collection: $type: ", $self->dump_data($bits)) if DEBUG;
    return $bits;
}

sub configure {
    my ($self, $config) = self_params(@_);
    my $item;

    if ($item = delete $config->{ components }) {
        $self->components($item);
    }
    if ($item = delete $config->{ resources }) {
        $self->resources($item);
    }
    if ($item = delete $config->{ delegates }) {
        $self->delegates($item);
    }
}

#-----------------------------------------------------------------------------
# comment
#-----------------------------------------------------------------------------

sub components {
    my $self  = shift->prototype;
    my $comps = $self->{ components }
             || $self->init_components;

    if (@_) {
        my $args = ref $_[0] eq HASH ? shift : { @_ };
        @$comps{ keys %$args } = values %$args;
    }

    return $comps;
}


sub component {
    my $self  = shift;
    my $comps = $self->components;
    $self->debug("components: ", $self->dump_data($comps)) if DEBUG;
    return @_
        ? $comps->{ $_[0] }
        : $comps;
}


sub delegates {
    my $self  = shift->prototype;
    my $class = $self->class;
    my $delgs = $self->{ delegates }
             || $self->init_delegates;

    if (@_) {
        my $args = ref $_[0] eq HASH ? shift : { @_ };
        @$delgs{ keys %$args } = values %$args;
    }

    return $delgs;
}


sub delegate {
    my $self   = shift;
    my $delegs = $self->delegates;
    $self->debug("delegates: ", $self->dump_data($delegs)) if DEBUG;
    return @_
        ? $delegs->{ $_[0] }
        : $delegs;
}


sub auto_can {
    my ($self, $name) = @_;
    my $target;

    if ($target = $self->component($name)) {
        $self->debug("creating component method in $self for $name")  if DEBUG;
        return $self->auto_component( $name => $target );
    }
    elsif ($target = $self->delegate($name)) {
        $self->debug("creating delegate method in $self for $name") if DEBUG;
        return $self->auto_delegate( $name => $target );
    }
    elsif (DEBUG) {
        $self->debug("no component or delegate found in $self for $name");
    }
        
    return undef;
}   


sub auto_component {
    my ($self, $name, $comp) = @_;
    my $class = ref $self || $self;

    $LOADED->{ $name } ||= class($comp)->load;

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


sub auto_delegate {
    my ($self, $name, $deleg) = @_;
    my $class = ref $self || $self;
    
    # foo => bar is mapped to $self->bar->foo
    # foo => [bar, baz] is mapped to $self->bar->baz
    my ($m1, $m2) = ref $deleg eq ARRAY ? @$deleg : ($deleg, $name);

    return $self->error("Cannot auto_delegate() a method to itself: $m1 -> $m2")
        if $m1 eq $m2;

    return sub {
        shift->$m1->$m2(@_);
    };
}



# Configure and create a sub-component identified by $name, using
# any configuration items in $params and any values defined locally
# in a configuration hash, object or class.
#
# The $self->{ config } can contain a hash array of configuration
# items, or it can be a Badger::Config object or the class name of a
# Badger::Config object.  We look in the hash, or call the object/class
# method to find $name (e.g. $hash->{ $name }, $object->$name, or
# $class->name()).  This is merged with $params.

sub construct {
    my $self   = shift;
    my $name   = shift;
    my $config = $self->config($name, @_);

    $self->debug("$name module config: ", $self->dump_data($config)) if DEBUG;
    
    # see if a module name is specified in $args, config hash or use $pkgmod
    my $module = $config->{ module }
        || return $self->error_msg( no_module => $name );

    # load the module
    class($module)->load;

    return $module->new($config);
}

sub config {
    my $self   = shift->prototype;
    my $config = $self->{ config };     return $config unless @_;
    my $name   = shift;
    my $params = params(@_);
    my $defaults;
    my $method;


    if ($config && ref $config eq HASH) {
        # $self->{ config } can be a hash ref with a $name item
        $defaults = $config->{ $name };
    }
    elsif (blessed $config && ($method = $config->can('get'))) {
        # $self->{ config } can be an object with a get($name) method which we call
        $self->debug("calling config->get($name)") if DEBUG;
        $defaults = $method->($config, $name);
    }
    elsif (blessed $config && ($method = $config->can($name))) {
        # $self->{ config } can be an object with a $name method which we call
        $self->debug("calling config->$name") if DEBUG;
        $defaults = $method->($config);
    }
    # no defaults
    return $self->no_config($name, $params)
        unless $defaults;

    $self->debug(
        "config for $name: DEFAULTS: ", 
        $self->dump_data($defaults),
        "\nPARAMS: ", $self->dump_data($params)
    ) if DEBUG;

    return {
        %$defaults,
        %$params
    };
}

sub no_config {
    my ($self, $name, $params) = @_;

    $self->debug(
        "no_config for $name: ", 
        "PARAMS: ", $self->dump_data($params)
    ) if DEBUG;

    # TODO: option to make this a failure
    return  $self->pkgvar_config($name, $params)
        ||  ($params ? { %$params } : { });
}

sub pkgvar_config {
    my ($self, $name, $params) = @_;
    my $pkgvar = $self->class->any_var(uc $name) || return $params;
    my $config;

    if (ref $pkgvar eq HASH) {
        # package variable can be a hash ref of config options
        $config = $pkgvar;
    }
    else {
        # or the name of a module
        $config = { 
            module => $pkgvar 
        };
    };

    return {
        %$config,
        %$params
    };
}



#------------------------------------------------------------------------
# destroy()
#
# Destroy the hub and cleanup any cache items we may have stored.
#------------------------------------------------------------------------

sub destroy {
    my $self = shift;

    # if called as a class method we cleanup any prototype object
    # stored as a singleton in the $PROTOTYPE package variable
    unless (ref $self) {
        no strict 'refs';
        my $class = $self;
        $self = ${"$class\::PROTOTYPE"} || return;
        $self->debug("deleting hub prototype from \$$class\::PROTOTYPE\n") if DEBUG;
        ${"$class\::PROTOTYPE"} = undef;
    }

    $self->debug("destroying hub: $self\n") if DEBUG;

    # empty content of $self to break any circular references that
    # we may have established with other items that point back to us
    %$self = ();
}


sub DESTROY {
    my $self = shift;
    $self->destroy;
}


1;
__END__

=encoding utf8

=head1 NAME

Badger::Hub - central repository of shared resources

=head1 SYNOPSIS

    use Badger::Hub;
    
    # do the happy badger dance!

=head1 INTRODUCTION

This documentation describes the C<Badger::Hub> object.  A hub sits in the 
middle of a L<Badger> application, providing a central point of access to 
the various other modules, components and sub-system that an application 
uses.

You generally don't need to worry about the C<Badger::Hub> if you're just
a casual user of the L<Badger> modules.  It will primarily be of interest
to developers who are building their own badger-powered applications or
extensions.

At present this module is quite basic. It will be developed further in due
course.

=head1 DESCRIPTION

A C<Badger::Hub> object is a central repository of shared resources for a
L<Badger> application. The hub sits in the middle of an application and
provides access to all the individual components and larger sub-systems 
that may be required.  It automatically loads and instantiates these other
modules on demand and caches then for subsequent use.

=head2 Components

The L<Badger::Hub> base class currently has two components:

    filesystem  =>  Badger::Filesystem
    codecs      =>  Badger::Codecs

An C<AUTOLOAD> method allows you to access any component by name.  It will
be loaded and instantiated automatically.  The C<AUTOLOAD> method also
generates the missing method so that you can avoid the overhead of the 
C<AUTOLOAD> method the next time you call it.

    my $filesystem = $hub->filesystem;

You can add your own component to a hub and they will be available in the
same way.

    $hub->components( fuzzbox => 'My::Module::Fuzzbox' );
    my $fuzzbox = $hub->fuzzbox;

=head2 Delegates

As well as accessing components directly, you can also make use of delegate
methods that get forwarded onto a component. For example, the hub C<file()>
method is just a short cut to the C<file()> method of the C<filesystem>
component (implemented by L<Badger::Filesystem>).

    $file = $hub->file('/path/to/file');                # the short cut
    $file = $hub->filesystem->file('/path/to/file');    # the long way

You can easily define your own delegate methods.

    $hub->delegates( warm_fuzz => 'fuzzbox' );
    $fuzzed = $hub->warm_fuzz;                          # the short way
    $fuzzed = $hub->fuzzbox->warm_fuzz;                 # the long way.

=head2 Subclassing Badger::Hub

You can subclass L<Badger::Hub> to define your own collection of components
and delegate methods, as shown in the example below.

    package My::Hub;
    
    use Badger::Class
        version   => 0.01,
        debug     => 0,
        base      => 'Badger::Hub';
    
    our $COMPONENTS = {
        fuzzbox => 'My::Module::Fuzzbox',
        flanger => 'My::Module::Flanger',
    };
    
    our $DELEGATES  = { 
        warm_fuzz   => 'fuzzbox',
        dirty_noise => 'fuzzbox',
        wide_flange => 'flanger',
        wet_flange  => 'flanger',
    };

=head2 Circular References are a Good Thing

In some cases, sub-systems instantiated by a L<Badger::Hub> will also 
maintain a reference back to the hub.  This allows them to access other
sub-systems and components that they require.

Note that this behaviour implicitly creates circular references between the
hub and its delegates. This is intentional. It ensures that the hub and
delegates keep each other alive until the hub is explicitly destroyed and the
references are freed. Having the hub stick around for as long as possible is
usually a Good Thing. It acts as a singleton providing a central point of
access to the resources that your application uses (which is a fancy way of
saying it's like a global variable).

    +-----+      +-----------+
    | HUB |----->| COMPONENT |
    |     |<-----|           |
    +-----+      +-----------+

If you manually create a hub for whatever reason (and the cases where you 
would need to are few and far between) then you are responsible for calling
the L<destroy()> method when you're done with it.  This will manually break
the circular references and free up any memory used by the hub and any 
delegates it is using.  If you don't call the L<destroy()> method then the 
hub will remain alive until the end of the program when the memory will be
freed as usual.  In most cases this is perfectly acceptable.

However, you generally don't need to worry about any of this because you
wouldn't normally create a hub manually. Instead, you would leave it up to the
L<Badger> façade (or I<"front-end">) module to do that behind the scenes. When
you create a L<Badger> module it implicitly creates a C<Badger::Hub> to use.
When the L<Badger> object goes out of scope its C<DESTROY> method
automatically calls the hub's L<destroy> method. 

    sub foo {
        my $badger = Badger->new;
        my $hub    = $badger->hub;
        # do something
        
        # $badger object is freed here, that calls $hub->destroy
    }

Because there is no reference from the hub back to the L<Badger> façade object
you don't have to worry about circular references.  The L<Badger> object is
correctly freed and that ensures the hub gets cleaned up.

    +--------+      +-----+      +-----------+
    | BADGER |----->| HUB |----->| COMPONENT |
    |        |      |     |<-----|           |
    +--------+      +-----+      +-----------+

If you call C<Badger> methods as class methods then they are forwarded to
a L<prototype|Badger::Prototype> object (effectively a singleton object).
That in turn will use a L<prototype|Badger::Prototype> hub object.  In this
case, both the C<Badger> and C<Badger::Hub> objects will exist until the 
end of the program.  This ensures that your class methods all I<Do the right
Thing> without you having to worry about creating a L<Badger> object.

    # class method creates Badger prototype, which creates Badger::Hub
    # prototype, which loads, instantiates and caches Badger::Filesystem 
    # which can then fetch the file
    my $file = Badger->file('/path/to/file');

    # later... reuse same Badger, Badger::Hub and Badger::Filesystem
    my $dir = Badger->dir('/path/to/dir');

=head1 METHODS

=head2 new() 

Constructor method used to create a new hub object.  

    $hub = Badger::Hub->new();

=head2 components()

This method can be used to get or set entries in the components table
for the hub.  Components are other modules that the hub can delegate to.

    # get components hash ref
    my $comps = $hub->components;
    
    # add new components
    $hub->components({
        fuzzbox => 'My::Module::Fuzzbox',
        flanger => 'My::Module::Flanger',
    });

=head2 component($name)

This method returns a single entry from the components table.

    print $hub->component('fuzzbox');   # My::Module::Fuzzbox

=head2 delegates()

This method can be used to get or set entries in the delegates table for
the hub.  This specifies which hub methods should be delegated to 
components.

    # get delegates hash ref
    my $delegs = $hub->delegates;
    
    # add new delegates
    $hub->delegates({
        warm_fuzz   => 'fuzzbox',
        dirty_noise => 'fuzzbox',
        wide_flange => 'flanger',
        wet_flange  => 'flanger',
    });

=head2 delegate($name)

This method returns a single entry from the delegates table.

    print $hub->delegate('warm_fuzz');  # fuzzbox

=head2 destroy()

This method can be manually called to destroy the hub and any components
that it is using.

=head1 INTERNAL METHODS

=head2 construct($component,\%params)

This method configures and instantiates a component. The first argument is the
component name. This is mapped to a module via the L<component()> method and
the module is loaded. A list of named parameters, or a reference to a hash
array of named paramters may follow. A reference to the hub is added to these
as the C<hub> item before forwarding them to the constructor method for the
component.  The component is then cached for subsequent use.

    # calling the construct() method like this...
    $hub->construct( fuzzbox => { volume => 11 } );

    # ...results in code equivalent to this:
    use Your::Module::Fuzzbox;
    Your::Module::Fuzzbox->new({ volume => 11, hub => $hub });

=head2 auto_can($name)

This method is installed as an L<auto_can|Badger::Class/auto_can> handler
which is called to resolved undefined methods.  If the method called matches
the name of a component then it calls L<auto_component()> to generate a 
method to access the component.  If it matches the name of a delegate method
then it calls L<auto_delegate()> to generate a delegate method.

=head2 auto_component($name,$module)

This method generates a component method named C<$name> which accesses an
instance of the C<$module> component module.

=head2 auto_delegate($name,$component)

This method generates a delegate method named C<$name> which delegates to
the C<$name> method of the C<$component> component.

=head2 config()

This method returns a reference to a L<Badger::Config> object representing
the configuration for the hub.  This is still marked experimental.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2009 Andy Wardley.  All Rights Reserved.

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
