package My::Vars7;

use Badger::Class
    vars => {
        X      => 1,
        Y      => [2, 3],
        Z      => { a => 99 },
        HAI    => sub { 'Hello ' . (shift || 'World') },
        '$FOO' => 25,
        '$BAR' => [11, 21, 31],
        '$BAZ' => { wam => 'bam' },
        '$BAI' => sub { 'Goodbye ' . (shift || 'World') },
        '@WIZ' => [100, 200, 300],
        '@WAZ' => 99,
        '%WOZ' => { ping => 'pong' },
    };


1;
