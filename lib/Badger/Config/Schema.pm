package Badger::Config::Schema;

use Badger::Debug ':dump';
use Badger::Config::Item;
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    import    => 'class CLASS',
    words     => 'CONFIG_SCHEMA',
    utils     => 'is_object',
#    accessors => 'items',
    constants => 'HASH ARRAY DELIMITER',
    constant  => {
        CONFIG_METHOD => 'configure',
        CONFIG_ITEM   => 'Badger::Config::Item',
        VALUE         => 1,
        NOTHING       => 0,
    },
    messages => {
        bad_type     => 'Invalid type prefix specified for %s: %s',
        bad_method   => 'Missing method for the %s %s configuration item: %s',
        dup_item     => 'Duplicate specification for scheme item: %s',
        bad_fallback => 'Invalid fallback item specified for %s: %s',
    };

sub init {
    my ($self, $config) = @_;
    $self->init_schema($config);
    return $self;
}

sub init_schema {
    my ($self, $config) = @_;
    my $iclass = $self->CONFIG_ITEM;
    my ($name, $info, @aka, $fallback, $test, $item);

    my $fall = $config->{ fallback } || $self;
    my $list = $self->{ items } = [ ];
    my $hash = $self->{ item  } = { };
    
    my $schema = $config->{ schema };
    my $extend = $config->{ extend };
    
    $self->debug("fallback is $fall") if DEBUG;
    # allow target class to be specified so we can resolve things like
    # package variables later
#    $self->{ class } = $config->{ class } || $config->{ target };
    
#    $self->debug("extending on from ", $self->dump_data($extend));

    $self->debug("Generating schema from config: ", $self->dump_data($config))
        if DEBUG;

    # We allow a scheme to be specified as a list reference in case the 
    # order of evaluation is important.  For convenience, we also accept
    # a hash ref for a schema specification where the order isn't important.
    # The values in the hash array can themselves be hash references or 
    # simple values which we assume is the default value.
    $schema = [ 
        map { 
            my $k = $_;
            my $v = $schema->{ $k };
            ref $v eq HASH
                ? { name => $k, %$v } 
                : { name => $k, default => $v }
        } 
        keys %$schema
    ] if ref $schema eq HASH;

    $schema = [ @$schema, $extend ? @$extend : () ];

    $self->debug("Canonical schema config: ", $self->dump_data($schema))
        if DEBUG;

    while (@$schema) {
        $name = shift @$schema;
        $item = undef;
        $info = undef;
        
        # TODO: not sure about this - we change the name....
        # skip anything we've already done  
        
        $self->debug("schema item: $name\n") if DEBUG;

        if (ref $name eq HASH) {
            $info = $name;
            $name = $info->{ name }
                || return $self->error("Invalid hash (no name): ", $self->dump_data($info));
        }
        elsif (is_object(CONFIG_ITEM, $name)) {
            $item = $name;
            $name = $item->name;
        }
        else {
            $info = { name => $name };
        }
        $self->debug("name: $name   info: $info") if DEBUG;

        $info->{ fallback_provider } ||= $fall;

        $item ||= $self->CONFIG_ITEM->new($info);
        $name = $item->name;
        
        next if $hash->{ $name };
        
        $self->debug("generated item: $item") if DEBUG;

        foreach my $alias ($item->names) {
#            return $self->error_msg( dup_item => $name )
#                if $hash->{ $name };
            $hash->{ $alias } = $item;
        }
        $self->debug("adding $name => $item to schema") if DEBUG;
        push(@$list, $item);
    }
    
    $self->debug("created schema: ", $self->dump_data($self->{ items }))
        if DEBUG;

    return $self;
}


sub fallback {
    my ($self, $name, $type, $data) = @_;
    return $self->error_msg( bad_fallback => $name, $type );
}


sub configure {
    my ($self, $config, $target, $class) = @_;
    my $items = $self->{ items };
    my ($element, $name, $alias, $code, @args, $ok, $value);
    
    $class ||= $target;
    
    $self->debug("configure(", CLASS->dump_data_inline($config), ')') if DEBUG;
    $self->debug("configure element: ", CLASS->dump_data($items)) if DEBUG;
    
    ELEMENT: foreach $element (@$items) {
#        $name = $element->{ name };
        $element->configure($config, $target, $class);
    }
    
    return $self;
}


sub item {
    my $self = shift;
    my $item = $self->{ item };
    return @_
        ? $item->{ $_[0] }
        : $item;
}

sub items {
    my $self  = shift;
    my $items = $self->{ items };
    return wantarray
        ? @$items
        :  $items;

    
}

1;
