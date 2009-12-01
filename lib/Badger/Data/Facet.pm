#========================================================================
#
# Badger::Data::Facet
#
# DESCRIPTION
#   Base class validation facet for simple data types.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Data::Facet;

use Badger::Debug ':dump';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    import    => 'class',
    words     => 'ARGS OPTS',
    accessors => 'value',
    messages  => {
#        invalid     => 'Invalid %s.  %s',
#        list_length    => '%s should be %d elements long (got %d)',
#        list_too_short => '%s should be at least %d elements long (got %d)',
#        list_too_long  => '%s should be at most %d elements long (got %d)',
#        text_length    => '%s should be %d characters long (got %d)',
#        text_too_short => '%s should be at least %d characters long (got %d)',
#        text_too_long  => '%s should be at most %d characters long (got %d)',
#        too_small      => '%s should be no less than %d (got %d)',
#        too_large      => '%s should be no more than %d (got %d)',
#        pattern        => '%s does not match pattern: %s',
        not_any        => '%s does not match any of the permitted values: <3>',
#        whitespace     => 'Invalid whitespace option: %s (expected one of: %s)',
#        not_number     => '%s is not a number: <3>',
    };


sub init {
    my ($self, $config) = @_;
    my $class = $self->class;
    my ($option, @optional);

    $self->debug("init() config is ", $self->dump_data($config)) if DEBUG;

    foreach $option ($class->list_vars(ARGS)) {
        $self->{ $option } = defined $config->{ $option }
            ? $config->{ $option }
            : $self->error_msg( missing => $option );
    }

    @optional = $class->list_vars(OPTS);
    @$self{ @optional } = @$config{ @optional };
    
    $self->{ name } ||= do {
        my $pkg = ref $self;
        $pkg =~ /.*::(\w+)$/;
        $1;
    };
    
    return $self;
}


sub validate {
    shift->not_implemented;
}


sub invalid {
    shift->error(@_);
}


sub invalid_msg {
    my $self = shift;
    $self->invalid( $self->message( @_ ) );
}


1;

__END__

=head1 NAME

Badger::Data::Facet - base class validation facet for simple data types

=head1 SYNOPSIS

TODO

=head1 PLEASE NOTE

This module is a work in progress. The implementation is subject to change and
the documentation may be incomplete or incorrect in places.

=head1 DESCRIPTION

This module implements a base class validation facet for data types.

=head1 METHODS

=head2 init($config)

Custom initialisation method for data facets. Subclasses may redefine this
method to do something different.  Otherwise the default behaviour is as 
follows.

It first looks for any C<$ARGS> package variables (in the current and any base
classes) which denote the names of mandatory arguments for the data type.

    our $ARGS = ['foo', 'bar'];

It then asserts that each of these is defined in the C<$config> and copies
the value into C<$self>.

Any optional parameters can be specified using the C<$OPTS> package variable.

    our $OPTS = 'baz';              # single string is sugar for ['baz']

If any of these value(s) are defined in the C<$config> then they will be 
copied into C<$self>.

=head2 validate($value,$type)

This is the main validation method for facets.  Subclasses must redefine this
method to implement their own validation routine.

The first argument is a I<reference> to the candidate value.  For list and 
hash data types, this will be a reference to the list or hash respectively,
as you would usually expect.  If the value is a non-reference scalar (e.g.
a number or text string) then a I<reference> will also be passed.  You may
not be expecting this.

    $facet->validate(\$text);
    $facet->validate(\@list);
    $facet->validate(\%hash);

=head2 invalid($message)

This method is used internally (e.g. by the L<validate()> method) to report
invalid values.

    $self->invalid("The value specified is not valid");

=head2 invalid_msg($format,@args)

This method is used internally (e.g. by the L<validate()> method) to report
invalid values using a pre-defined L<message()|Badger::Base/message()> 
format.

    our $MESSAGES = {
        not_orange => 'The colour specified is not orange: %s',
    };

    sub validate {
        my ($self, $value) = @_;
        
        return $$value eq 'orange'
            || $self->invalid_msg( not_orange => $$value );
    }

=head1 PACKAGE VARIABLES

=head2 $MESSAGES

Subclasses may defined their own message formats (for use with 
L<invalid_msg()>) using the C<$MESSAGES> package variable.  This should
be a reference to a hash array mapping short names to message formats.
These formats are expanded using the C<xprintf()|Badger::Utils/xprintf()>
function in L<Badger::Utils>.  This is a wrapper around C<sprintf()> with
some extra syntactic sugar for handling positional arguments.

    our $MESSAGES = {
        # messages taking one and two parameters
        not_orange => 'The colour specified is not orange: %s',
        not_colour => 'The colour specified is not %s: %s',

        # message specifying parameters in a different order
        alt_colour => 'You specified the colour <2> but that is not <1>.',
    };

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 ACKNOWLEDGEMENTS

This module is derived from the L<XML::Schema::Facet> module, also written 
by Andy Wardley under funding from Canon Research Europe Ltd.

=head1 SEE ALSO

L<Badger::Data::Type::Simple>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
