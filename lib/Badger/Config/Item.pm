package Badger::Config::Item;

use Badger::Debug ':dump';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    import    => 'class CLASS',
    utils     => 'blessed',
    accessors => 'name',
    constants => 'DELIMITER ARRAY HASH',
    alias     => {
        init  => \&init_item,
    },
    messages  => {
        bad_type     => 'Invalid type prefix specified for %s: %s',
        bad_method   => 'Missing method for the %s %s configuration item: %s',
        dup_item     => 'Duplicate specification for scheme item: %s',
        bad_fallback => 'Invalid fallback item specified for %s: %s',
        no_value     => 'No value specified for the %s configuration item',
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
    $self->{ required } = ($name =~ s/!$//)      ?  1 : $config->{ required };
    $self->{ default  } = ($name =~ s/=(\S+)$//) ? $1 : $config->{ default  };

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
    
    $target->{ $name } = $value;
    $self->{ action }->($self, $name, $value) if $self->{ action };

    if (blessed($object) && ($method = $self->{ method })) {
        $self->debug("calling method $method on object $object\n") if DEBUG;
        $object->$method($name, $value);
    }
        
    return $self;
}

     
sub args {
    my $self = shift;
    my $args = shift;
    my $value;
    
    if ($self->{ args }) {
        $self->debug("looking for $self->{ name } arg in ", $self->dump_data($args)) if DEBUG;
        return $self->error_msg( no_value => $self->{ name } )
            unless @$args && defined $args->[0] && $args->[0] !~ /^-/;
        $value = shift @$args;
    }
    else {
        $value = 1;
    }
    # this is all the wrong way around - quick hack
    return $self->configure({ $self->{ name } => $value }, @_);
}

sub summary {
    my ($self, $reporter) = @_;
    my $name  = $self->{ name };
    my $args  = $self->{ args }  || '';
    my $about = $self->{ about } || '';
    $args = " <$args>" if length $args;
    return $reporter
        ? $reporter->option( $name.$args, $about )
        : sprintf('--%-20s %s', $name.$args, $about);
}
    

1;