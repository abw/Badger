package Badger::Schema;

use Badger::Debug ':dump';
use Badger::Schema::Fields;
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    import    => 'class',
#    accessors => 'fields',
    constants => 'HASH DELIMITER',
    constant  => {
        SCHEMA  => __PACKAGE__,
        FACTORY => 'Badger::Schema::Fields',
    },
    exports   => {
        any     => 'SCHEMA Schema',
    },
    messages  => {
        bad_fields => 'Invalid fields specified: %s',
        bad_field  => 'Invalid field specification for %s: %s',
    };
    
    
sub Schema {
    __PACKAGE__->new(@_);
}


sub init {
    my ($self, $config) = @_;
    my $class = $self->class;
    
    $self->{ fields } = { };
    $self->{ names  } = { };
    
    # initialise fields with those defined in $FIELDS package vars and/or
    # fields defined in $config
    $self->fields( 
        $class->hash_vars( 
            FIELDS => $config->{ fields } 
        )
    );
    
    return $self;
}

sub fields {
    my $self = shift;

    return $self->{ fields }
        unless @_;

    my $factory = $self->FACTORY;
    my $fields  = $self->{ fields };
    my $names   = $self->{ names  };
    my $addons  = @_ == 1 ? shift : { @_ };
    my ($name, $info, $alias);
    
    if (! ref $addons) {
        # text string of one or more field names
        $addons = {
            map { $_ => { } }
            split DELIMITER, $_[0]
        };
    }
    elsif (ref $addons ne HASH) {
        return $self->error_msg( bad_fields => $addons );
    }

    # $addons is now a hash ref
    
    $self->debug("Adding fields: ", $self->dump_data($addons)) if DEBUG;
    
    while (($name, $info) = each %$addons) {
        # $info can be:
        #    0      optional argument (default)
        #    1      mandatory argument
        #    type   e.g. text, num, date, etc.
        #    {...}  hash of info
        if (ref $info eq HASH) {
            # ok
        }
        elsif (ref $info) {
            # can't handle any other references yet
            return $self->error_msg( bad_field => $name, $info );
        }
        elsif ($info eq '1') {
            $info = { required => 1 };
        }
        elsif ($info eq '0') {
            $info = { };                    # optional
        }
        else {
            $info = { type => $info };
        }

        # $info is now a hash ref
        $info->{ name } = $name
            unless defined $info->{ name };

        my $field = $factory->field($info);
        
        $self->debug("Adding field: ", $self->dump_data($info)) if DEBUG;

        # add primary entry
        $fields->{ $name } = $names->{ $name } = $info;
        
        # add any aliases to name lookup
        if ($info->{ aliases }) {
            foreach $alias (split DELIMITER, $info->{ aliases }) {
                $names->{ $alias } = $info;
                $self->debug("alias $alias => $name") if DEBUG;
            }
        }
    }
    
    return $fields;
}


1;



