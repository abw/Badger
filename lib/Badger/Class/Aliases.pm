#========================================================================
#
# Badger::Class::Aliases
#
# DESCRIPTION
#   Class mixin module for adding code onto a class to provide aliases 
#   for configuration parameters and the like.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Class::Aliases;

use Carp;
use Badger::Debug ':dump';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Exporter Badger::Base',
    import    => 'class CLASS',
    words     => 'ALIASES',
    constants => 'HASH',
    constant  => {
        INIT_METHOD => 'init_aliases',
    };

sub export {
    my $class   = shift;
    my $target  = shift;
    my $aliases = @_ == 1 ? shift : { @_ };

    croak("Invalid defaults specified: $aliases")
        unless ref $aliases eq HASH;
    
    $class->export_symbol(
        $target,
        ALIASES,
        \$aliases
    );
    
    $class->export_symbol(
        $target, 
        INIT_METHOD, 
        $class->can(INIT_METHOD)    # subclass might redefine method
    );
}

sub init_aliases {
    my ($self, $config) = @_;
    my $class = class($self);

    $self->debug("init_aliases(", CLASS->dump_data_inline($config), ')') if DEBUG;
    
    my $aliases = $class->hash_vars(ALIASES);
    CLASS->debug('$ALIASES: ', CLASS->dump_data_inline($aliases)) if DEBUG;
    
    while (my ($key, $alias) = each %$aliases) {
        if (defined $config->{ $key }) {
            CLASS->warn("Both $key and $alias are defined, using $key: $config->{ $key }\n")
                if defined $config->{ $alias };
        }
        else {
            $config->{ $key } = $config->{ $alias };
        }
    }
    
    return $self;
}
    
1;


1;

__END__

=head1 NAME

Badger::Class::Aliases - class mixin for creating parameter aliases

=head1 SYNOPSIS

    package My::Module;
    
    use Badger::Class
        base => 'Badger::Base';
    
    use Badger::Class::Aliases
        user => 'username',
        pass => 'password';
        
    sub init {
        my ($self, $config) = @_;
        $self->init_aliases($config);
        $self->{ user } = $config->{ user };
        $self->{ pass } = $config->{ pass };
        return $self;
    }

=head1 DESCRIPTION

This class mixin module allows you to define aliases for configuration 
parameters.

It is still experimental and subject to change.

=head1 METHODS

=head2 init_aliases($config)

This method is mixed into classes that use it.  It creates a composite
hash of all C<$ALIASES> defined in package variables and updates the 
C<$config> hash reference, adding entries against the definitive name
for any options that are specified using aliases.

See L<Badger::Class> for further details.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008 Andy Wardley.  All Rights Reserved.

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
