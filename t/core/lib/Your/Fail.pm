# broken module loaded by modules.t test

package Your::Fail;

# Oh Noes!  
use Some::Module::Which::Hopefully::Does::Not::Exist;

1;
