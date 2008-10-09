package My::Vars6;

use Badger::Class
    vars => {
        '$FOO' => 'fifteen',
        '@BAR' => [15, 25, 35],
        '%BAZ' => {i => 310, j => 420},
    };


1;
