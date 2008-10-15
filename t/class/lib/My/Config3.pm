package My::Config3;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    accessors => 'username password driver',
    config    => {
        username => {
            fallback => ['user', 'pkg:USERNAME', 'env:MY_USERNAME'],
            required => 1,
        },
        password => {
            fallback => ['pass', 'class:PASSWORD', 'env:MY_PASSWORD'],
            required => 1,
        },
        driver => {
            fallback => ['env:MY_DRIVER', 'pkg:DRIVER'],
        },
    };

our $PASSWORD = 'top_secret';

sub init {
    shift->configure(@_);
}


1;
