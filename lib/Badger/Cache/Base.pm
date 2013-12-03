package Badger::Cache::Base;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base';

sub get {
    shift->not_implement('in base class');
}

sub set {
    shift->not_implement('in base class');
}

1;
