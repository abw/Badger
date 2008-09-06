# test module used by t/core/debug.t

# The DEBUG import hook in Badger::Debug defines a DEBUG constant.
# In this case, we define the default value to be 0.  However, that
# default can be over-ridden by defining $My::Debugger::DEBUG before
# loading the module.  The benefit of this approach is that the DEBUG
# constant will be resolved at compile time so that there is no overhead
# for statements like: $self->debug(...) if DEBUG;

package My::Debugger1;

use Badger::Debug
    DEBUG => 0; 

sub wibble {
    my ($self, $value) = @_;
    return DEBUG        
        ? 'debugging wibble'
        : 'normal wibble';
}

1;
