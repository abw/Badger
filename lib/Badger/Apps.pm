package Badger::Apps;

use Badger::Factory::Class
    version   => 0.01,
    debug     => 0,
    item      => 'app';


sub found_module {
    my ($self, $type, $module, $args) = @_;
    $self->debug("Found module: $type => $module") if DEBUG;
    $self->{ loaded }->{ $module } ||= class($module)->load;
    return $module;
}

sub not_found {
    my ($self, $type, @args) = @_;
    return $self->decline_msg( not_found => $self->{ item }, $type );
}


1;