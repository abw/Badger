# test the ability to generate constants on the fly.

package My::Exporter::Generator;

use Badger::Class
    exports => {
        tags => {
            math => {
                e   => '=2.718',
                pi  => '=3.142',
                phi => '=1.618',
            }
        },
# This doesn't work.  I might make it work one day, but it requires a 
# bit of refactoring in Badger::Exporter (which is probably a good thing)
#        any => {
#            cheese   => '=Cheddar',
#            biscuits => '=Crackers',
#        },
#        all => {
#            food     => '=Nuts and Berries',
#        },
    };

    
1;
