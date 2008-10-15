package My::Config4;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'My::Config3',
    accessors => 'extra volume colour',
    config    => 'extra|class:EXTRA volume|method:VOLUME=10 colour=black',
    constant  => {
        VOLUME => undef,
    };
    
our $EXTRA = 'read all about it';

sub init {
    shift->configure(@_);
}


1;
