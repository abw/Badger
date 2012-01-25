#========================================================================
#
# Badger::Modules
#
# DESCRIPTION
#   Module for loading and instantiating other modules.
#
# NOTE
#   Badger::Factory is being cleaved in twain.  Badger::Modules will 
#   implement the lower level parts related to finding and loading 
#   modules.  Badger::Factory will be a subclass specialised for creating
#   object instances.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Modules;

use Carp;
use Badger::Debug ':dump';
use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Prototype Badger::Exporter',
    import      => 'class',
    utils       => 'plural blessed textlike dotid camel_case',
    accessors   => 'item items',
    words       => 'ITEM ITEMS ISA TOLERANT BADGER_LOADED',
    constants   => 'PKG ARRAY HASH REFS ONCE DEFAULT',
    constant    => {
        OBJECT          => 'object',
        FOUND           => 'found',
        FOUND_REF       => 'found_ref',
        PATH_SUFFIX     => '_PATH',
        NAMES_SUFFIX    => '_NAMES',
        DEFAULT_SUFFIX  => '_DEFAULT',
    },
    methods     => {
        init            => \&init_modules,
        throws          => \&item,
    },
    messages    => {
        no_item     => 'No item(s) specified for factory to manage',
        no_default  => 'No default defined for %s factory',
        bad_ref     => 'Invalid reference for %s factory item %s: %s',
        bad_method  => q{Can't locate object method "%s" via package "%s" at %s line %s},
        failed      => q{Error loading %s module %s as %s: %s},
    };

our $ITEM = 'module';


sub init_modules {
    my ($self, $config) = @_;
    my $class = $self->class;
    my ($item, $items);

    $self->debug("initialising modules: ", $self->dump_data($config)) if DEBUG;

    $config->{ tolerant } = $class->any_var(TOLERANT)
        unless defined $config->{ tolerant };

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
    
    my @path  = @$config{ path  => lc $ipath  };
    my @names = @$config{ names => lc $inames };
    $self->{ path     } = $class->list_vars(uc $ipath, @path);
    $self->{ names    } = $class->hash_vars(uc $inames, @names);
    $self->{ $items   } = $class->hash_vars(uc $items, $config->{ $items });        # TODO: this could clash
    $self->{ tolerant } = $config->{ tolerant };
    $self->{ items    } = $items;
    $self->{ item     } = $item;
    $self->{ loaded   } = { };                                                      # TODO: make this the same thing?

    $self->debug(
        " Item: $self->{ item }\n",
        "Items: $self->{ items }\n",
        " Path: ", $ipath, ": ", $self->dump_data($self->{ path }), "\n",
        "Names: ", $inames, ": ", $self->dump_data($self->{ names })
    ) if DEBUG;

    return $self;
}


sub path {
    my $self = shift->prototype;
    return @_ 
        ? ($self->{ path } = ref $_[0] eq ARRAY ? shift : [ @_ ])
        :  $self->{ path };
}


sub names {
    my $self  = shift->prototype;
    my $names = $self->{ names };
    if (@_) {
        my $args = ref $_[0] eq HASH ? shift : { @_ };
        @$names{ keys %$args } = values %$args;
    }
    return $names;
}


sub module_names {
    my $self = shift;
    my @bits = 
        map { camel_case($_) }
        map { split /[\.]+/ } @_;
    my %seen;

    return (
        grep { ! $seen{ $_ }++ }
        join( PKG, map { ucfirst $_ } @bits ),
        join( PKG, @bits )
    );
}


sub modules {
    my $self  = shift->prototype;
    my $items = $self->{ $self->{ items } };
    if (@_) {
        # NOTE: this doesn't have any effect... it's a artefact from 
        # Badger::Factory... we need to change $self->{ loaded } to be 
        # $self->{ items }
        my $args = ref $_[0] eq HASH ? shift : { @_ };
        @$items{ keys %$args } = values %$args;
    }
    return $items;
}


sub module {
    my $self    = shift->prototype;
    my $name    = shift;
    my $path    = $self->{ path    };
    my $loaded  = $self->{ loaded };
    my ($module, $base, $alias, $found, $file, $symtab, @names, $size);
    
    # Run the name through the name map to handle any unusual capitalisation,
    # spelling, aliases, etc.
    $name = $self->{ names }->{ $name } || $name;

    # Then expand the name using whatever rules are in effect (e.g. the 
    # default which maps foo_bar to FooBar)
    # FIXME: probably shouldn't do this if we found an entry in the names lookup
    @names = $self->module_names($name);
    
  LOOKUP: 
    foreach $base (@$path) {
        foreach $alias (@names) {
            $module = join(PKG, $base, $alias);

            # TODO: look in $self->{ $items } for pre-defined result...
            
            # See if we've previously loaded a module with this name (true
            # value) or failed to load a module (defined but false value)
            if ($found = $loaded->{ $module }) {
                $self->debug("$module has already been loaded") if DEBUG;
                return $self->found( $name, $module );
            }
            elsif (defined $found) {
                $self->debug("$module has previously been requested but not found") if DEBUG;
                next;
            }

            # Look to see if the module already has a symbol table defined
            no strict REFS;
            $symtab = \%{$module.PKG};

            # We have to be careful because symbols may be defined in a 
            # package's symbols table *before* the module is loaded (e.g. the
            # $DEBUG package variable that Badger::Debug uses).  So we only
            # assume that the module is loaded if VERSION or BADGER_LOADED is
            # defined
            if ($symtab->{ VERSION } || $symtab->{ BADGER_LOADED }) {
                $self->debug("found an existing VERSION/BADGER_LOADED in $module symbol table") if DEBUG;
                return $self->found( $name, $module );
            }
            
            $file = $module;
            $file =~ s/::/\//g;         # TODO: check Perl maps this to OS
            $file .= '.pm';
            
            $self->debug("Attempting to load $module as $file") if DEBUG;

            eval {
                # We use eval so that we can "use" the module and force any
                # import hooks to run.  But it might be better to load the 
                # module with "require" and then manually call import()
                require $file;
            };

            if ($@) {
                $self->debug("Failed to load $module: $@") if DEBUG;
                # Don't confuse "Can't locate A/Module/Used/In/Your/Module.pm"
                # messages with "Can't locate Your/Module.pm".  The former is 
                # an error that should be reported, the latter isn't.  We convert the
                # class name to a regex that matches any non-word directory 
                # separators, e.g. Your::Module => Your\W+Module
                my $qmfile = quotemeta($file);
                $self->failed($name, $module, $@) if $@ !~ /^Can't locate $qmfile.*? in \@INC/;
                next;
            }

            # Some filesystems are case-insensitive (like Apple's HFS), so an 
            # attempt to load Badger::Example::foo may succeed, when the 
            # correct package name is actually Badger::Example::Foo.  We 
            # double-check by looking to see if anything extra has been added
            # to the symbol table. 
            $self->debug("$module symbol table keys: ", join(', ', keys %$symtab)) if DEBUG;
            next unless %$symtab;

            $self->debug("calling $module->import") if DEBUG;

            # now call the import() method to fire any import actions
            $module->import;

            # add the $BADGER_LOADED package variable to indicate that the 
            # module has been loaded and add an entry to the internal cache
            ${ $module.PKG.BADGER_LOADED } ||= 1;
            $loaded->{ $module } = $module;

            return $self->found( $name, $module );
        }
    }

    # add entry to indicate module not found
    $loaded->{ $name } = 0;
    
    return $self->not_found($name);
}


sub found {
    # my ($self, $name, $module) = @_;
    return $_[2];
}


sub not_found {
    my $self = shift;

    return $self->{ tolerant }
        ? $self->decline_msg( not_found => $self->{ item } => @_ )
        : $self->error_msg(   not_found => $self->{ item } => @_ );
}


sub failed {
    my $self = shift;
    $self->error_msg( failed => $self->{ item }, @_ );
}

    


1;

__END__

=head1 NAME

Badger::Modules - a module for loading modules

=head1 SYNOPSIS

=head2 Example 1 - using a Badger::Modules object

    use Badger::Modules;
    
    my $modules = Badger::Modules->new( 
        path => ['My::Example','Your::Example'],
    );
    
    # load either My::Example::Foo or Your::Example::Foo
    my $foo_module = $modules->module('foo');
    
    # module() returns the module (class) name that was loaded
    my $foo_object = $foo_module->new;

=head2 Example 2 - creating a Badger::Modules subclass

    package My::Project::Modules;
    use base 'Badger::Modules';
    our $PATH = 'My::Project';      # or a list reference
    1;

=head2 Example 3 - using the Badger::Modules subclass

    use My::Project::Modules;

    # either by creating an object...
    my $modules = My::Project::Modules->new;
    my $module  = $modules->module('foo')
        || die $modules->reason;
    
    # ...or by calling class methods
    my $module  = My::Project::Modules->module('foo')
        || die $modules->reason;
    
=head2 Example 4 - pre-loading modules (TODO)

    # This doesn't work yet
    use My::Project::Module
        preload => 'foo bar baz';
    
=head2 Example 4 - pre-loading modules and exporting constants (MAYBE)

    # Not sure about this.
    use My::Project::Module
        modules => 'foo bar baz';
    
    my $object = FOO_MODULE->new;

=head1 DESCRIPTION

C<Badger::Modules> is a module for dynamically loading other modules that live
under a common namespace or namespaces. 

It is ideally suited for loading plugin extension modules into an application
when you don't know in advance which modules may be required. An example of
such a module is L<Badger::Codecs> which loads L<Badger::Codec> modules for
encoding and decoding data in various formats. 

It can also be useful even when you I<do> know what modules you want to use,
or think you do. Delegating the task of loading modules to a central
C<Badger::Modules> object allows you to easily change the modules that are
loaded at a later date, simply by changing the configuration for the
C<Badger::Modules> object.

C<Badger::Modules> can be used as a stand-alone module or as a base class for
creating specialised sub-classes of your own. A subclass of C<Badger::Modules>
can pre-define default values for configuration options. For example, you
might want to create a C<Your::App::Plugins> module that is configured to load
modules under the C<Your::App::Plugin> namespace by default. 

Subclasses can also override methods to change the way it works or affect what
happens after a module is loaded. The L<Badger::Factory> module is an example
of such a module. It provides additional methods for dynamically creating
objects and relies on the underlying functionality provided by
C<Badger::Modules> to ensure that the relevant modules are loaded.

=head2 What's the Problem?

Consider the following code fragment showing a subroutine that creates and 
uses a C<Your::App::Widget> object.

    use Your::App::Widget;
    
    sub some_code {
        my $widget = Your::App::Widget->new;
        $widget->do_something;
    }

One of the benefits of object oriented programming is that objects of
equivalent types are interchangeable. That means that we should be able to
replace the C<Your::App::Widget> object with a different
implementation as long as it has the same interface in terms of the methods it
implements. In strictly typed programming languages this equivalence is
enforced rigidly, by requiring that both objects share a common base class,
expose the same interface, implement a particular role, or some other
mechanism. In loosely typed languages like Perl, we have to rely on duck
typing: if it looks like a duck, floats like a duck and quacks like a duck
then it is a duck (or is close enough to being a duck for practical purposes).

For example, we might want to use a dummy widget object for test purposes.

    use Your::App::MockObject::Widget;
    
    sub some_code {
        my $widget = Your::App::MockObject::Widget->new;
        $widget->do_something;
    }

Or perhaps use a C implementation of a module on platforms that support it.

    use Your::App::XS::Widget;
    
    sub some_code {
        my $widget = Your::App::XS::Widget->new;
        $widget->do_something;
    }

Or maybe an implementation with additional debugging facilities for use 
during development, but not in production code.

    use Your::App::Developer::Widget;
    
    sub some_code {
        my $widget = Your::App::Developer::Widget->new;
        $widget->do_something;
    }

By now the problem should be apparent. To use a different implementation of
the widget object we have to go and manually change the code. Every occurrence
of C<Your::App::Widget> in every module of your application must be
changed to the new module name.  Of course, if you were doing this in real 
life you would probably end up defining a variable to store the name of the
relevant class.  Something like this perhaps.

    use Your::App::Widget;
    our $WIDGET_CLASS = 'Your::App::Widget';
    
    sub some_code {
        my $widget = $WIDGET_CLASS->new;
        $widget->do_something;
    }

This works well in simple cases.  However, if you've designed your application 
to be suitably modular (thereby promoting reusability of the individual 
components and extensibility of the system as a whole) then you may have a 
whole bunch of different modules to load, all of which need similar variables.

    use Your::App::Widget;
    use Your::App::Doodah;
    use Your::App::Thingy;
    our $WIDGET_CLASS = 'Your::App::Widget';
    our $DOODAH_CLASS = 'Your::App::Doodah';
    our $THINGY_CLASS = 'Your::App::Thingy';

Not only is the repetition of C<Your::App> in the above code a red 
flag for refactoring in itself, but we also have to consider the issue of 
sharing these variables among the various modules that might need access to 
them.  But before we fall too deep into that rabbit hole, let's jump through
the looking glass and see how C<Badger::Modules> can be used to tackle the
problem.

=head2 Using Badger::Modules

C<Badger::Modules> can be used as a stand-alone module for loading other
modules in a particular namespace. The following example creates a 
C<Badger::Modules> object for loading modules under the C<Your::App> 
namespace.

    use Badger::Modules;
    
    my $modules = Badger::Modules->new( 
        path => 'Your::App' 
    );

Here we've created a C<Badger::Modules> object which loads modules under 
the C<Your::App> namespace.  To create a C<Your::App::Widget>
object we can now write the following code.

    my $wclass = $modules->module('Widget');
    my $widget = $wclass->new;

The L<module()> method maps the argument passed to a full class name
(C<Your::App::Widget>), loads the module if it hasn't already been
loaded and then returns the class name.  Of course we could combine this
into a single expression:

    my $widget = $modules->module('Widget')->new;

The L<path> configuration option can be specified as a reference to a list
of namespaces.  The C<Badger::Modules> module will try each in turn until 
it finds a matching module. 

    my $modules = Badger::Modules->new( 
        path => ['My::App','Your::App'],
    );

Now when you request the C<Widget> module you'll get
C<My::App::Widget> returned if it exists or
C<Your::App::Widget> if it doesn't.

If neither is available then an error will be thrown as a L<Badger::Exception>
object containing an error message of the format C<module not found: Widget>.
You can set the L<item> configuration option to something other than C<module>
to change this message.  For example, setting the C<item> to C<plugin> will
generate a C<plugin not found: Widget> message.

    my $modules = Badger::Modules->new( 
        item => 'plugin',
        path => ['My::App::Plugin','Your::App::Plugin'],
    );

If you would rather have the L<module()> method return C<undef> to indicate
that a module can't be found then set the C<tolerant> configuration option to
any true value.

    my $modules = Badger::Modules->new( 
        path     => ['My::App','Your::App'],
        tolerant => 1,
    );

It's then up to you to check the return value and handle the case where it is
undefined. The L<error()|Badger::Base/error()> method (inherited from the
L<Badger::Base> base class) can be used to return an error message for the
purposes of friendly error reporting.

    my $module = $modules->module('Widget')
        || die $modules->error;         # module not found: Widget

Any other errors encountered while loading a module will be reported using
C<croak>, regardless of the L<tolerant> option. These usually indicate syntax
errors requiring immediate attention and thereby warrant the full backtrace
that C<croak> provides. 

=head2 Mapping Names

[ROUGH DRAFT]

Name is tried as-is first.  

    Your::App + Widget = Your::App::Widget

Then we try camel casing it.  

    Your::App + nice_widget = Your::App::NiceWidget

This allows us to specify names in lower case with underscores separating
words and have them automatically mapped to the correct CamelCase
representation for module names.

Lower case + underscores not only looks nicer (IMHO, YMMV) but can also help
to eliminate problems on filesystems like HFS that are case insensitive by
default. If you're relying on the difference between say, C<CGI> and C<cgi> in
a module name then you're going to have a world of pain the first time you (or
someone else) tries to use that code on a shiny new Mac. And yes, that's me
speaking from personal experience :-)

You may think this is a brain-dead stupid thing to do. You may be right. But
there are brain-dead stupid filesystems out there that we have to accommodate.

=head2 Defining a Badger::Modules Subclass

The C<Badger::Modules> module can be used as a base class for your own
module-loading modules.  Here's a complete example.

    package My::App::Plugins;
    use base 'Badger::Modules';
    our $PATH = ['My::App::Plugin', 'Your::App::Plugin'];
    1;

The C<$PATH> package variable can be defined to provide the default search
path. The C<$ITEM>, C<$ITEMS>, C<$NAMES> and C<$TOLERANT> package variables
(not shown) can also be used to set the default values for the corresponding
configuration options.

You can then use your subclass like this:

    use My::App::Plugins;
    my $plugins = My::App::Plugins->new;
    my $plugin  = $plugins->module('example');

This will load either C<My::App::Plugin::Example> or
C<Your::App::Plugin::Example>, or throw an error to report that the
C<example> module can't be loaded.

You can provide additional configuration options when you create your 
subclass object.  Any C<path> elements specified will be searched after
those defined in the C<$PATH> package variable. 

    use My::App::Plugins;
    my $plugins = My::App::Plugins->new(
        path => 'Our::App::Plugins',
    );
    my $plugin  = $plugins->module('example');

This will load C<My::App::Plugin::Example>, C<Your::App::Plugin::Example>, 
C<Our::App::Plugin::Example> or throw an error.

=head2 Using Badger::Modules as a Singleton

You can call the L<module()> method as a class method against
C<Badger::Modules> or any subclass of it.  

    use My::App::Plugins;
    my $plugin  = My::App::Plugins->module('example');

In this case the L<module()> method fetches a singleton prototype object
to use (creating it via a call to L<new()>, if necessary).  The same prototype
object will be re-used for any subsequent class methods.

=head1 CONFIGURATION OPTIONS

=head2 path / module_path

This options allows you to specify one or more base namespaces to search
for modules.  Multiple values can be specified by reference to an array.

    # single path location
    my $modules = Badger::Modules->new(
        path => 'My::Modules',
    );

    # multiple path locations
    my $modules = Badger::Modules->new(
        path => ['My::Modules', 'Your::Modules'],
    );

The C<module_path> option is an alias for C<path>.

    my $modules = Badger::Modules->new(
        module_path => ['My::Modules', 'Your::Modules'],
    );

If the C<item> configuration option is specified then the name of the
C<module_path> option will be changed accordingly.

    # setting item to 'wibble' provides 'wibble_path' as alias to 'path'
    my $modules = Badger::Modules->new(
        item        => 'wibble',
        wibble_path => ['My::Modules', 'Your::Modules'],
    );

An C<$ITEM> package variable defined in a subclass module has the same effect.

    package My::App::Plugins;
    use base 'Badger::Modules';
    our $ITEM = 'plugin';
    1;
    
    package main;
    use My::App::Plugins;
    
    my $plugins = My::App::Plugins->new(
        plugin_path => ['My::Plugin', 'Your::Plugin'],
    );

=head2 item

This option can be used to change the name of the items that the module loads.
The default value is the generic term C<module>. You may wish to set it to
something else for the sake of having more meaningful configuration options,
error messages, etc. 

    my $modules = Badger::Modules->new(
        item        => 'wibble',
        wibble_path => ['My::Modules', 'Your::Modules'],
    );

A default value can be provided by a C<$ITEM> package variable in a subclass
of C<Badger::Modules>.

    package My::App::Plugins;
    use base 'Badger::Modules';
    our $ITEM = 'plugin';
    1;

Another effect of setting C<item> is that it allows you to specify the 
C<path> option using the item name as a prefix.

    my $modules = Badger::Modules->new(
        item        => 'plugin',
        plugin_path => ['My::App::Plugin', 'Your::App::Plugin'],
    );

This can be useful if you've got several different module loaders in an
application and want to avoid confusion between the different C<path>
configuration options.

=head2 items

This can be used to specify the correct plural form of the L<item> name for
those cases where the singular form does not pluralise regularly (where
"regularly" is defined as something that the
L<plural()|Badger::Utils/plural()> function can handle.  

    my $modules = Badger::Modules->new(
        # highly contrived example
        item  => 'attorney_general',
        items => 'attorneys_general',
    );

A default value can be provided by a C<$ITEMS> package variable in a subclass
of C<Badger::Modules>.

    package My::App::Plugins;
    use base 'Badger::Modules';
    our $ITEM  = 'attorney_general';
    our $ITEMS = 'attorneys_general';
    1;

Note that this isn't used in the base class, but some subclasses rely on it
to generate useful error messages.

=head2 names

This can be used to provide an explicit mapping for module names that may
be requested via the L<module()> method.  The default behaviour is to 
camel case module names that are separated by underscores.  For example, 
requesting a C<foo_bar> module will look for a C<FooBar> module in any of
the L<path> locations.

This work well enough for most modules, but some do not capitalise
consistently. Modules whose names contain acronyms like C<URL> are typically
prone to a dose of fail.

    $module = $modules->module('url');      # looks for XXX::Url not XXX::URL

If you specify the name in the correct capitalisation then you'll have no 
problem.

    $module = $modules->module('URL');

If like me you prefer to use case-insensitive throughout and leave it up to 
the module loader to worry about the correct capitalisation then the C<names>
option is your friend.  You can use to define any number of simple aliases
for the L<module()> method to use.

    $modules = Badger::Modules->new(
        path  => ['My::Plugin', 'Your::Plugin'],
        names => {
            url => 'URL',
            cgi => 'CGI',
            foo => 'iFoo::XS'
        }
    );

Note that the values specified in the C<names> hash array are partial module
names.  They will still be applied to the base paths specified in the C<path>
option to generate complete candidate module paths.

=head2 tolerant

This option affects what happens when a module requested via the L<module()>
method cannot be found.  In the usual case, the tolerant option is not set and
the L<module()> method will throw a "module not found: XXX" error.  If the 
C<tolerant> option is set then the method will instead return C<undef>

=head1 METHODS

=head2 new()

Constructor method to create a new C<Badger::Modules> object.  Inherited from
the L<Badger::Base> base class.

=head2 module($name)

Method to load a module identified by C<$name>.

[ROUGH DRAFT]

    * name is aliased via names lookup table

    * name is expanded to various possible capitalisations
    
    * each base namespace in path is tried...
    
    * with each name...
    
    * until one is located and loaded, in which case found() is called
      (or failed() if an error occurred while loading the module)
    
    * or we exhaust all possibilities, in which case not_found() is called.
    
=head2 modules()

This method can be used to get or set the internal mapping of names to 
modules.  It's not used at present... there's some more refactoring to be 
done with L<Badger::Factory> to sort out how this is going to work.

=head2 path()

Method to get or set the module search path.  It returns a reference to a 
list of the current search path namespaces when called without any arguments.

    my $path = $modules->path;

It can be called with arguments to set a new search path.  One or more 
modules namespaces can be specified as arguments:

    $modules->path('My::App', 'Your::App');

These can also be specified as a reference to an array.

    # either
    $modules->path(['My::App', 'Your::App']);
    
    # or
    @namespaces = ('My::App', 'Your::App');
    $modules->path(\@namespaces);

=head2 names()

=head1 INTERNAL METHODS

=head2 init_modules($config)

Internal initialisation method used to prepare newly created
C<Badger::Modules> objects. The C<init()> method is an alias to
C<init_modules()> for the default L<new()> method inherited from the
L<Badger::Base> base class to call. 

If you subclass the C<Badger::Modules> module and define your own
L<init()|Badger::Base/init()> method then it should call the C<init_modules()>
to perform the base class initialisation either before, after or in between
blocks of your own code.

    package Your::Modules;
    use base 'Badger::Modules';
    
    sub init {
        my ($self, $config) = @_;
        # your code here
        $self->init_modules($config);
        # more of your code here
        return $self;
    }

This has the same effect as calling C<$self-E<gt>SUPER::init($config)> but 
with less ambiguity in the face of multiple inheritance (usually considered
a bad thing to be avoided wherever possible) or in obscure cases where you
are monkeying around with the heritage (i.e. base classes) of a module and 
Perl can't reliably resolve the correct L<init()|Badger::Base/init()> method
at compile time.

=head2 module_names($name)

This method maps the name passed as an argument to the correct case (or
variations of case) for Perl modules.

TODO: More on this.  Method should possibly be renamed to expand_names()?

=head2 found($name,$module)

This method is called by the L<module()> method when a requested module
is found.  The implementation in the base class simply returns the module
name passed to it as the second argument.  This becomes the return value
for the successful invocation of the L<module()> method.

Subclasses may redefine this method to perform some other functionality.

=head2 not_found($name)

This method is called by the L<module()> method when a requested module cannot
be found. The default behaviour for this implementation in the base class
throws an error (via the L<error|Badger::Base/error()> method inherited from
the L<Badger::Base> base class). If the L<tolerant> configuration option is
set to a true value then it instead returns C<undef> by calling the
L<decline()|Badger::Base/decline()> method, also inherited from
L<Badger::Base>.

Subclasses may redefine this method to perform some other functionality.

=head2 failed($message)

This method is used internally to report a failure to load a module.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2010 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Factory>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
