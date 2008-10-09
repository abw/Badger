package My::Vars3;

use Badger::Class::Vars {
    '$FOO' => 'twelve',
    '@BAR' => [12, 22, 32],
    '%BAZ' => {c => 310, d => 420},
};


1;
