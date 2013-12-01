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

use Badger::Debug ':dump debugf';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    base      => 'Badger::Prototype',
    utils     => 'blessed numlike is_object',
    constants => 'HASH ARRAY CODE DELIMITER',
    auto_can  => 'can_configure',
    constant  => {
        METADATA_OBJECT => 'Badger::Config::Metadata',
    },
    alias     => {
        init  => \&init_config,
    },
    messages  => {
        get       => 'Cannot fetch configuration item <1>.<2> (<1> is <3>)',
        no_config => 'No configuration data found for %s',
    };


sub init_config {
    my ($self, $config) = @_;
    my $data  = $self->{ data } = $config->{ data } || { %$config };
    my $class = $self->class;
    
    # merge all $ITEMS in package variables with those listed in 
    # $config->{ items } and all other $config keys.
    my $items = $self->class->list_vars( 
        ITEMS => delete($config->{ items }), keys %$data
    );
    
    # store hash lookup table marking valid items
    $items = $self->{ item } = {
        map { $_ => 1 } 
        keys %$data,
        map { split DELIMITER } 
        @$items 
    };

    # load up all the configuration items from package variables
    #
    # TODO: We need different init rules here with fallbacks.  This should
    # be merged in with the code in Badger::Class::Config, or rather B:C:C
    # should define a config schema.
    foreach my $item (keys %$items) {
        next if exists $data->{ $item };
        $data->{ $item } = $config->{ $item }
            || $class->any_var( uc $item );
        $self->debug("config set $item => ", $data->{ $item }, "\n") if DEBUG;
    }
    
    if (DEBUG) {
        $self->debug("config items: ", $self->dump_data($self->{ item }));
        $self->debug("config data: ", $self->dump_data($self->{ data }));
    }

    return $self;
}


sub get {
    my $self  = shift->prototype;
    my @names = map { ref $_ eq ARRAY ? @$_ : split /\./ } @_;
    my $name  = shift @names;

    $self->debug(
        "get: [", 
        join('].[', $name, @names),
        "]"
    ) if DEBUG;
    
    # fetch the head item
    my $data = $self->head($name) 
        ||  return $self->decline_msg( 
                no_config => $name
            );

    return @names
        ? $self->dot($name, $data, \@names)
        : $data;
}

sub dot {
    my ($self, $name, $data, $dots) = @_;
    my @done = ($name);
    my ($dot, $last, $method);

    $self->debug(
        "dot: [", 
        join('].[', $name, @$dots),
        "]"
    ) if DEBUG;
    

    # resolve any dotted paths after the head
    foreach $dot (@$dots) {
        # call any function reference to return a value
        if (ref $data eq CODE) {
            $data = $data->();
        }

        CHECK: {
            if (ref $data eq HASH || is_object(METADATA_OBJECT, $data)) {
                $data = $data->{ $dot };
                last CHECK;
            }
            elsif (ref $data eq ARRAY) {
                if (numlike $dot) {
                    $data = $data->[$dot];
                    last CHECK;
                }
                # else vmethods?
            }
            elsif (blessed $data) {
                if ($method = $data->can($dot)) {
                    $data = $method->($dot);
                    last CHECK;
                }
            }
            return $self->decline_msg( 
                no_config => join('.', @done, $dot)
            );
        }

        if (! defined $data) {
            return $self->decline_msg( 
                no_config => join('.', @done, $dot)
            );
        }
        push(@done, $dot);
    }

    return $data;
}

sub head {
    my ($self, $name) = @_;
    # subclasses can do somethign more complicated
    return $self->{ data }->{ $name };
}

sub set {
    my $self = shift->prototype;
    my $name = shift;
    my $data = @_ == 1 ? shift : { @_ };
    $self->{ data }->{ $name } = $data;
    $self->{ item }->{ $name } = 1;
    return $data;
}

sub can_configure {
    my ($self, $name) = @_;

    $self = $self->prototype unless ref $self;

    $self->debug("can_configure($name)") if DEBUG;

    return 
        unless $name && $self->has_item($name);

    return sub {
        return @_ > 1
            ? shift->set( $name => @_ )     # set
            : shift->get( $name );
    };
}

sub has_item {
    my $self = shift->prototype;
    my $name = shift;
    $self = $self->prototype unless ref $self;
    return $self->{ item }->{ $name };
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

=head1 INTERNAL METHODS

=head2 can_configure($name)

Internal method used to generate accessor methods on demand.  This is 
installed using the L<auto_can|Badger::Class/auto_can> hook in 
L<Badger::Class>.

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
