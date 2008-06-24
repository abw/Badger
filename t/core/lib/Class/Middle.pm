package Class::Middle;

use Badger::Class
    version => 3.00,
    base    => 'Class::Bottom',
    debug   => 0;

sub middle {
    return "in the middle";
}

1;
