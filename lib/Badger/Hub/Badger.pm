#========================================================================
#
# Badger::Hub::Badger
#
# DESCRIPTION
#   Custom Badger::Hub for accessing other Badger components.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Hub::Badger;

use Badger::Debug ':dump';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Hub';

use Badger::Config;
our $CONFIG     = 'Badger::Config';
our $COMPONENTS = {
    pod        => 'Badger::Pod',
    codecs     => 'Badger::Codecs',
    filesystem => 'Badger::Filesystem',
};
our $DELEGATES  = { 
    file      => 'filesystem',      # hub->file ==> hub->filesystem->file
    directory => 'filesystem',
    dir       => 'filesystem',
    codec     => 'codecs',
    pod       => 'pod',
};


1;
__END__

=head1 NAME

Badger::Hub::Badger - central hub for accessing Badger components

=head1 SYNOPSIS

    use Badger::Hub::Badger;
    
    # do the happy badger dance!

=head1 DESCRIPTION

The L<Badger::Hub> module implements a generic object which provides access
to other components in an application.  The C<Badger::Hub::Badger> module 
is an eating-your-own-dog-food subclass module for the C<Badger::*> modules.

=head1 COMPONENT METHODS

=head2 codecs()

Loads, instantiates and returns a L<Badger::Codecs> object.

=head2 filesystem()

Loads, instantiates and returns a L<Badger::Filesystem> object.

=head2 pod()

Loads and returns a C<Badger::Pod> object. This is a work in progress
so it's almost certainly not installed on your machine.  Sorry about that.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
