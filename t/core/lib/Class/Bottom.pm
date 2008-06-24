package Class::Bottom;

use Badger::Class
    version => 3.00,
    base    => 'Badger::Base',
    debug   => 0;

sub bottom {
    return "on the bottom";
}

1;
