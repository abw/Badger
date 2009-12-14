package Badger::Data::Type::Class;

use Badger::Debug ':dump';
use Badger::Class
    version    => 0.01,
    debug      => 0,
    uber       => 'Badger::Class',
#    words      => 'FACETS',
    constants  => 'ARRAY DELIMITER',
    hooks      => {
        type   => \&type,
        size   => \&size,
        facets => \&facets,
    };


sub type {
    my ($self, $type) = @_;
    $self->debug("set type to $type") if DEBUG;
    $self->method( type => $type );
}


sub size {
    my ($self, $size) = @_;
    $self->debug("set size to $size") if DEBUG;
    $self->method( size => $size );
}


sub facets {
    my ($self, $facets) = @_;
    my $current = $self->var_default( FACETS => [ ] );

    foreach ($facets, $current) {
        $_ = [ split DELIMITER ]
            unless ref eq ARRAY;
    }

    push(@$current, @$facets);
    
    $self->debug("merged facets are ", $self->dump_data($facets)) if DEBUG;
    
    $self->var( FACETS => $current );
}


1;
