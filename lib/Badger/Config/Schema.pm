package Badger::Config::Schema;

use Badger::Debug ':dump';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    import    => 'class CLASS',
    words     => 'CONFIG_SCHEMA',
    accessors => 'items',
    constants => 'HASH ARRAY DELIMITER',
    constant  => {
        CONFIG_METHOD => 'configure',
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
    my ($name, $info, @aka, $fallback, $test);

    my $fall = $config->{ fallback } || $self;
    my $list = $self->{ items } = [ ];
    my $hash = $self->{ item  } = { };
    
    my $schema = $config->{ schema };
    my $extend = $config->{ extend };
    
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

    $self->debug("Canonical schema config: ", $self->dump_data($config))
        if DEBUG;

    $schema = [ @$schema, $extend ? @$extend : () ];
        
    while (@$schema) {
        $name = shift @$schema;
        
        # TODO: not sure about this
        # skip anything we've already done  
        next if $hash->{ $name };
        
        $self->debug("schema item: $name\n") if DEBUG;
        
        if (ref $name eq HASH) {
            $info = $name;
            $name = $info->{ name }
                || return $self->error("Invalid hash (no name): ", $self->dump_data($info));
        }
        else {
            $info = { };
        }
        $self->debug("name: $name   info: $info") if DEBUG;
        
        $info->{ required } = 1 
            if $name =~ s/!$//;
            
        $info->{ default } = $1
            if $name =~ s/=(\S+)$//;

        # name can be 'name|alias1|alias2|...'
        ($name, @aka) = split(/\|/, $name);
        
        # $info is now a hash ref
        $info->{ name } = $name;

        # always do this because we may have stripped stuff off the name
#            unless defined $info->{ name };

        # aliases can be specified as a list ref or string which we split
        $fallback = $info->{ fallback } || [];
        $fallback = [ split(DELIMITER, $fallback) ]
            unless ref $fallback eq ARRAY;
        push(@$fallback, @aka);

        foreach my $item (@$fallback) {
            unless ($item =~ /:/) {
                $info->{ alias }->{ $item } = $name;
                next;
            }
            my ($type, $data) = split(/:/, $item, 2);
            $item = $fall->fallback($name, $type, $data)
                || return $self->error_msg( bad_type => $name, $type );
        }
        
        # add any aliases specified as part of the name and bind them 
        # back into the field info hash
        $info->{ fallback } = $fallback;

        $self->debug("Adding config schema element for $name: ", $self->dump_data($info)) if DEBUG;

        foreach my $alias ($name, keys %{ $info->{ alias } || { } }) {
#            return $self->error_msg( dup_item => $name )
#                if $hash->{ $name };
            $hash->{ $alias } = $info;
        }
        push(@$list, $info);
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
    $self->debug("items: ", CLASS->dump_data($items)) if DEBUG;
    
    ELEMENT: foreach $element (@$items) {
        $name = $element->{ name };
        
        FALLBACK: foreach $alias ($name, @{ $element->{ fallback } || [ ] }) {
            next unless defined $alias;
            if (ref $alias eq ARRAY) {
                ($code, @args) = @$alias;
                ($ok, $value) = $code->($class, $name, $config, $target, @args);
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
#                $self->debug("Nothing found for $alias to set name in ", $self->dump_data($config));
            }
        }
        
        if (exists $element->{ default }) {
            $self->debug("setting to default value: $element->{ default }\n") if DEBUG;
            $target->{ $name } = $element->{ default };
            next ELEMENT;
        }
        
        if ($element->{ required }) {
            $self->debug("$name is required, throwing error\n") if DEBUG;
            return $self->error_msg( $element->{ error } || missing => $name );
        }
        $self->debug("$name is not required, continuing\n") if DEBUG;
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

1;