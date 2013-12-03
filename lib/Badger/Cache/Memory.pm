package Badger::Cache::Memory;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Cache::Base',
    utils     => 'Now Duration';


sub init {
    my ($self, $config) = @_;
    $self->{ cache   } = { };
    $self->{ expires } = { };
    return $self;
}

sub set {
    my ($self, $uri, $data, $expires) = @_;
    $self->{ cache }->{ $uri } = $data;

    if ($expires) {
        my $duration = Duration($expires);
        my $expiry   = Now->adjust( seconds => $duration->seconds );
        $self->debug("$uri expires in $duration at $expiry") if DEBUG;
        $self->{ expires }->{ $uri } = $expiry;
    }
}

sub get {
    my ($self, $uri) = @_;
    my $data    = $self->{ cache   }->{ $uri } || return;
    my $expires = $self->{ expires }->{ $uri } || return $data;

    if (Now->after($expires)) {
        $self->debug("$uri has expired (at $expires)");
        delete $self->{ cache   }->{ $uri };
        delete $self->{ expires }->{ $uri };
        $data = undef;
    }
    else {
        $self->debug("$uri has not expired in cache (expires: $expires)") if DEBUG;
    }

    return $data;
}


1;
