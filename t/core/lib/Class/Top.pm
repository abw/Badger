package Class::Top;

use Badger::Class
    version => 3.00,
    base    => 'Class::Middle',
    debug   => 0;

sub top {
    return "on the top";
}

1;
