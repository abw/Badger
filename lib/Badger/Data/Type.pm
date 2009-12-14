#========================================================================
#
# Badger::Data::Type
#
# DESCRIPTION
#   Base class data type.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Data::Type;

use Badger::Data::Facets;
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    import    => 'CLASS',
    accessors => 'base namespace facets',
    constants => 'CODE DOT',
    as_text   => 'name',
    is_true   => 1,
    constant  => {
        type    => '',
        simple  => 0,
        complex => 0,
#       CLAUSES => 'Badger::Data::Clauses',
        FACETS  => 'Badger::Data::Facets',
    },
    alias     => {
        init  => \&init_type,
    };

use Badger::Debug ':dump';


our @PARAMS = qw( base name namespace );

sub init_type {
    my ($self, $config) = @_;

    # copy in basic parameters
    @$self{ @PARAMS } = @$config{ @PARAMS };

    # constraint the type with any validation facets defined
    $self->constrain( 
        $self->class->list_vars( FACETS => $config->{ facets } )
    );
    return $self;
}


sub name {
    my $self = shift;
    return $self->{ name } ||= do {
        my $pkg  = ref $self || $self;
        my $base = CLASS;
        $pkg =~ s/${base}:://g;
        $pkg =~ s/::/./g;
        $pkg;
    };
}


sub constrain {
    my ($self, @args) = @_;
    my $FACETS = $self->FACETS;
    my $facets = $self->{ facets } ||= [ ];
    my $type   = $self->type;
    my ($name, $value);

    $self->debug("preparing facets: ", $self->dump_data($facets)) if DEBUG;

    while (@args) {
        $name = shift(@args);
        $self->debug("preparing facet: $name") if DEBUG;
        push(
            @$facets, 
            ref $name eq CODE 
                ? $name
                : $FACETS->facet(
                      # prepend the basic type (e.g. length => text.length)
                      # unless type and facet are the same (e.g. text => text)
                      ($type eq $name) ? $type : ($type ? $type.DOT.$name : $name),
                      shift(@args)
                  )
        );
    }

    $self->debug("constrained type with facets: ", $self->dump_data($facets), "\n")
        if DEBUG;
}


sub validate {
    my ($self, $value) = @_;

    foreach my $facet (@{ $self->{ facets } }) {
        $self->debug("validating facet: $facet with value: $value") if DEBUG;
        ref $facet eq CODE 
            ? $facet->($value, $self)               # TODO: this should be passed as refs...
            : $facet->validate($value, $self);
    }
    return $value;
}


sub JUST_TESTING_clause {
    my $self    = shift;
    my $type    = shift;
    my $clauses = $self->CLAUSES;
    $clauses->clause(
        $type, 
        $self, 
        map { ref $_ ? $_ : $clauses->clause( literal => $_ ) } 
        @_
    );
}


1;

__END__

=head1 NAME

Badger::Data::Type - base class data type

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

TODO

=head1 METHODS

TODO

=head1 PACKAGE VARIABLES

TODO

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2009 Andy Wardley.  All Rights Reserved.

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
