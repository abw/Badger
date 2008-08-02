package My::Mixin::Foo;

use Badger::Class
    base     => 'Badger::Mixin',
    mixins   => 'wam bam';

sub wam { 'Wam!' }
sub bam { 'Bam!' }

1;
