package My::Config2;

use strict;
use warnings;
use base 'Badger::Base';
use Badger::Class::Methods
    get => 'username password';
use Badger::Class::Config 
    username => {
        fallback => ['user', 'pkg:USERNAME', 'env:MY_USERNAME'],
        required => 1,
    },
    password => {
        fallback => ['pass', 'pkg:PASSWORD', 'env:MY_PASSWORD'],
        required => 1,
    },
    driver => {
        fallback => ['env:MY_DRIVER', 'pkg:DRIVER'],
    };

sub init {
    shift->configure(@_);
}


1;
