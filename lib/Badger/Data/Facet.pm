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
        list_length    => '%s should be %d elements long (got %d)',
        list_too_short => '%s should be at least %d elements long (got %d)',
        list_too_long  => '%s should be at most %d elements long (got %d)',
        text_length    => '%s should be %d characters long (got %d)',
        text_too_short => '%s should be at least %d characters long (got %d)',
        text_too_long  => '%s should be at most %d characters long (got %d)',
        too_small      => '%s should be no less than %d (got %d)',
        too_large      => '%s should be no more than %d (got %d)',
        pattern        => '%s does not match pattern: %s',
        not_any        => '%s does not match any of the permitted values: <3>',
        whitespace     => 'Invalid whitespace option: %s (expected one of: %s)',
        not_number     => '%s is not a number: <3>',
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
