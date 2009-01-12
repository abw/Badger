package My::Config5;

use Badger::Class
    version   => 0.01,
    debug     => 1,
    base      => 'My::Config4',
    accessors => 'cat dog feline',
    config    => [
        'cat|pussy=felix',
        { 
            name     => 'dog',
            fallback => 'hound',
            aliases  => ['hound'],
            default  => 'rover',
        },
        'feline|target:cat',
    ],
    constant  => {
        VOLUME => 11,
    };
    

1;
