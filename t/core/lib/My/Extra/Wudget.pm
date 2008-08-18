# used by t/core/factory.t

package My::Extra::Wudget;

use Badger::Class
    version     => 1,
    base        => 'My::Wodget';

sub name {
    return '<< ' . $_[0]->{name} . ' >>';
}

package My::Extra::Wudgetola;

use Badger::Class
    version     => 1,
    base        => 'My::Extra::Wudget';
    
sub name {
    return '** ' . $_[0]->{name} . ' **';
}

1;
