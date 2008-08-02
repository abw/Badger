package My::Class;

use Badger::Class
    version  => 3.14,
    base     => 'Badger::Class',
    constant => {
        CONSTANTS => 'My::Constants',
    };
    
1;
