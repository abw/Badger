#========================================================================
#
# Badger::Factory
#
# DESCRIPTION
#   Factory module for loading and instantiating other modules.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Factory;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Prototype Badger::Exporter',
    import    => 'class',
    utils     => 'plural blessed textlike',
    words     => 'ITEM ITEMS ISA',
    constants => 'PKG ARRAY HASH REFS ONCE',
    constant  => {
        OBJECT       => 'object',
        FOUND_REF    => 'found_ref',
        PATH_SUFFIX  => '_PATH',
    },
    messages  => {
        no_item    => 'No item(s) specified for factory to manage',
        bad_ref    => 'Invalid reference for %s factory item %s: %s',
        bad_method => qq{Can't locate object method "%s" via package "%s" at %s line %s},
    };

our $RUNAWAY = 0;
our $AUTOLOAD;
our %LOADED;
our %MAPPED;

*init = \&init_factory;


sub init_factory {
    my ($self, $config) = @_;
    my $class = $self->class;
    my ($item, $items, $path);

    # 'item' and 'items' can be specified as config params or we look for
    # $ITEM and $ITEMS variables in the current package or those of any 
    # base classes.  NOTE: $ITEM and $ITEMS must be in the same package
    unless ($item = $config->{ item }) {
        foreach my $pkg ($class->heritage) {
            no strict   REFS;
            no warnings ONCE;
            
            if (defined ($item = ${ $pkg.PKG.ITEM })) {
                $items = ${ $pkg.PKG.ITEMS };
                last;
            }
        }
    }
    return $self->error_msg('no_item')
        unless $item;

    # use 'items' in config, or grokked from $ITEMS, or guess plural
    $items = $config->{ items } || $items || plural($item);

    $path = $config->{ $item.'_path' } || $config->{ path };
    $path = [ $path ] if $path && ref $path ne ARRAY;
    $self->{ path   } = $class->list_vars(uc $item . PATH_SUFFIX, $path);
    $self->{ $items } = $class->hash_vars(uc $items, $config->{ $items });
    $self->{ items  } = $items;
    $self->{ item   } = $item;

    $self->debug("Initialised $item/$items factory") if DEBUG;
    $self->debug("Path: [", join(', ', @{ $self->{ path } }), "]") if DEBUG;
    
    
    return $self;
}


sub path {
    my $self = shift->prototype;
    return @_ 
        ? ($self->{ path } = ref $_[0] eq ARRAY ? shift : [ @_ ])
        :  $self->{ path };
}


sub items {
    my $self  = shift->prototype;
    my $items = $self->{ $self->{ items } };
    if (@_) {
        my $args = ref $_[0] eq HASH ? shift : { @_ };
        @$items{ keys %$args } = values %$args;
    }
    return $items;
}


sub item {
    my $self = shift->prototype;
    my ($type, @args) = $self->type_args(@_);
    my $items = $self->{ $self->{ items } };
    my ($name, $item, $iref);

    # Modules like Template::TT2::Filterw allow the first argument to be 
    # a code ref or object which implements the required behaviour.  If this
    # is the case then we bypass the whole module lookup business and assume
    # that we've been handed an object/ref that we otherwise would have 
    # constructed.

    if (textlike $type) {
        # massage $type to a canonical form
        $name = lc $type;
        $name =~ s/\W//g;
        $item = $items->{ $name };
    }
    else {
        $name = $item = $type;
    }
    
    # TODO: add $self to $config - but this breaks if %$config check
    # in Badger::Codecs found_ref_ARRAY
    
    if (! defined $item) {
        # we haven't got an entry in the items table so let's try 
        # autoloading some modules using the module path
        $item = $self->load($type, @args)
            || return $self->not_found( $name, @args );
#            || return $self->error_msg( not_found => $self->{ item }, $type );
        $item = $self->construct($name, $item, @args);
    }
    elsif ($iref = ref $item) {
        $iref = OBJECT if blessed $item;

        $self->debug(
            "Looking for handler methods: ", 
            FOUND_REF,'_'.$iref, "() or ", 
            FOUND_REF, "()"
        ) if DEBUG;
        
        my $method 
             = $self->can(FOUND_REF . '_' . $iref)
            || $self->can(FOUND_REF)
            || return $self->error_msg( bad_ref => $self->{ item }, $type, $iref );
            
        $item = $method->($self, $name, $item, @args) 
            || return;
    }
    else {
        # otherwise we load the module and create a new object
        class($item)->load unless $LOADED{ $item }++;
        $item = $self->construct($name, $item, @args);
    }

    return $self->found( $name => $item );
#    return $item;
}


# TODO: make this more generic and have a selectable/pluggable strategy

sub type_args {
    my $self   = shift;
    my $type   = shift;
    my $params = @_ && ref $_[0] eq HASH ? shift : { @_ };
    $params->{ $self->{ items } } ||= $self;
    return ($type, $params);
}


sub construct {
    shift;            # $self
    shift;            # $name
    shift->new(@_);   # $class, @args
}


sub module_names {
    my ($self, $base, $type) = @_;
#    (ucfirst $type, $type, uc $type);   # Foo, foo, FOO

    join( PKG,
         $base,
         map {
             join( '',
                   map { s/(.)/\U$1/; $_ }
                   split('_')
             );
         }
         split(/\./, $type)
    );
}


sub load {
    my $self   = shift->prototype;
    my $type   = shift;
    my $bases  = $self->path;
    my $loaded = 0;
    my $module;
    
    foreach my $base (@$bases) {
        foreach $module ($self->module_names($base, $type)) {
            no strict REFS;

            # TODO: handle multi-element names, e.g. foo.bar
            
            $self->debug("maybe load $module ?\n") if $DEBUG;
            # Some filesystems are case-insensitive (like Apple's HFS), so an 
            # attempt to load Badger::Example::foo may succeed, when the correct 
            # package name is actually Badger::Example::Foo
            return $module 
                if ($loaded || class($module)->maybe_load && ++$loaded)
                && @{ $module.PKG.ISA };
                
            $self->debug("failed to load $module\n") if $DEBUG;
        }
    }
    return undef;
#   return $self->error_msg( not_found => $self->{ item } => $type );
}


sub found_ref_ARRAY {
    my ($self, $name, $item, @args) = @_;
    
    # default behaviour for handling a factory entry that is an ARRAY
    # reference is to assume that it is a [$module, $class] pair
    
    class($item->[0])->load unless $LOADED{ $item->[0] }++;
    return $self->construct($name, $item->[1], @args);
}


sub found {
    return $_[2];
}


sub not_found {
    my ($self, $name, @args) = @_;
    $self->error_msg( not_found => $self->{ item }, $name );
}


sub can {
    my ($self, $name) = @_;

    # upgrade class methods to calls on prototype
    $self = $self->prototype unless ref $self;
    
    if ($name eq $self->{ item }) {
        return $self->can('item');          # TODO: SUPER
    }
    elsif ($name eq $self->{ items }) {
        return $self->can('items');
    }
    else {
        return $self->SUPER::can($name);
    }
}


sub AUTOLOAD {
    my ($self, @args) = @_;
    my ($name) = ($AUTOLOAD =~ /([^:]+)$/ );
    return if $name eq 'DESTROY';

    $self->debug("AUTOLOAD $name\n") if $DEBUG;

    local $RUNAWAY = $RUNAWAY;
    $self->error("AUTOLOAD went runaway on $name")
        if ++$RUNAWAY > 10;

    # upgrade class methods to calls on prototype
    $self = $self->prototype unless ref $self;

    $self->debug("factory item: $self->{ item }\n") if DEBUG;
    
    if ($name eq $self->{ item }) {
        $self->class->method( $name => $self->can('item') );
    }
    elsif ($name eq $self->{ items }) {
        $self->class->method( $name => $self->can('items') )
    }
    elsif (my $item = $self->try( item => $name, @args )) {
        return $item;
    }
    else {
        my ($pkg, $file, $line) = caller;
        my $class = ref $self || $self;
        die $self->message( bad_method => $name, $class, $file, $line ), "\n";
    }
    
    # should be installed now
    $self->$name(@args);
}


1;

__END__

=head1 NAME

Badger::Factory - base class factory module

=head1 SYNOPSIS

This module is designed to be subclassed to create factory classes that
automatically load modules and instantiate objects on demand.

    package My::Widgets;
    use base 'Badger::Factory';
    
    # tell the base class factory what we create
    our $ITEM        = 'widget';
    our $ITEMS       = 'widgets';
    
    # define module search path for widgets
    our $WIDGET_PATH = ['My::Widget', 'Your::Widget'];
    
    # lookup table for any non-standard spellings/capitalisations/paths
    our $WIDGETS     = {
        url   => 'My::Widget::URL',       # non-standard capitalisation
        color => 'My::Widget::Colour',    # different spelling
        amp   => 'Nigels::Amplifier',     # different path
    };

You can then use it like this:

    use My::Widgets;
    
    # class methods (note: widget() is singular)
    $w = My::Widgets->widget( foo => { msg => 'Hello World' } );
    
    # same as:
    use My::Widget::Foo;
    $w = My::Widget::Foo({ msg => 'Hello World' });

    # add/update widgets lookup table (note: widgets() is plural)
    My::Widgets->widgets(
        extra => 'Another::Widget::Module',
        super => 'Golly::Gosh',
    );
    
    # now load and instantiate new widget modules
    $w = My::Widgets->widget( extra => { msg => 'Hello Badger' } );

You can also create factory objects:

    my $factory = My::Widgets->new(
        widget_path => ['His::Widget', 'Her::Widget'],
        widgets     => {
            extra => 'Another::Widget::Module',
            super => 'Golly::Gosh',
        }
    );
    
    $w = $factory->widget( foo => { msg => 'Hello World' } );

The L<Badger::Factory::Class> module can be used to simplify the process
of defining factory subclasses.

    package My::Widgets;
    
    use Badger::Factory::Class
        item    => 'widget',
        path    => 'My::Widget Your::Widget';
        widgets => {
            extra => 'Another::Widget::Module',
            super => 'Golly::Gosh',
        };

=head1 DESCRIPTION

This module implements a base class factory object for loading modules
and instantiating objects on demand.

TODO: the rest of the documentation

=head1 METHODS

=head2 path($path)

Mutator method to get/set the factory module path.

TODO: examples

=head2 items(%items)

TODO: Method to fetch or update the lookup table for mapping names to modules

=head2 item($name,@args)

TODO: Method to load a module and insantiate an object.

=head2 type_args(@args)

TODO: Method to perform any manipulation on the argument list before passing 
to object constructor

=head2 load($type)

TODO: Method to load a module for an object type

=head2 construct($name,$class,@args)

TODO: Method to instantiate a $class object using the arguments provided.
In the base class this method  simply calls:

    $class->new(@args);

=head2 module_names($type)

TODO: Method to expand an object type into a candidate list of module names.

=head2 found_ref_ARRAY($name,$entry,@args)

TODO: Method hook to handle the case of a factory entry defined as an 
array reference.  It is assumed to be C<[$module, $class]>.  The C<$module>
is loaded and the C<$class> instantiated.

Subclasses can re-define this to change this behaviour.

=head2 found($name,$item)

TODO: Method hook to perform any post-processing (e.g. caching) after an
item has been found and instantiated.

=head2 not_found($name,@args)

Called when the requested item is not found, this method simply throws 
an error using the C<not_found> message format.  The method can be 
re-defined in subclasses to perform additional fallback handing.

=head2 can($method)

TODO: Implements the magix to ensure that the item-specific accessor methods
(e.g. widget()/widgets()) are generated on demand.

=head2 AUTOLOAD(@args)

TODO: Implements the AUTOLOAD magic to generate the item-specific accessor
methods (e.g. widget()/widgets()) on demand.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Factory::Class>, L<Badger::Codecs>.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
