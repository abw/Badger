package My::Vars4;

use strict;
use warnings;
use Badger::Class::Vars ['$FOO', '@BAR', '%BAZ'];

$FOO = 'thirteen';
@BAR = (13, 23, 33);
%BAZ = (e => 310, f => 420);

1;
