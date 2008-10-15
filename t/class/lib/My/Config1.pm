package My::Config1;

use strict;
use warnings;
use base 'Badger::Base';
use Badger::Class::Config 
    'username|user! password|pass!';
use Badger::Class::Methods
    get => 'username password';

sub init {
    shift->configure(@_);
}


1;
