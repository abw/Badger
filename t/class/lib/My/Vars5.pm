package My::Vars5;

use Badger::Class
    vars => '$FOO @BAR %BAZ';

$FOO = 'fourteen';
@BAR = (14, 24, 34);
%BAZ = (g => 310, h => 420);

1;
