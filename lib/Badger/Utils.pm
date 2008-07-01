#========================================================================
#
# Badger::Utils
#
# DESCRIPTION
#   Module implementing various useful utility functions.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Utils;

use strict;
use warnings;
use File::Path;
use Scalar::Util qw(blessed reftype );
use base qw( Badger::Exporter );
use constant {
    UTILS  => 'Badger::Utils',
};

our $VERSION  = 0.01;
our $DEBUG    = 0 unless defined $DEBUG;
our $ERROR    = '';
our $MESSAGES = {
    no_module   => "Cannot load %s module (not found)",
    load_failed => 'Failed to load module %s: %s',
};

__PACKAGE__->export_any(qw(
    UTILS blessed reftype load_module
));

__PACKAGE__->export_hooks(
    md5_hex => sub {
        my ($class, $target, $symbol, $more_symbols) = @_;
        require Digest::MD5;
        $class->export_coderef($target, $symbol, \&Digest::MD5::md5_hex);
        return 1;
    }
);



#------------------------------------------------------------------------
# module_file($module)
#
# Converts a module name, e.g. Foo::Bar to its corresponding file
# name, e.g. Foo/Bar.pm
#------------------------------------------------------------------------

sub module_file {
    my ($class, $file) = @_;
    $file  =~ s[::][/]g;
    $file .= '.pm';
}


#------------------------------------------------------------------------
# load_module($name)
#
# Load a Perl module.
#------------------------------------------------------------------------

sub load_module {
    my $class = shift;
    my $name  = $class->module_file(@_);
    require $name;
}

sub maybe_load_module {
    eval { shift->load_module(@_) } || 0;
}

sub xprintf {
    my ($class, $format, @args) = @_;
    $class->debug(" input format: $format\n") if $DEBUG;
    $format =~ s/<(\d+)(?::([#\-\+ ]?[\w\.]+))?>/'%' . $1 . '$' . ($2 || 's')/eg;
    $class->debug("output format: $format\n") if $DEBUG;
    sprintf($format, @args);
    # accept numerical flags like %0 %1 %2 as well as %s
#    my $n = 0;
#    $format =~ s/%(?:(s)|(\d+))/$1 ? $args[$n++] : $args[$2]/ge;
#    return $format;
}

sub debug {
    my $self = shift;
    print STDERR @_;
}

1;

__END__

=head1 NAME

Badger::Utils - various utility functions

=head1 SYNOPSIS

    use Badger::Utils;

    Badger::Utils->load_module('foo');

=head1 DESCRIPTION

This module implements various utility functions.

=head1 FUNCTIONS

TODO

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

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
