package My::Config5;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'My::Config4',
    accessors => 'cat dog',
    config    => [
        'cat|pussy=felix',
        { 
            name     => 'dog',
            fallback => 'hound',
            aliases  => ['hound'],
            default  => 'rover',
        },
    ],
    constant  => {
        VOLUME => 11,
    };
    

1;
