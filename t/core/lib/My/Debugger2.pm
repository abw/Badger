# test module used by t/core/debug.t

package My::Debugger2;

use Badger::Debug
    default => 0; 

sub wibble {
    my ($self, $value) = @_;
    return DEBUG        
        ? 'debugging wibble'
        : 'normal wibble';
}

sub wobble {
    my ($self, $value) = @_;
    return $DEBUG        
        ? 'debugging wobble'
        : 'normal wobble';
}

sub hello {
    shift->debug("Hello world");
}


1;
