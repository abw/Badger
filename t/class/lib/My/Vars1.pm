package My::Vars1;

use strict;
use warnings;
use Badger::Class::Vars '$FOO @BAR %BAZ';

$FOO = 'ten';
@BAR = (10, 20, 30);
%BAZ = (x => 100, y => 200);

1;
