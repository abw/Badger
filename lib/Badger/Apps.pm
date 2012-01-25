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

=head1 NAME

Badger::Apps - factory module for application modules

=head1 DESCRIPTION

This module implements a subclass of L<Badger::Factory> for loading and
instantiating L<Badger::App> application modules.

=head1 METHODS

The following methods are defined in addition to those inherited from the 
L<Badger::Factory> and L<Badger::Base> base classes.

=head2 found_module($type, $module, @args)

=head2 not_found($type, @args)

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008-2012 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Factory>,
L<Badger::Base>.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

