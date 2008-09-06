# test module used by t/core/debug.t

package My::Debugger3;

use Badger::Debug
    default => 0;

sub debug_static_status {
    return DEBUG ? 'on' : 'off';
}

sub debug_dynamic_status {
    return $DEBUG ? 'on' : 'off';
}

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

1;
