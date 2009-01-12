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
        VALUE         => 1,
        NOTHING       => 0,
    },
    messages => {
        bad_type   => 'Invalid type prefix specified for %s: %s',
        bad_method => 'Missing method for the %s %s configuration item: %s',
    };


sub export {
    my $class  = shift;
    my $target = shift;
    my $params = @_ == 1 ? shift : { @_ };
    $class->debug("export to $target: ", join(', ', @_)) if DEBUG;
    my $schema = $class->schema($params);
    
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
    my $config = @_ == 1 ? (ref $_[0] eq ARRAY ? [@{$_[0]}] : shift) : [ @_ ];
    my ($name, $info, @aka, $fallback, $test, @schema);

    $class->debug("Generating schema from config: ", $class->dump_data($config))
        if DEBUG;
    
    $config = [ split(DELIMITER, $config) ]
        unless ref $config;
    
    $config = [ 
        map { 
            my $k = $_;
            my $v = $config->{ $k };
            ref $v eq HASH
                ? { name => $k, %$v } 
                : { name => $k, default => $v }
        } keys %$config
    ] if ref $config eq HASH;

#    $config = { 
#        map { 
#            ref($_) eq HASH 
#                ? ($_->{ name } => $_)
#                : ($_           => { })
#        } @$config 
#    } if ref $config eq ARRAY;

    $class->debug("Canonical config: ", $class->dump_data($config))
        if DEBUG;
        
#    while (($name, $info) = each %$config) {
    while (@$config) {
        $name = shift @$config;
        $class->debug("config item: $name\n") if DEBUG;
        if (ref $name eq HASH) {
            $info = $name;
            $name = $info->{ name };
        }
        else {
            $info = { };
        }
        $class->debug("name: $name   info: $info") if DEBUG;
#        if (ref $info eq HASH) {
#            # ok
#        }
#        else {
#            $info = { default => $info };
#        }
        
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
    my ($self, $config, $target) = @_;
    my $class  = class($self);
    my $schema = $class->list_vars(CONFIG);
    my ($element, $name, $alias, $code, @args, $ok, $value);
    
    # if a specific $target isn't defined then we default to updating $self
    $target ||= $self;

    $self->debug("configure(", CLASS->dump_data_inline($config), ')') if DEBUG;
    $self->debug("schema: ", CLASS->dump_data($schema)) if DEBUG;
    
    ELEMENT: foreach $element (@$schema) {
        $name = $element->{ name };
        
        FALLBACK: foreach $alias ($name, @{ $element->{ fallback } }) {
            if (ref $alias) {
                $self->debug("Dispatching handler to set $name\n") if DEBUG;
                ($code, @args) = @$alias;
                ($ok, $value) = $code->($self, $class, $name, $config, $target, @args);
                if ($ok) {
                    $target->{ $name } = $value;
                    next ELEMENT;
                }
            }
            elsif (defined $config->{ $alias }) {
                $self->debug("Looking for $alias in config to set $name\n") if DEBUG;
                $target->{ $name } = $config->{ $alias };
                next ELEMENT;
            }
            else {
                $self->debug("Nothing found for $alias to set $name\n") if DEBUG;
            }
        }
        
        if (exists $element->{ default }) {
            $target->{ $name } = $element->{ default };
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
    my ($self, $class, $name, $config, $target, $var) = @_;
    my $value = $class->var($var);

    $self->debug(
        "Looking for \$$var package variable in $class to set $name: ", 
        defined $value ? $value : '<undef>'
    ) if DEBUG;

    return defined $value
        ? (VALUE => $value)
        : (NOTHING);
}

sub configure_class {
    my ($self, $class, $name, $config, $target, $var) = @_;
    my $value = $class->any_var_in( split(':', $var) );

    $self->debug(
        "Looking for \$$var class variable in $class to set $name: ", 
        defined $value ? $value : '<undef>'
    ) if DEBUG;

    return defined $value
        ? (VALUE => $value)
        : (NOTHING);
}

sub configure_env {
    my ($self, $class, $name, $config, $target, $var) = @_;
    my $value = $ENV{ $var };

    $self->debug(
        "Looking for $var environment variable to set $name: ",
        defined $value ? $value : '<undef>'
    ) if DEBUG;

    return defined $value
        ? (VALUE => $value)
        : (NOTHING);
}

sub configure_method {
    my ($self, $class, $name, $config, $target, $method) = @_;

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

    return defined $value
        ? (VALUE => $value)
        : (NOTHING);
}

sub configure_target {
    my ($self, $class, $name, $config, $target, $var) = @_;

    my $value = $target->{ $var };
    
    $self->debug(
        "Looking for $var in $class target $target to set $name: ", 
        defined $value ? $value : '<undef>'
    ) if DEBUG;

    return defined $value
        ? (VALUE => $value)
        : (NOTHING);
}



1;

__END__

=head1 NAME

Badger::Class::Config - class mixin for configuration

=head1 SYNOPSIS

    package Your::Module;
    
    # via Badger::Class
    use Badger::Class
        base      => 'Badger::Base',
        accessors => 'foo bar baz wig woot toot zoot zang',
        config    => [
            'foo',                      # optional item
            'bar!',                     # mandatory item
            'baz=42',                   # item with default
            'wig|wam|bam',              # item with aliases
            'woot|pkg:WOOT',            # fallback to $WOOT pkg var
            'toot|class:WOOT',          # fallback to $WOOT class var
            'zoot|method:ZOOT',         # fallback to ZOOT() method/constant
            'zing|zang|pkg:ZING=99',    # combination of above
        ];
    
    sub init {
        my ($self, $config) = @_;
        
        # call the configure() method provided by the above
        $self->configure($config);
        
        return $self;
    }

=head1 DESCRIPTION

This class mixin module allows you to define configuration parameters
for an object class.  It exports a L<configure()> method which can be used
to initialise your object instances.

Please note that the scope of this module is intentionally limited at present. 
It should be considered experimental and subject to change.

=head2 Configuration Options

Configuration options for a module can be defined as import options to 
C<Badger::Class::Config>.

    package Your::Module;
    use base 'Badger::Base';
    use Badger::Class::Config 'foo', 'bar';

For convenience, multiple items can be specified in a single whitespace 
delimited string.

    use Badger::Class::Config 'foo bar';

More complex configurations can be specified using list and hash references,
but we'll keep things simple for now.

Using the module as shown here has two immediate effects.  The first is that
the C<$CONFIG> package variable will be defined in C<Your::Module> containing
a reference to the configuration schema for your module.  This schema contains
information about the configuration items which in this example are C<foo>
and C<bar>.  The second effect is to define a L<configure()> method which 
uses this schema to configure your object using the configuration options 
passed to the constructor method.  You can call this method from your 
L<init()|Badger::Base/init()> method (if you're using L<Badger::Base>)
or from your own construction or initialisation methods.

    sub init {
        my ($self, $config) = @_;
        $self->configure($config);
        return $self;
    }

The L<configure()> method is intentionally simple, although flexible.  It
doesn't attempt to assert that any configuration items are of the correct 
type or validate the values in any way.  If the relevant values are defined
in the C<$config> hash then they will be copied into C<$self>.  Otherwise
they are ignored.

If a configuration item is mandatory then add a C<!> at the end of the name.
If no value is defined for this item then the L<configure()> method will 
throw an exception.

    use Badger::Class::Config 'foo! bar!';      # mandatory items

A default value can be provided using C<=>;

    use Badger::Class::Config 'foo=10 bar=20';  # default values

Aliases for the configuration item can be provided using C<|>

    use Badger::Class::Config 'foo|Foo|FOO';    # aliases for 'foo'

As well as looking for items in the C<$config> hash array, you can search
for package variables (in the current package), class variables (in the 
current package or those of all base class), environment variables, and
call object methods.

    use Badger::Class::Config
        'foo|pkg:FOO',                  # fallback to $FOO package var
        'bar|class:BAR',                # fallback to $BAR class var
        'baz|env:BAZ',                  # fallback to $BAZ environment var
        'bam|method:BAM';               # fallback to BAM() method
        'wam|target:slam';              # fallback to $target->{ slam }

Bear in mind that Perl implements constants using subroutines.  Thus, you
can access a constant defined in a package/class by calling it as a
method.  So if you have a constant defined in the module that you want
to use then specify it using the C<method:> prefix. 

TODO: more on that

=head2 Detailed Specification

The syntax for defining configuration options described above is a short-cut
to the more detailed specification used to generate a configuration scheme for
the L<configure()> method to use.  You can use the more detailed specification
if you prefer:

    use Badger::Class::Config 
        {
            foo => {
                required => 1,
                default  => 10,
                fallback => ['class:FOO', 'env:FOO'],
            },
            bar => {
                required => 1,
                default  => 20,
                fallback => ['class:BAR', 'env:BAR'],
            },
            
        };

You can mix and match simple and detailed specifications by specifying them as
items in a list reference. Each configuration option should be defined as a
separate item (i.e. you can't merge multiple items into a single whitespace
delimited string). Simple definitions are specified using strings, complex
definitions using hash reference.  Note that the name of the option must
be specified explicitly in the hash array when used this way.

    use Badger::Class::Config 
        [
            'foo|class:FOO!',
            {
                name     => 'bar',
                required => 1,
                default  => 20,
                fallback => ['class:BAR', 'env:BAR'],
            },
            
        ];

=head2 Badger::Class Hook

The L<Badger::Class> module implements a L<config|Badger::Class/config> hook
which interfaces to this module.  You can specify a single string to define
multiple configuration items in one go:

    use Badger::Class
        base   => 'Badger::Base',
        config => 'foo! bar=10 baz|class:BAZ=20';

Or a reference to a hash array or list containing individually defined
configuration items.

    use Badger::Class
        base   => 'Badger::Base',
        config => [
            'foo!',
            'bar=10',
            'baz|class:BAZ=20'
        ];

=head1 METHODS

=head2 schema()

This method is used internally to define a configuration schema.  It exports
it as the C<$CONFIG> package variable into the calling module.

=head2 configure($config,$target)

This method is exported the calling module to perform the configuration
process. It used the configuration schema stored in the C<$CONFIG> package
variable by the L<schema()> method.  It is typically called from a
construction or initialisation method.

The first argument should be a reference to a hash array of configuration
options.  The second should be a reference to a hash array or hash-based
object into which the configuration values can be copied.  If this is not
specified then the method defaults to updating the C<$self> object reference
passed as the first implicit argument.

    sub init {
        my ($self, $config) = @_;
        $self->configure($config);
        return $self;
    }

=head2 configure_pkg()

This method is used internally to look up package variables for configuration
options.

=head2 configure_class()

This method is used internally to look up class variables for configuration
options.  Class variables are package variables in the current package or
those of any of its base classes.

=head2 configure_env()

This method is used internally to look up environment variables for 
configuration options.

=head2 configure_method()

This method is used internally to call object methods to return default
configuration values.

=head2 configure_target()

This method is used internally to look inside the target object or hash array
to return default configuration values.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008-2009 Andy Wardley.  All Rights Reserved.

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
