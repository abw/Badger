package My::Mixin::Baz;

use Badger::Class
    base     => 'Badger::Mixin My::Mixin::Foo My::Mixin::Bar',
    mixins   => 'plop';
#    mixin    => 'My::Mixin::Foo My::Mixin::Bar';

sub plop { 'Plop!' }

1;
