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
    utils     => 'plural',
    words     => 'ITEM ITEMS ISA',
    constants => 'PKG ARRAY HASH REFS ONCE',
    constant  => {
        FOUND_REF    => 'found_ref',
        PATH_SUFFIX  => '_PATH',
    },
    messages  => {
        no_item => 'No item(s) specified for factory to manage',
        bad_ref => 'Invalid reference for %s factory item %s: %s',
    };

our %LOADED;

sub init {
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

    $path = $config->{ path };
    $path = [ $path ] if $path && ref $path ne ARRAY;
    $self->{ path   } = $class->list_vars(uc $item . PATH_SUFFIX, $path);
    $self->{ $items } = $class->hash_vars(uc $items, $config->{ $items });
    $self->{ items  } = $items;
    $self->{ item   } = $item;
    
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
    
    # massage $type to a canonical form
    my $name = lc $type;
       $name =~ s/\W//g;
    my $item = $items->{ $name };
    my $iref;
    
    # TODO: add $self to $config - but this breaks if %$config check
    # in Badger::Codecs found_ref_ARRAY
    
    if (! defined $item) {
        # we haven't got an entry in the $CODECS table so let's try 
        # autoloading some modules using the $CODEC_B
        $item = $self->load($type)
            || return $self->error_msg( not_found => $self->{ item }, $type );
        $item = $item->new(@args);
    }
    elsif ($iref = ref $item) {
        my $method 
             = $self->can(FOUND_REF . '_' . $iref)
            || $self->can(FOUND_REF)
            || return $self->error_msg( bad_ref => $self->{ item }, $type, $iref );
            
        $item = $method->($self, $item, @args) 
            || return;
    }
    else {
        # otherwise we load the module and create a new object
        class($item)->load unless $LOADED{ $item }++;
        $item = $item->new(@args);
    }

    return $self->found( $name => $item );
#    return $item;
}

sub type_args {
    my $self   = shift;
    my $type   = shift;
    my $params = @_ && ref $_[0] eq HASH ? shift : { @_ };
    $params->{ $self->{ items } } ||= $self;
    return ($type, $params);
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
            # package name is actually Badger::Codec::Foo
            return $module 
                if ($loaded || class($module)->maybe_load && ++$loaded)
                && @{ $module.PKG.ISA };
        }
    }
    return $self->error_msg( not_found => $self->{ item } => $type );
}

sub found_ref_ARRAY {
    my ($self, $item, $config) = @_;
    
    # default behaviour for handling a factory entry that is an ARRAY
    # reference is to assume that it is a [$module, $class] pair
    
    class($item->[0])->load unless $LOADED{ $item->[0] }++;
    return $item->[1]->new($config);
}

sub found {
    return $_[2];
}


1;