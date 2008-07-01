package Badger;

use 5.8.0;
use Badger::Hub;
use Badger::Class
    debug   => 0,
    base    => 'Badger::Base',
    utils   => 'UTILS',
    import  => 'class',
    words   => 'HUB';

our $VERSION = 0.01;
our $HUB     = 'Badger::Hub';
our $AUTOLOAD;

sub init {
    my ($self, $config) = @_;
    my $hub = $config->{ hub } || $self->class->any_var(HUB);
    unless (ref $hub) {
        UTILS->load_module($hub);
        $hub = $hub->new($config);
    }
    $self->{ hub } = $hub;
    return $self;
}

sub hub {
    my $self = shift;

    if (ref $self) {
        return @_
            ? ($self->{ hub } = shift)
            :  $self->{ hub };
    }
    else {
        return @_
            ? $self->class->var(HUB => shift)
            : $self->class->var(HUB)
    }
}

1;

__END__

=head1 NAME

Badger - application programming toolkit

=head1 SYNOPSIS

    use Badger;
	
    # forage for nuts and berries in the forest
    
=head1 DESCRIPTION

TODO

=head1 METHODS

TODO

=head1 AUTHOR

Andy Wardley  E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:



