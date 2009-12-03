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
    utils     => 'plural blessed textlike dotid camel_case',
    words     => 'ITEM ITEMS ISA',
    constants => 'PKG ARRAY HASH REFS ONCE DEFAULT',
    constant  => {
        OBJECT         => 'object',
        FOUND          => 'found',
        FOUND_REF      => 'found_ref',
        PATH_SUFFIX    => '_PATH',
        NAMES_SUFFIX   => '_NAMES',
        DEFAULT_SUFFIX => '_DEFAULT',
    },
    messages  => {
        no_item    => 'No item(s) specified for factory to manage',
        no_default => 'No default defined for %s factory',
        bad_ref    => 'Invalid reference for %s factory item %s: %s',
        bad_method => qq{Can't locate object method "%s" via package "%s" at %s line %s},
    };

our $RUNAWAY = 0;
our $AUTOLOAD;

*init = \&init_factory;


sub init_factory {
    my ($self, $config) = @_;
    my $class = $self->class;
    my ($item, $items, $path, $map, $default);

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

    my $ipath    = $item.PATH_SUFFIX;
    my $inames   = $item.NAMES_SUFFIX;
    my $idefault = $item.DEFAULT_SUFFIX;
    
    # Merge all XXXX_PATH package vars with any 'xxxx_path' or 'path' config 
    # items.  Ditto for XXXX_NAME / 'xxxx_name' / 'aka' and  XXXXS/ 'xxxxs'
    
    my @path  = @$config{ path  => $ipath  };
    my @names = @$config{ names => $inames };
    $self->{ path     } = $class->list_vars(uc $ipath, @path);
    $self->{ names    } = $class->hash_vars(uc $inames, @names);
    $self->{ $items   } = $class->hash_vars(uc $items, $config->{ $items });
    $self->{ items    } = $items;
    $self->{ item     } = $item;
    $self->{ loaded   } = { };
    $self->{ no_cache } = $config->{ no_cache };  # quick hack - need refactoring

    # see if a 'xxxx_default' or 'default' configuration option is specified
    # or look for the first XXXX_DEFAULT or DEFAULT package variable.
    $default = $config->{ $idefault } 
            || $config->{ default }
            || $class->any_var_in( uc $idefault, uc DEFAULT );
    if ($default) {
        $self->debug("Setting default to $default") if DEBUG;
        $self->{ default } = $self->{ names }->{ default } = $default;
    }

    $self->debug(
        "Initialised $item/$items factory\n",
        " Path: ", $self->dump_data($self->{ path }), "\n",
        "Names: ", $self->dump_data($self->{ names })
    ) if DEBUG;

    return $self;
}

sub path {
    my $self = shift->prototype;
    return @_ 
        ? ($self->{ path } = ref $_[0] eq ARRAY ? shift : [ @_ ])
        :  $self->{ path };
}

sub default {
    my $self = shift->prototype;
    return @_ 
        ? ($self->{ default } = $self->{ names }->{ default } = shift)
        :  $self->{ default };
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
    my $self = shift; $self = $self->prototype unless ref $self;
    my ($type, @args) = $self->type_args(@_);

    # In most cases we're expecting $type to be a name (e.g. Table) which we
    # lookup in the items hash, or tack onto one of the module bases in the 
    # path (e.g. Template::Plugin) to create a full module name which we load 
    # and instantiate (e.g. Template::Plugin::Table).  However, the name might 
    # be explicitly mapped to a  reference of some kind, or the $type passed 
    # in could already be a reference (e.g. Template::TT2::Filters allow the 
    # first argument to be a code ref or object which implements the required 
    # filtering behaviour).  In which case, we bypass any name-based lookup
    # and skip straight onto the "look what I found!" phase

    return $self->found($type, $type, \@args)
        unless textlike $type;

    $type = $type . '';     # auto-stringify any textlike objects
    
    # OK, so $type is a string.  We'll also create a canonical version of the 
    # name (lower case dotted) to provide a case/syntax insensitve fallback
    # (e.g. so "foo.bar" can match against "Foo.Bar", "Foo::Bar" and so on)
    
    my $items = $self->{ $self->{ items } };
    my $canon = dotid $type;

    $self->debug("Looking for '$type' or '$canon' in $self->{ items }") if DEBUG;
#   $self->debug("types: ", $self->dump_data($self->{ types })) if DEBUG;

    # false but defined entry indicates the item is not found
    return $self->not_found($type, \@args)
        if exists $items->{ $type }
           && not $items->{ $type };

    my $item = $items->{ $type  } 
            || $items->{ $canon }
            # TODO: this needs to be defined-or, like //
            # Plugins can return an empty string to indicate that they 
            # do nothing.
            # HMMM.... or does it?
            ||  $self->find($type, \@args)
#            ||  $self->default($type, \@args)
            ||  return $self->not_found($type, \@args);

    $items->{ $type } = $item
        unless $self->{ no_cache };

    return $self->found($type, $item, \@args);
}

sub type_args {
    # Simple method to grok $type and @args from argument list.  The only
    # processing it does is to set $type to 'default' if it is undefined or
    # false. Subclasses can re-define this to insert their own type mapping or 
    # argument munging, e.g. to inject values into the configuration params 
    # for an object
    shift;
    my $type = shift || DEFAULT;
    return ($type, @_);
}

sub find {
    my $self   = shift;
    my $type   = shift;
    my $bases  = $self->path;
    my $module;
    
    # run the type through the type map to handle any unusual capitalisation,
    # spelling, aliases, etc.
    $type = $self->{ names }->{ $type } || $type;
    
    foreach my $base (@$bases) {
        return $module
            if $module = $self->load( $self->module_names($base, $type) );
    }

    return undef;
}

sub load {
    my $self   = shift;
    my $loaded = $self->{ loaded }; 

    foreach my $module (@_) {
        # see if we've previously loaded a module with this name (true
        # value) or failed to load a module (defined but false value)
            
        if ($loaded->{ $module }) {
            $self->debug("$module has been previously loaded") if DEBUG;
            return $module;
        }
        elsif (defined $loaded->{ $module }) {
            next;
        }
                        
        no strict REFS;
        $self->debug("attempting to load $module") if DEBUG;

        # Some filesystems are case-insensitive (like Apple's HFS), so an 
        # attempt to load Badger::Example::foo may succeed, when the correct 
        # package name is actually Badger::Example::Foo.  We double-check
        # by looking for $VERSION or @ISA.  This is a bit dodgy because we might be
        # loading something that has no ISA.  Need to cross-check with 
        # what's going on in Badger::Class _autoload()

        if ( ( $loaded->{ $module } = class($module)->maybe_load )
        &&   ( ${ $module.PKG.VERSION } || @{ $module.PKG.ISA }  ) ) {
            $self->debug("loaded $module") if DEBUG;
            return $module 
        }

        $self->debug("failed to load $module") if DEBUG;
    }

    return undef;
}


sub found {
    my ($self, $type, $item, $args) = @_;
    
    if (ref $item) {
        # if it's a reference we found then forward it onto the appropriate
        # method, e.g found_array(), found_hash(), found_code().  Fall back 
        # on found_ref()
        my $iref = blessed($item)
            ? OBJECT 
            : lc ref $item;

        $self->debug(
            "Looking for handler methods: ", 
            FOUND,'_'.$iref, "() or ", 
            FOUND_REF, "()"
        ) if DEBUG;
        
        my $method 
             = $self->can(FOUND . '_' . $iref)
            || $self->can(FOUND_REF)
            || return $self->error_msg( bad_ref => $self->{ item }, $type, $iref );
            
        $item = $method->($self, $type, $item, $args);
    }
    else {
        # otherwise it's the name of a module
        $item = $self->found_module($type, $item, $args);
    }

    # NOTE: an item can be defined but false, e.g. a Template::Plugin which
    # return '' from its new() method to indicate it does nothing objecty
    return unless defined $item;
    
    $self->debug("Found result: $type => $item") if DEBUG;

    # TODO: what about caching result?  Do we always leave that to subclasses?
    return $self->result($type, $item, $args);
}

sub found_module {
    # This method is called when a module name is found, either by being 
    # predefined in the factory entry table, or loaded on demand from disk.
    # It ensures the module is loaded and and instantiates an object from the 
    # class name
    my ($self, $type, $module, $args) = @_;
    $self->debug("Found module: $type => $module") if DEBUG;
    $self->{ loaded }->{ $module } ||= class($module)->load;
    return $self->construct($type, $module, $args);
}

sub found_array {
    my ($self, $type, $item, $args) = @_;
    my ($module, $class) = @$item;
    $self->{ loaded }->{ $module } ||= class($module)->load;
    return $self->construct($type, $class, $args);
}

sub not_found {
    my ($self, $type, @args) = @_;

    return $type eq DEFAULT
        ? $self->error_msg( no_default => $self->{ item } )
        : $self->error_msg( not_found => $self->{ item }, $type );
}

sub construct {
    my ($self, $type, $class, $args) = @_;
    $self->debug("constructing class: $type => $class") if DEBUG;
    return $class->new(@$args);
}

sub module_names {
    my $self = shift;
    my @bits = 
        map { camel_case($_) }
        map { split /[\.]+/ } @_;

    return (
        join( PKG, map { ucfirst $_ } @bits ),
        join( PKG, @bits )
    );
}


sub can {
    my ($self, $name) = @_;

    # upgrade class methods to calls on prototype
    $self = $self->prototype unless ref $self;

    # NOTE: this method can get called before we've called init_factory()
    # to define the item/items members, so we tread carefully.
    if ($self->{ item } && $self->{ item } eq $name) {
        return $self->SUPER::can('item');
    }
    elsif ($self->{ items } && $self->{ items } eq $name) {
        return $self->SUPER::can('items');
    }
    else {
        return $self->SUPER::can($name);
    }
}

sub result {
    $_[2];
}

sub AUTOLOAD {
    my ($self, @args) = @_;
    my ($name) = ($AUTOLOAD =~ /([^:]+)$/ );
    return if $name eq 'DESTROY';

    $self->debug("AUTOLOAD $name") if DEBUG;

    local $RUNAWAY = $RUNAWAY;
    $self->error("AUTOLOAD went runaway on $name")
        if ++$RUNAWAY > 10;

    # upgrade class methods to calls on prototype
    $self = $self->prototype unless ref $self;

    $self->debug("factory item: $self->{ item }") if DEBUG;
    
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

This module implements a base class factory object for loading modules and
instantiating objects on demand. It originated in the L<Template::Plugins>
module, evolved over time in various directions for other projects, and was 
eventually pulled back into line to become C<Badger::Factory>.

=head2 Defining a Factory Module

The C<Badger::Factory> module isn't designed to be used by itself. Rather it
should be used as a base class for your own factory modules. For example,
suppose you have a project which has lots of C<My::Widget::*> modules. You can
define a factory for them like so:

    package My::Widgets;
    use base 'Badger::Factory';
    
    our $ITEM           = 'widget';
    our $ITEMS          = 'widgets';
    our $WIDGET_PATH    = ['My::Widget', 'Your::Widget'];
    our $WIDGET_DEFAULT = 'foo';
    our $WIDGET_NAMES   = {
        html => 'HTML',
    };

    # lookup table for any non-standard spellings/capitalisations/paths
    our $WIDGETS     = {
        url   => 'My::Widget::URL',       # non-standard capitalisation
        color => 'My::Widget::Colour',    # different spelling
        amp   => 'Nigels::Amplifier',     # different path
    };

    1;

The C<$ITEM> and C<$ITEMS> package variables are used to define the
singular and plural names of the items that the factory is responsible for.
In this particular case, the C<$ITEMS> declaration isn't strictly 
necessary because the module would correctly "guess" the plural name 
C<widgets> from the singular C<widget> defined in C<$ITEM>.  However, 
this is only provided as a convenience for those English words that 
pluralise regularly and shouldn't be relied upon to work all the time.
See the L<pluralise()|Badger::Utils/pluralise()> method in L<Badger::Utils>
for further information, and explicitly specify the plural in C<$ITEMS> if
you're in any doubt.

The C<$WIDGET_PATH> is used to define one or more base module names under
which your widgets are located.  The name of this variable is derived 
from the upper case item name in C<$ITEM> with C<_PATH> appended.  In this
example, the factory will look for the C<Foo::Bar> module as either 
C<My::Widget::Foo::Bar> or C<Your::Widget::Foo::Bar>.  

The C<$WIDGET_DEFAULT> specifies the default item name to use if a request
is made for a module using an undefined or false name.  If you don't specify
any value for a default then it uses the literal string C<default>.  Adding
a C<default> entry to your C<$WIDGET_NAMES> or C<$WIDGETS> will have the same
effect.

The C<$WIDGET_NAMES> is used to define any additional name mappings. This is
usually required to handle alternate spellings or unusual capitalisations that
the default name mapping algorithm would get wrong. For example, a request for
an C<html> widget would look for C<My::Widget::Html> or C<Your::Widget::Html>.
Adding a C<$WIDGET_MAP> entry mapping C<html> to C<HTML> will instead send it
looking for C<My::Widget::HTML> or C<Your::Widget::HTML>.

If you've got any widgets that aren't located in one of these locations,
or if you want to provide some aliases to particular widgets then you can
define them in the C<$WIDGETS> package variable.  The name of this variable
is the upper case conversion of the value defined in the C<$ITEMS> package
variable.

=head2 Using Your Factory Module

Now that you've define a factory module you can use it like this.

    use My::Widgets;
    
    my $widgets = My::Widgets->new;
    my $foo_bar = $widgets->widget('Foo::Bar');

The C<widget()> method is provided to load a widget module and instantiate
a widget object.

The above example is equivalent to:

    use My::Widget::Foo::Bar;
    my $foo_bar = My::Widget::Foo::Bar->new;

Although it's not I<strictly> equivalent because the factory could just
has easily have loaded it from C<Your::Widget::Foo::Bar> in the case that
C<My::Widget::Foo::Bar> doesn't exist.

You can specify additional arguments that will be forwarded to the object 
constructor method.

    my $foo_bar = $widgets->widget('Foo::Bar', x => 10, y => 20);

If you've specified a C<$WIDGET_DEFAULT> for your factory then you can call
the L<widget()> method without any arguments to get the default object.

    my $widget = $widgets->widget;

You can use the L<default()> method to change the default module.

    $widgets->default('bar');

The factory module can be customised using configuration parameters. For
example, you can provide additional values for the C<widget_path>, or define
additional widgets:

    my $widgets = My::Widgets->new(
        widget_path => ['His::Widget', 'Her::Widget'],
        widgets     => {
            extra => 'Another::Widget::Module',
            super => 'Golly::Gosh',
        }
    );

The factory module is an example of a L<prototype()|Badger::Prototype> module.
This means that you can call the C<widget()> method as a class method to save
yourself of explicitly creating a factory object.

    my $widget = My::Widgets->widget('Foo::Bar');

=head1 METHODS

=head2 new()

Constructor method to create a new factory module.

    my $widgets = My::Widgets->new;

=head2 path($path)

Used to get or set the factory module path.

    my $path = $widgets->path;
    $widgets->path(['My::Widgets', 'Your::Widgets', 'Our::Widgets']);

Calling the method with arguments replaces any existing list.

=head2 names($names)

Used to get or set the names mapping table.

    my $names = $widgets->names;
    $widgets->names({ html => 'HTML' });

Calling the method with arguments replaces any existing names table.

=head2 default($name)

Used to get or set a name for the default item name.  The default value is
the literal string C<default>.  This allows you to add a C<default> entry
to either your L<names()> or L<items()> and it will be located automatically.

=head2 items(%items)

Used to fetch or update the lookup table for mapping names to modules.

    my $items = $widgets->items;
    $widgets->items( foo => 'My::Plugin::Foo' );

Calling the method with arguments (named parameters or a hash reference) 
will add the new definitions into the existing table.

This method can also be aliased by the plural name defined in C<$ITEMS>
in your subclass module.

    $widgets->widgets;

=head2 item($name,@args)

Method to load a module and instantiate an object.

    my $widget = $widgets->item('Foo');

Any additional arguments provided after the module name are forwarded to the
object's C<new()> constructor method.

    my $widget = $widgets->item( Foo => 10, 20 );

This method can also be aliased by the singular name defined in C<$ITEM>
in your subclass module.

    my $widget = $widgets->widget( Foo => 10, 20 );

The module name specified can be specified in lower case.  The name is
capitalised as a matter of course.

    # same as Foo
    my $widget = $widgets->widget( foo => 10, 20 );

Multi-level names can be separated with dots rather than C<::>.  This is in
keeping with the convention used in the Template Toolkit.  Each element after
a dot is capitalised.

    # same as Foo::Bar
    my $widget = $widgets->widget( 'foo.bar' => 10, 20 );

=head1 INTERNAL METHODS

=head2 type_args(@args)

This method can be re-defined by a subclass to perform any pre-manipulation on
the arguments passed to the L<item()> method.  The first argument is usually
the type (i.e. name) of module requested, followed by any additional arguments
for the object constructor.

    my ($self, $type, @args) = @_;

The method should return them like so:

    return ($type, @args);

=head2 find($type,\@args)

This method is called to find and dynamically load a module if it doesn't
already have an entry in the internal C<items> table.  It iterates through
each of the base paths for the factory and calls the L<load()> method to
see if the module can be found under that prefix.

=head2 load(@module_names)

This method is called to dynamically load a module.  It iterates through
each of the module name passed as arguments until it successfully loads
one.  At that point it returns the module name that was successfully 
loaded and ignores the remaining arguments.  If none of the modules can
be loaded then it returns C<undef>

=head2 found($name,$item,\@args)

This method is called when an item has been found, either in the internal
C<items> lookup table, or by a call to L<find()>. The L<$item> argument is
usually a module name that is forwarded onto L<found_module()>. However, it
can also be a reference which will be forwarded onto one of the following
methods depending on its type: L<found_array()>, L<found_hash()>,
L<found_scalar()>, L<found_object()> (and in theory, C<found_regex()>, 
C<found_glob()> and maybe others, but they're not implemented).

The result returned by the appropriate C<found_XXXXX()> method will then
be forwarded onto the L<result()> method.  The method returns the result
from the L<result()> method.

=head2 found_module($module)

This method is called when a requested item has been mapped to a module name.
The module is loaded if necessary, then the L<construct()> method is called
to construct an object.

=head2 found_array(\@array)

An entry in the C<items> (aka C<widgets> in our earlier example) table
can be a reference to a list containing a module name and a separate class
name.

    my $widgets = My::Widgets->new(
        widgets => {
            wizbang => ['Wiz::Bang', 'Wiz::Bang::Bash'],
        },
    );

If the C<wizbang> widget is requested from the C<My::Widgets> factory
in the example above, then the L<found()> method will call C<found_array()>,
passing the array reference as an argument.

The module listed in the first element is loaded.  The class name in 
the second element is then used to instantiate an object.

=head2 found_hash(\%hash)

This method isn't implemented in the base class, but can be defined by
subclasses to handle the case where a request is mapped to a hash reference.

=head2 found_scalar(\$scalar)

This method isn't implemented in the base class, but can be defined by
subclasses to handle the case where a request is mapped to a scalar reference.

=head2 found_object($object)

This method isn't defined in the base class, but can be defined by subclasses
to handle the case where a request is mapped to an existing object.

=head2 construct($name,$class,\@args)

This method instantiates a C<$class> object using the arguments provided.
In the base class this method  simply calls:

    $class->new(@$args);

=head2 result($name,$result,\@args)

This method is called at the end of a successful request after an object
has been instantiated (or perhaps re-used from an internal cache).  In the
base class it simply returns C<$result> but can be redefined in a subclass
to do something more interesting.

=head2 module_names($type)

This method performs the necessary mapping from a requested module name to 
its canonical form.

=head2 not_found($name,@args)

This method is called when the requested item is not found. The method simply
throws an error using the C<not_found> message format. The method can be
redefined in subclasses to perform additional fallback handing.

=head2 can($method)

This method implements the magic to ensure that the item-specific accessor
methods (e.g. C<widget()>/C<widgets()>) are generated on demand.

=head2 AUTOLOAD(@args)

This implements the other bit of magic to generate the item-specific accessor
methods on demand.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2009 Andy Wardley.  All Rights Reserved.

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
