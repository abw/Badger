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


sub _JUST_TESTING_clause {
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

Badger::Data::Type - base class for data types

=head1 DESCRIPTION

This module implements a base class for data types.

=head1 CONFIGURATION OPTIONS

=head2 name

An optional name for the data type. 

=head2 namespace

An optional namespace for the data type.

=head2 base

An optional base data type.

=head2 facets

An optional list of validation facets.

=head1 METHODS

The following methods are defined in addition to those inherited from the 
L<Badger::Base> base class.

=head2 init()

This is aliased to the L<init_type()> method.

=head2 init_type($config)

This is the initialisation method for a data type.  It is called automatically
when a data type object is created via the L<new()|Badger::Base/new()> method
inherited from the L<Badger::Base> base class.

=head2 name()

Returns the name of the data type as specified via the L<name> configuration
option.  If no name was specified then an automatically generated name is
returned based on the class name with the C<Badger::Data::Type> prefix
removed and all C<::> sequences replaced with periods, e.g. a data type 
C<Badger::Data::Type::Foo::Bar> would yield a name of C<Foo.Bar>.

=head2 namespace()

Returns the namespace for the data type, or C<undef> is none is defined.

=head2 base()

Returns the base data type, or C<undef> is none is defined.

=head2 facets()

Returns a reference to a list of validation facets defined for the data type.

=head2 simple()

This constant method always returns the value C<0>.  Subclasses representing
simple data types should re-define this to return the value C<1>.

=head2 complex()

This constant method always returns the value C<0>.  Subclasses representing
complex data types should re-define this to return the value C<1>.

=head2 constrain($facet, @args)

Applies a new validation facet to the data type.

=head2 validate($value_ref)

Validates the value passed by reference as the first argument.  It calls
the C<validate()> method of each of the validation facets in turn. 

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008-2012 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Base>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
