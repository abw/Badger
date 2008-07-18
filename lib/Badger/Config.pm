#========================================================================
#
# Badger::Config
#
# DESCRIPTION
#   A central configuration module.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Config;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Prototype';

our $AUTOLOAD;

sub new {
    my $class = shift;
    my $args  = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };
    bless $args, $class;
}

sub AUTOLOAD {
    my ($self, @args) = @_;
    my ($name) = ($AUTOLOAD =~ /([^:]+)$/ );
    return if $name eq 'DESTROY';
    $self = $self->prototype unless ref $self;

    # very simple for now
    return exists $self->{ $name }
        ? $self->{ $name }
        : $self->error_msg( bad_method => $name, ref $self, (caller())[1,2] );
}



#------------------------------------------------------------------------
# generate_config_methods()
#
# Generate an accessor method for each of the items passed as arguments
#------------------------------------------------------------------------

sub OLD_generate_config_methods {
    my $class   = shift;
    my $methods = shift; # || $class->pkgvar('METHODS');
    $class = ref $class || $class;

    # engage cloaking shield to protect us from Perl's beady eyes and nagging tongue
    no strict 'refs';

    foreach my $method (@$methods) {
        $class->debug("Generating method: $method()\n") if $DEBUG;

        *{"${class}::$method"} = sub {
            my $self = shift;
            # look for the item in the $self->{ config } or an UPPER CASE package variable.
            my $item = ref $self ? $self->{ config }->{ $method } : $self->pkgvar(uc $method);

            # return any value that isn't a hash ref
            return $item unless ref $item eq 'HASH';
            
            if (@_) {
                # if we have any arguments then merge them with the default
                # values in the $item hash and return a new composite set
                my $config = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };
                return { 
                    %$item,
                    %$config,
                };
            }
            else {
                # otherwise return a copy of the defaults
                return { %$item };
            }
        } unless defined &{"${class}::$method"};
    }
}
1;
__END__

=head1 NAME

Badger::Config - configuration module

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

TODO

=head1 METHODS

TODO

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2001-2007 Andy Wardley.  All Rights Reserved.

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
