#========================================================================
#
# Badger::Config
#
# DESCRIPTION
#   A central configuration module.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Config;

use Badger::Class
    version   => 0.01,
    debug     => { default => 0, import => ':dump' },
    import    => 'class',
    base      => 'Badger::Prototype',
    utils     => 'blessed numlike',
    constants => 'HASH ARRAY CODE DELIMITER',
    messages  => {
        get => 'Cannot fetch configuration item <1>.<2> (<1> is <3>)',
    };

our $AUTOLOAD;

sub init {
    my ($self, $config) = @_;
    my $data = $self->{ data } = $config->{ data } || $config;
    
    # merge all $ITEMS in package variables with those listed in 
    # $config->{ items } and all other $config keys.
    my $items = $self->class->list_vars( 
        ITEMS => delete($config->{ items }), keys %$data
    );
    
    # store hash lookup table marking valid items
    $self->{ item } = {
        map { $_ => 1 } 
        map { split DELIMITER } 
        @$items 
    };
    
    if (DEBUG) {
        $self->debug("config items: ", $self->dump_data($self->{ items }));
        $self->debug("config data: ", $self->dump_data($self->{ data }));
    }

    return $self;
}

sub get {
    my $self  = shift;
    my @names = map { ref $_ eq ARRAY ? @$_ : split /\W+/ } @_;
    my $name  = shift @names;
    my $data  = $self->{ data }->{ $name };
    my ($last, $method);

    $self->debug("get: ", join(' / ', @names)) if DEBUG;
    
    while (defined $data && @names) {
        $data = $data->() if ref $data eq CODE;
        $name = shift @names;
        if (ref $data eq HASH) {
            $data = $data->{ $name };
        }
        elsif (ref $data eq ARRAY && numlike $name) {
            $data = $data->[$name];
        }
        elsif (blessed $data && (my $method = $data->can($name))) {
            $data = $method->($data);
        }
        else {
            return $self->error_msg(
                get => $last, $name, ref $last || 'text'
            );
        }
    }
    
    return $data;
}

sub set {
    my $self = shift;
    my $name = shift;
    my $data = @_ == 1 ? shift : { @_ };
    $self->{ data }->{ $name } = $data;
    $self->{ item }->{ $name } = 1;
    return $data;
}

sub can {
    my ($self, $name) = @_;
    return $self->SUPER::can($name)
        || $self->{ item }->{ $name }
        && $self->generate_config_method($name);
}

sub generate_config_method {
    my ($self, $name) = @_;
    my $method = sub {
        return @_ > 1
            ? shift->set( $name => @_ )     # set
            : $self->{ data }->{ $name };   # get
    };
    $self->class->method( $name => $method );
    return $method;
}

sub AUTOLOAD {
    my $self = shift;
    my ($name) = ($AUTOLOAD =~ /([^:]+)$/ );
    return if $name eq 'DESTROY';
    $self = $self->prototype unless ref $self;

    $self->debug("AUTOLOAD: $name in ", $self->dump_data($self->{ data })) if DEBUG;
    
    # generate method on demand for valid items, then call it
    return $self->{ item }->{ $name }
        ? $self->generate_config_method($name)->($self, @_)
        : $self->error_msg( bad_method => $name, ref $self, (caller())[1,2] );
}



#------------------------------------------------------------------------
# generate_config_methods()
#
# Generate an accessor method for each of the items passed as arguments
#------------------------------------------------------------------------

sub _OLD_generate_config_methods {
    my $class   = shift;
    my $methods = shift; # || $class->pkgvar('METHODS');
    $class = ref $class || $class;

    # engage cloaking shield to protect us from Perl's beady eyes and nagging tongue
    no strict 'refs';

    foreach my $method (@$methods) {
        $class->debug("Generating method: $method()\n") if $DEBUG;

        *{"${class}::$method"} = sub {
            my $self = shift;
            # look for the item in the $self->{ config } or an UPPER CASE package variable.
            my $item = ref $self ? $self->{ config }->{ $method } : $self->pkgvar(uc $method);

            # return any value that isn't a hash ref
            return $item unless ref $item eq 'HASH';
            
            if (@_) {
                # if we have any arguments then merge them with the default
                # values in the $item hash and return a new composite set
                my $config = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };
                return { 
                    %$item,
                    %$config,
                };
            }
            else {
                # otherwise return a copy of the defaults
                return { %$item };
            }
        } unless defined &{"${class}::$method"};
    }
}
1;
__END__

=head1 NAME

Badger::Config - configuration module

=head1 SYNOPSIS

    use Badger::Config;
    
    my $config = Badger::Config->new(
        user => {
            name => {
                given  => 'Arthur',
                family => 'Dent',
            },
            email => [
                'arthur@dent.org',
                'dent@heart-of-gold.com',
            ],
        },
        planet => {
            name        => 'Earth',
            description => 'Mostly Harmless',
        },
    );
    
    # fetch top-level data item - these both do the same thing
    my $user = $config->user;                       # shortcut method
    my $user = $config->get('user');                # generic get() method
    
    # fetch nested data item - these all do the same thing
    print $config->get('user', 'name', 'given');    # Arthur
    print $config->get('user.name.family');         # Dent
    print $config->get('user/email/0');             # arthur@dent.org
    print $config->get('user email 1');             # dent@heart-of-gold.com

=head1 DESCRIPTION

This is a quick hack to implement a placeholder for the L<Badger::Config>
module.  A config object is currently little more than a blessed hash with
an AUTOLOAD method which allows you to get/set items via methods.

Update: this has been improved a little since the above was written.  It's
still incomplete, but it's being worked on.

=head1 METHODS

=head2 new()

Constructor method to create a new L<Badger::Config> object.  Configuration 
data can be specified as the C<data> named parameter:

    my $config = Badger::Config->new(
        data => {
            name  => 'Arthur Dent',
            email => 'arthur@dent.org',
        },
    );

The C<items> parameter can be used to specify the names of other 
valid configuration values that this object supports.

    my $config = Badger::Config->new(
        data => {
            name  => 'Arthur Dent',
            email => 'arthur@dent.org',
        },
        items => 'planet friends',
    );

Any data items defined in either C<data> or C<items> can be accessed via
methods.

    print $config->name;                # Arthur Dent
    print $config->email;               # arthur@dent.org
    print $config->planet || 'Earth';   # Earth

As a shortcut you can also specify configuration data direct to the method.

    my $config = Badger::Config->new(
        name  => 'Arthur Dent',
        email => 'arthur@dent.org',
    );

You should avoid this usage if there is any possibility that your
configuration data might contain the C<data> or C<items> items.

=head2 get($name)

Method to retrieve a value from the configuration.

    my $name = $config->get('name');

This can also be used to fetch nested data.  You can specify each element
as a separate argument, or as a string delimited with any non-word characters.
For example, given the following configuration data:

    my $config = Badger::Config->new(
        user => {
            name => {
                given  => 'Arthur',
                family => 'Dent',
            },
            email => [
                'arthur@dent.org',
                'dent@heart-of-gold.com',
            ],
        },
    );

You can then access data items using any of the following syntax:

    print $config->get('user', 'name', 'given');    # Arthur
    print $config->get('user.name.family');         # Dent
    print $config->get('user/email/0');             # arthur@dent.org
    print $config->get('user email 1');             # dent@heart-of-gold.com

In addition to accessing list and hash array items, the C<get()> will call
subroutine references and object methods, as shown in this somewhat contrived
example:

    # a trivial object class
    package Example;
    use base 'Badger::Base';
    
    sub wibble {
        return 'wobble';
    }
    
    package main;

    # a config with a function that returns a hash containing an object
    my $config = Badger::Config->new(
        function => sub {
            return {
                object => Example->new(),
            }
        }
    );
    print $config->get('function.object.wibble');   # wobble

=head2 set($name,$value)

Method to store a value in the configuration.  

    $config->set( friend  => 'Ford Prefect' );
    $config->set( friends => ['Ford Prefect','Trillian','Marvin'] );

At present this does I<not> allow you to set nested data items in the way that
the L<get()> method does.

=head2 can($name)

Replacement for the C<can()> method that would otherwise be inherited from
C<UNIVERSAL>. If the named method doesn't exist and is one of the known
configuration items for this object then it calls L<generate_config_method()>
to automatically generate an accessor method. A C<CODE> reference to this
method is then returned.

=head1 INTERNAL METHODS

=head2 AUTOLOAD

The C<AUTOLOAD> method automatically generates a method on demand for any
valid configuration items.

=head2 generate_config_method($name)

Internal method used to generate accessor methods on demand.

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
