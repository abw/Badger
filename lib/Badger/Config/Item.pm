package Badger::Config::Item;

use Badger::Debug ':dump';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    import    => 'class CLASS',
    utils     => 'blessed',
    accessors => 'name arity',
    constants => 'DELIMITER ARRAY HASH',
    constant  => {
        ARITY_ITEM => 1,
        ARITY_LIST => 2,
        ARITY_HASH => 3,
    },
    alias     => {
        init  => \&init_item,
    },
    messages  => {
        bad_type     => 'Invalid type prefix specified for %s: %s',
        bad_method   => 'Missing method for the %s %s configuration item: %s',
        dup_item     => 'Duplicate specification for scheme item: %s',
        bad_fallback => 'Invalid fallback item specified for %s: %s',
        no_value     => 'No value specified for the %s configuration item',
        no_key_value => 'No value specified for the <2> key of the <1> configuration item',
    };

our $ARITY = {
    '$' => ARITY_ITEM,
    '@' => ARITY_LIST,
    '%' => ARITY_HASH,
};

sub init_item {
    my ($self, $config) = @_;
    my ($name, @aka, $alias, $fallback, $test);

    my $fall = delete $config->{ fallback_provider } || $self;

    $self->debug("Generating config item: ", $self->dump_data($config))
        if DEBUG;

    $name = $config->{ name }
        || return $self->error_msg( missing => 'name' );
    
    # A '!' at the end of the name indicates it's mandatory.
    # A '=value' at the end indicates a default value.
    $self->{ required } = ($name =~ s/!$//)        ?  1 : $config->{ required };
    $self->{ default  } = ($name =~ s/=(\w\S*)$//) ? $1 : $config->{ default  };

    # Alternately, '=$XXX', '=@XXX' or '=%XXX' can be used to indicate that
    # the options takes one 'XXX' argument, multiple 'XXX' arguments or key
    # values/pairs where the values are 'XXX' arguments
    if ($name =~ s/=([\$\@\%])(.+)$//) {
        $self->debug("config item: $name [$1] [$2]") if DEBUG;
        $config->{ arity } = $ARITY->{ $1 };
        $config->{ args  } = $2;
    }


    # name can be 'name|alias1|alias2|...'
    ($name, @aka) = split(/\|/, $name);

    # alias can be specified as hash ref or string 
    $alias = $config->{ alias } || { };
    $alias = [ split(DELIMITER, $alias) ]
        unless ref $alias;
    $alias = { map { $_ => $name } @$alias }
        if ref $alias eq ARRAY;
    return $self->error_msg( invalid => alias => $alias )
        unless ref $alias eq HASH;
    
    # aliases, and more generally, fallbacks, can be specified as a list ref 
    # or string which we split
    $self->debug("fallback: ", $self->dump_data($config->{ fallback })) if DEBUG;

    $fallback = $config->{ fallback } || [ ];
    $fallback = [ split(DELIMITER, $fallback) ] 
        unless ref $fallback eq ARRAY;
    push(@$fallback, @aka);
    
    $self->debug("fallbacks: ", $self->dump_data($fallback)) if DEBUG;

    foreach my $item (@$fallback) {
        unless ($item =~ /:/) {
            $alias->{ $item } = $name;
            next;
        }
        my ($type, $data) = split(/:/, $item, 2);
        $item = $fall->fallback($name, $type, $data)
            || return $self->error_msg( bad_type => $name, $type );
    }
        
    # add any aliases specified as part of the name and bind them 
    # back into the field info hash
    $self->{ fallback } = $fallback;

    # this is getting way too large... but I just want to get things working
    # before I start paring things down
    $self->{ name    } = $name;
    $self->{ alias   } = $alias;
    $self->{ message } = $config->{ message } || $config->{ error };
    $self->{ action  } = $config->{ action  };
    $self->{ method  } = $config->{ method  };
    $self->{ about   } = $config->{ about   };
    $self->{ args    } = $config->{ args    };
    $self->{ arity   } = $config->{ arity   } || 0;

    $self->debug(
        "Configured configuration item: ", $self->dump
    ) if DEBUG;
    
    return $self;
}


sub fallback {
    shift->not_implemented;
}

sub names {
    my $self  = shift;
    my @names = ($self->{ name }, keys %{ $self->{ alias } });
    return wantarray
        ?  @names
        : \@names;
}


sub configure {
    my ($self, $config, $target, $class) = @_;
    my ($name, $alias, $code, @args, $ok, $value);
    
    $class ||= $target;
    
    $self->debug("configure(", CLASS->dump_data_inline($config), ')') if DEBUG;
    $self->debug("item is ", $self->dump_data($self)) if DEBUG;
#    $self->debug("items: ", CLASS->dump_data($items)) if DEBUG;
    
    $name = $self->{ name };
        
    # TODO: abstract out action calls.
    
    FALLBACK: foreach $alias ($name, @{ $self->{ fallback } || [ ] }) {
        next unless defined $alias;
        
        if (ref $alias eq ARRAY) {
            ($code, @args) = @$alias;
            #$self->todo('calling code');
            ($ok, $value) = $code->($class, $name, $config, $target, @args);
            if ($ok) {
                return $self->set($target, $name, $value, $class);
            }
        }
        elsif (defined $config->{ $alias }) {
            $self->debug("Found value for $name ($alias): $config->{ $alias }\n") if DEBUG;
            return $self->set($target, $name, $config->{ $alias }, $class);
        }
        else {
            $self->debug("Nothing found for $alias to set $name\n") if DEBUG;
        }
    }
        
    if (defined $self->{ default }) {
        $self->debug("setting to default value: $self->{ default }\n") if DEBUG;
        return $self->set($target, $name, $self->{ default }, $class);
    }
        
    if ($self->{ required }) {
        $self->debug("$name is required, throwing error\n") if DEBUG;
        return $self->error_msg( $self->{ message } || missing => $name );
    }
    
    return $self;
}


sub set {
    my ($self, $target, $name, $value, $object) = @_;
    my $method;
    
    $object ||= $target;

    $self->debug("set($target, $name, $value)") if DEBUG;

    if ($self->{ arity } == ARITY_LIST) {
        my $list = $target->{ $name } ||= [ ];
        push(@$list, $value);
    }
    elsif ($self->{ arity } == ARITY_HASH) {
        return $self->error_msg( invalid => 'key/value pair' => $value)
            unless ref $value eq ARRAY;

        my $hash = $target->{ $name } ||= { };
        $hash->{ $value->[0] } = $value->[1];
    }
    else {
        $target->{ $name } = $value;
    }

    $self->{ action }->($self, $name, $value) if $self->{ action };

    if (blessed($object) && ($method = $self->{ method })) {
        $self->debug("calling method $method on object $object\n") if DEBUG;
        $object->$method($name, $value);
    }
        
    return $self;
}


# this is being replaced by Badger::Config::Reader::Args

sub args {
    my $self = shift;
    my $args = shift;
    my $value;
    
    if ($self->{ args }) {
        $self->debug("looking for $self->{ name } arg in ", $self->dump_data($args)) if DEBUG;

        return $self->error_msg( no_value => $self->{ name } )
            unless @$args && defined $args->[0] && $args->[0] !~ /^-/;

        $value = shift @$args;

        if ($self->{ arity } == ARITY_HASH) {
            my $key = $value;
            return $self->error_msg( no_key_value => $self->{ name }, $key )
                unless @$args && defined $args->[0] && $args->[0] !~ /^-/;
            $value = shift @$args;
            $value = [ $key, $value ];
        }
    }
    else {
        $value = 1;
    }
    # this is all the wrong way around - quick hack
    return $self->configure({ $self->{ name } => $value }, @_);
}

# temporary method providing access to args value
sub has_args {
    shift->{ args };
}

sub hash_arity {
    shift->{ arity } == ARITY_HASH;
}

sub list_arity {
    shift->{ arity } == ARITY_LIST;
}

sub summary {
    my ($self, $reporter) = @_;
    my $name  = $self->{ name };
    my $args  = $self->{ args }  || '';
    my $about = $self->{ about } || '';
    if (length $args) {
        $args =~ s/\s+/> </g;
        $args = " <$args>";
    }
    return $reporter
        ? $reporter->option( $name.$args, $about )
        : sprintf('--%-20s %s', $name.$args, $about);
}
    

1;
