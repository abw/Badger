package Badger::Reporter::App;

use Badger::Class
    version   => 2.71,
    debug     => 0,
    base      => 'Badger::Reporter';

our $EVENTS = [
    {
        name    => 'credits',
        colour  => 'yellow',
        message => "<1> v<2><3| by ?><4|, ?>",
    },
    {
        name    => 'section',
        colour  => 'yellow',
        message => "\n%s:",
        summary => 0,
    },
    {
        name    => 'about',
        colour  => 'cyan',
        message => '  %s',
    },
    {
        name    => 'option',
        colour  => 'cyan',
        message => '  --%-20s %s',
    },
    {
        name    => 'info',
        colour  => 'cyan',
        message => '%s',
        summary => '',
    },
    {
        name    => 'detail',
        colour  => 'cyan',
        message => '%s',
        summary => '',
        verbose => 1,
    },
];

1;
