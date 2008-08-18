# test module which gets autoloaded into the hub.  See t/core/hub.t
# also used by t/core/factory.t

package My::Widget;

use Badger::Class
    version => 1,
    base    => 'Badger::Base';

1;
