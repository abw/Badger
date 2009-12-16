package Badger::Config::Item;

use Badger::Debug ':dump';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    import    => 'class CLASS',
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

    $self->{ name    } = $name;
    $self->{ alias   } = $alias;
    $self->{ message } = $config->{ message } || $config->{ error };

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
        
    FALLBACK: foreach $alias ($name, @{ $self->{ fallback } || [ ] }) {
        next unless defined $alias;
        
        if (ref $alias eq ARRAY) {
            ($code, @args) = @$alias;
            #$self->todo('calling code');
            ($ok, $value) = $code->($class, $name, $config, $target, @args);
            if ($ok) {
                $target->{ $name } = $value;
                return $self;
            }
        }
        elsif (defined $config->{ $alias }) {
            $self->debug("Found value for $name ($alias): $config->{ $alias }\n") if DEBUG;
            $target->{ $name } = $config->{ $alias };
            return $self;
        }
        else {
            $self->debug("Nothing found for $alias to set $name\n") if DEBUG;
        }
    }
        
    if (defined $self->{ default }) {
        $self->debug("setting to default value: $self->{ default }\n") if DEBUG;
        $target->{ $name } = $self->{ default };
        return $self;
    }
        
    if ($self->{ required }) {
        $self->debug("$name is required, throwing error\n") if DEBUG;
        return $self->error_msg( $self->{ message } || missing => $name );
    }
    
    return $self;
}



1;