#========================================================================
#
# Badger::Class::Config
#
# DESCRIPTION
#   Class mixin module for adding code onto a class for configuration.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Class::Config;

use Carp;
use Badger::Debug ':dump';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Exporter Badger::Base',
    import    => 'class CLASS',
    words     => 'CONFIG',
    constants => 'HASH ARRAY DELIMITER',
    constant  => {
        CONFIG_METHOD => 'configure',
    },
    messages => {
        bad_type   => 'Invalid type prefix specified for %s: %s',
        bad_method => 'Missing method for the %s %s configuration item: %s',
    };


sub export {
    my $class  = shift;
    my $target = shift;
    my $schema = $class->schema(@_);
    
    $class->export_symbol(
        $target,
        CONFIG,
        \$schema
    );
    
    $class->export_symbol(
        $target, 
        CONFIG_METHOD, 
        $class->can(CONFIG_METHOD)    # subclass might redefine method
    );
}


sub schema {
    my $class  = shift;
    my $config = @_ == 1 ? shift : { @_ };
    my ($name, $info, @aka, $fallback, $test, @schema);

    $class->debug("Generating schema from config: ", $class->dump_data($config))
        if DEBUG;
    
    $config = [ split(DELIMITER, $config) ]
        unless ref $config;
        
    $config = { map { $_ => { } } @$config } 
        if ref $config eq ARRAY;

    $class->debug("Canonical config: ", $class->dump_data($config))
        if DEBUG;

        
    while (($name, $info) = each %$config) {
        if (ref $info eq HASH) {
            # ok
        }
        else {
            $info = { default => $info };
        }
        
        $info->{ required } = 1 
            if $name =~ s/!$//;
            
        $info->{ default } = $1
            if $name =~ s/=(\S+)$//;

        # name can be 'name|alias1|alias2|...'
        ($name, @aka) = split(/\|/, $name);
        
        # $info is now a hash ref
        $info->{ name } = $name
            unless defined $info->{ name };

        # aliases can be specified as a list ref or string which we split
        $fallback = $info->{ fallback } || [];
        $fallback = [ split(DELIMITER, $fallback) ]
            unless ref $fallback eq ARRAY;
        push(@$fallback, @aka);

        foreach my $item (@$fallback) {
            next unless $item =~ /:/;
            my ($type, $data) = split(/:/, $item, 2);
            my $code = $class->can('configure_' . $type)
                || return $class->error_msg( bad_type => $name, $type );
            $item = [ $code, $data ];
        }
        
        # add any aliases specified as part of the name and bind them 
        # back into the field info hash
        $info->{ fallback } = $fallback;

        $class->debug("Adding config schema element for $name: ", $class->dump_data($info)) if DEBUG;

        push(@schema, $info);
    }

#    $class->debug('schema: ', $class->dump_data_inline(\@schema)) if DEBUG;
    
    return \@schema;
}
    

#-----------------------------------------------------------------------
# this method is mixed into the target module
#-----------------------------------------------------------------------

sub configure {
    my ($self, $config) = @_;
    my $class  = class($self);
    my $schema = $class->list_vars(CONFIG);
    my ($element, $name, $alias, $value);

    $self->debug("configure(", CLASS->dump_data_inline($config), ')') if DEBUG;
    $self->debug("schema: ", CLASS->dump_data($schema)) if DEBUG;
    
    ELEMENT: foreach $element (@$schema) {
        $name = $element->{ name };
        
        FALLBACK: foreach $alias ($name, @{ $element->{ fallback } }) {
            if (ref $alias) {
                $self->debug("Dispatching handler to set $name\n") if DEBUG;
                my ($code, @args) = @$alias;
                next ELEMENT
                    if $code->($self, $class, $name, $config, @args);
            }
            elsif (defined $config->{ $alias }) {
                $self->debug("Looking for $alias in config to set $name\n") if DEBUG;
                $self->{ $name } = $config->{ $alias };
                next ELEMENT;
            }
            else {
                $self->debug("Nothing found for $alias to set $name\n") if DEBUG;
            }
        }
        
        if (exists $element->{ default }) {
            $self->{ $name } = $element->{ default };
            next ELEMENT;
        }
        
        if ($element->{ required }) {
            return $self->error_msg( $element->{ error } || missing => $name );
        }
    }
    
    return $self;
}


#-----------------------------------------------------------------------
# These handlers implement the various fallback types for providing 
# configuration data.  The schema() method maps fallacks specified as
# 'pkg:FOO' and 'class:BAR', for example, to the configure_pkg() and 
# configure_class() handlers, passing the token following the colon as 
# an argument.  They are called as code refs, but the object they're 
# configuring is passed as the first argument, $self. So they look
# like object methods, but they're not exported into the object's 
# namespace.
#-----------------------------------------------------------------------
    
sub configure_pkg {
    my ($self, $class, $name, $config, $var) = @_;
    my $value = $class->var($var);

    $self->debug(
        "Looking for \$$var package variable in $class to set $name: ", 
        defined $value ? $value : '<undef>'
    ) if DEBUG;

    if (defined $value) {
        $self->{ $name } = $value;
        return 1;
    }
    return 0;
}


sub configure_class {
    my ($self, $class, $name, $config, $var) = @_;
    my $value = $class->any_var($var);

    $self->debug(
        "Looking for \$$var class variable in $class to set $name: ", 
        defined $value ? $value : '<undef>'
    ) if DEBUG;

    if (defined $value) {
        $self->{ $name } = $value;
        return 1;
    }
    return 0;
}


sub configure_env {
    my ($self, $class, $name, $config, $var) = @_;
    my $value = $ENV{ $var };

    $self->debug(
        "Looking for $var environment variable to set $name: ",
        defined $value ? $value : '<undef>'
    ) if DEBUG;

    if (defined $value) {
        $self->{ $name } = $value;
        return 1;
    }
    return 0;
}

sub configure_method {
    my ($self, $class, $name, $config, $method) = @_;

    # see if the object has the required method - note we must call 
    # error_msg against CLASS (Badger::Class::Config) to use the 'bad_method'
    # message defined above.
    my $code = $self->can($method)
        || return CLASS->error_msg( bad_method => $class, $name, $method );

    # call the code and do the usual shuffle
    my $value = $code->($self);

    $self->debug(
        "Called $method() method to set $name: ",
        defined $value ? $value : '<undef>'
    ) if DEBUG;

    if (defined $value) {
        $self->{ $name } = $value;
        return 1;
    }
    return 0;
}


1;

__END__

=head1 NAME

Badger::Class::Config - class mixin for configuration

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

This class mixin module allows you to define configuration 
parameters.

It is still experimental and subject to change.

=head1 METHODS

See L<Badger::Class> for further details.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
