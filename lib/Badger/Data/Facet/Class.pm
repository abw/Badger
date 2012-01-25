package Badger::Data::Facet::Class;

use Carp;
use Badger::Data::Facets;
use Badger::Class
    version    => 0.01,
    debug      => 0,
    uber       => 'Badger::Class',
    utils      => 'camel_case',
    constants  => 'DELIMITER ARRAY',
    constant   => {
        FACETS => 'Badger::Data::Facets',
        FACET  => 'Badger::Data::Facet',
    },
    hooks      => {
        type   => \&type,
        args   => \&args,
        opts   => \&opts,
    };


sub type {
    my ($self, $type) = @_;
    my $facet = $self->FACETS->prototype->find($type)
        || croak "Invalid facet type: $type\n";
    $self->base($facet);
}


sub args {
    my ($self, $args) = @_;
    
    $args = [ split(DELIMITER, $args) ]
        unless ref $args eq ARRAY;
        
    $self->var( ARGS => $args );
    $self->mutators($args);
}


sub opts {
    my ($self, $opts) = @_;

    $opts = [ split(DELIMITER, $opts) ]
        unless ref $opts eq ARRAY;

    $self->var( OPTS => $opts );
    $self->mutators($opts);
}


1;
__END__

=head1 NAME

Badger::Data::Facet::Class - metaprogramming module for data facet classes

=head1 SYNOPSIS

    package Badger::Data::Facet::Text::Example;

    use Badger::Data::Facet::Class
        version   => 0.01,
        type      => 'text',        # base data type
        args      => 'foo bar',     # mandatory arguments
        opts      => 'baz bam';     # optional arguments

=head1 DESCRIPTION

This module implements a subclass of L<Badger::Class> for creating data
validation facets.

=head1 METHODS

This module implements the following methods in addition to those inherited 
from the L<Badger::Class> base class.

=head2 type($type)

This method implements the C<type> import hook for specifying the base data
type for a validation facet.

=head2 args($args)

This method implements the C<args> import hook for specifying the mandatory
configuration arguments for a validation fact.

=head2 opts($opts)

This method implements the C<opts> import hook for specifying the optional
configuration arguments for a validation facet.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008-2012 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Base>,
L<Badger::Data::Facet>.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
