package Badger::Data::Facet::Class;

use Carp;
use Badger::Data::Facets;
use Badger::Class
    version    => 0.01,
    debug      => 0,
    uber       => 'Badger::Class',
    utils      => 'camel_case',
    constants  => 'DELIMITER ARRAY',
    constant   => {
        FACETS => 'Badger::Data::Facets',
        FACET  => 'Badger::Data::Facet',
    },
    hooks      => {
        type   => \&type,
        args   => \&args,
        opts   => \&opts,
    };


sub type {
    my ($self, $type) = @_;
    my $facet = $self->FACETS->prototype->find($type)
        || croak "Invalid facet type: $type\n";
#    print "Facet::Class facet: $type => $facet\n";
    $self->base($facet);
}


sub args {
    my ($self, $args) = @_;
    
    $args = [ split(DELIMITER, $args) ]
        unless ref $args eq ARRAY;
        
    $self->var( ARGS => $args );
    $self->mutators($args);
}


sub opts {
    my ($self, $opts) = @_;

    $opts = [ split(DELIMITER, $opts) ]
        unless ref $opts eq ARRAY;

    $self->var( OPTS => $opts );
    $self->mutators($opts);
}


1;
