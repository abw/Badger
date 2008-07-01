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

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Prototype',
    utils     => 'UTILS',
    constants => 'HASH ARRAY REFS PKG',
    words     => 'COMPONENTS DELEGATES COMP_CACHE DELG_CACHE',
    messages => {
        no_module => 'No %s module defined.',
    };

use Badger::Config;
our $CONFIG     = 'Badger::Config';
our $COMPONENTS = {
    codecs     => 'Badger::Codecs',
    filesystem => 'Badger::Filesystem',
};
our $DELEGATES  = { 
    file      => 'filesystem',      # hub->file ==> hub->filesystem->file
    directory => 'filesystem',
    dir       => 'filesystem',
    codec     => 'codecs',
};
our $LOADED     = { };
our $AUTOLOAD;


sub init {
    my ($self, $args) = @_;
    # We're looking for a specific 'config' item which the user can provide to
    # points to a master configuration object or class name.  We default to the 
    # value in the $CONFIG package variable, which in this case is Badger::Config,
    # but could be re-defined by a subclass to be something else.
    my $config = delete($args->{ config }) || $self->class->any_var('CONFIG');
    $config = $config->new($args) unless blessed $config;
    $self->{ config } = $config;
    $self->debug("hub config: $self->{ config }\n") if $DEBUG;
    return $self;
}

sub config {
    my $self = shift;
    $self = $self->prototype(@_) unless ref $self;
    return $self->{ config };
}

sub components {
    my $self  = shift;
    my $class = $self->class;
    my $comps = $class->var(COMP_CACHE) 
             || $class->var(COMP_CACHE => $class->hash_vars(COMPONENTS));
    if (@_) {
        my $args = ref $_[0] eq HASH ? shift : { @_ };
        @$comps{ keys %$args } = values %$args;
    }
    return $comps;
}

sub component {
    my $self = shift;
    my $name = shift;
    $self->components->{ $name };
}

sub delegates {
    my $self  = shift;
    my $class = $self->class;
    my $delgs = $class->var(DELG_CACHE) 
             || $class->var(DELG_CACHE => $class->hash_vars(DELEGATES));
    if (@_) {
        my $args = ref $_[0] eq HASH ? shift : { @_ };
        @$delgs{ keys %$args } = values %$args;
    }
    return $delgs;
}

sub delegate {
    my ($self, $name) = @_;
    $self->delegates->{ $name };
}

sub generate_component_method {
    my ($self, $name, $comp) = @_;
    my $class = ref $self || $self;
    no strict REFS;

    $LOADED->{ $name } ||= UTILS->load_module($comp);

    unless (defined &{$class.PKG.$name}) {
        $class->debug("generating $name() in $class\n") if $DEBUG;
        *{$class.PKG.$name} = sub {
            my $self = shift;
            my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
            $self = $self->prototype() unless ref $self;
            return $self->{ $name } 
                ||= $self->configure( $name => { 
                    # TODO: figure out what's going on here in terms of
                    # possible combinations of configuration options
                    %$args, 
                    hub    => $self, 
                    module => $comp } 
                );
        };
    }
}

sub generate_delegate_method {
    my ($self, $name, $deleg) = @_;
    my $class = ref $self || $self;
    no strict REFS;
    
    # foo => bar is mapped to $self->bar->foo
    # foo => [bar, baz] is mapped to $self->bar->baz
    my ($m1, $m2) = ref $deleg eq ARRAY ? @$deleg : ($deleg, $name);

    unless (defined &{$class.PKG.$name}) {
        $class->debug("generating $name() in $class\n") if $DEBUG;
        *{$class.PKG.$name} = sub {
            shift->$m1->$m2(@_);
        };
    }
}

sub AUTOLOAD {
    my ($self, @args) = @_;
    my ($name) = ($AUTOLOAD =~ /([^:]+)$/ );
    return if $name eq 'DESTROY';
    my ($comp, $deleg);
    
    $self->debug("AUTOLOAD $name\n") if $DEBUG;

    # upgrade class methods to calls on prototype
    $self = $self->prototype unless ref $self;
    
    if ($comp = $self->component($name)) {
        $self->debug("Found component: $name\n") if $DEBUG;
        $self->generate_component_method($name => $comp);
        $self->debug("Calling $self->$name(", join(',', @args), ")\n") if $DEBUG;
        return $self->$name(@args);
    }
    elsif ($deleg = $self->delegate($name)) {
        $self->debug("Found delegate: $name\n") if $DEBUG;
        $self->generate_delegate_method($name => $deleg);
        $self->debug("Calling $self->$name(", join(',', @args), ")\n") if $DEBUG;
        return $self->$name(@args);
    }

    return $self->error_msg( bad_method => $name, ref $self, (caller())[1,2] );
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

sub configure {
    my $self = shift;
    my $name = shift;
    my $args = @_ && ref($_[0]) eq 'HASH' ? shift : { @_ };

    $self->debug("configure()\n") if $DEBUG;
    
    # $NAME pkg var can be a module name or hash ref with 'module' item
    my $pkgvar = $self->class->any_var(uc $name);
    my $pkgmod = ref $pkgvar eq 'HASH' ? $pkgvar->{ module } : $pkgvar;
    my $config = $self->{ config };
    my $method;

    if ($config && ref $config eq 'HASH') {
        # $self->{ config } can be a hash ref with a $name item
        $config = $config->{ $name };
    }
    elsif ($config && ($method = UNIVERSAL::can($self->{ config }, $name))) {
        # $self->{ config } can be an object with a $name method which we call
        $config = $method->($config);
    }
    else {
        # no local config data so we'll fall back on a package variable
        $config = $pkgvar;
    }

    # if $config isn't a hash then it's the name of the module to use
    $config = { module => $config } unless ref $config eq 'HASH';

    # see if a module name is specified in $args, config hash or use $pkgmod
    my $module = $args->{ module } ||= $config->{ module } ||= $pkgmod
        || return $self->error_msg( no_module => $name );

    # load the module
    UTILS->load_module($module);

    # add any extra arguments to the config hash
    $config = { %$config, %$args } if %$args;

    return $module->new($config);
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
        $self->debug("deleting hub prototype from \$$class\::PROTOTYPE\n") if $DEBUG;
        ${"$class\::PROTOTYPE"} = undef;
    }

    $self->debug("destroying hub: $self\n") if $DEBUG;

    # empty content of $self to break any circular references that
    # we may have established with other items that point back to us
    %$self = ();
}

sub DESTROY {
    my $self = shift;
    $self->destroy();
}


1;
__END__

=head1 NAME

Badger::Hub - central repository of shared resources

=head1 SYNOPSIS

    use Badger::Hub;
    # do the happy badger dance!

=head1 DESCRIPTION

A C<Badger::Hub> object is a base class object which can be used as the
central repository of shared resources for a L<Badger> application. It is
designed to be subclassed for practical use.

=head1 METHODS

=head1 new() 

Constructor method used to create a new hub object.  

    $hub = Badger::Hub->new();

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2001-2008 Andy Wardley.  All Rights Reserved.

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
