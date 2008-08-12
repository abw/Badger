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
use base 'Badger::Exporter';
use File::Path;
use Scalar::Util qw( blessed reftype );
use Badger::Constants 'HASH';
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
    UTILS blessed reftype is_object params load_module
));

__PACKAGE__->export_hooks(
    md5_hex => sub {
        my ($class, $target, $symbol, $more_symbols) = @_;
        require Digest::MD5;
        $class->export_symbol($target, $symbol, \&Digest::MD5::md5_hex);
        return 1;
    }
);

sub is_object {
    blessed $_[1] && $_[1]->isa($_[0]);
}

sub params {
    @_ && ref $_[0] eq HASH ? shift : { @_ };
}


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
    $class->_debug(" input format: $format\n") if $DEBUG;
    $format =~ s/<(\d+)(?::([#\-\+ ]?[\w\.]+))?>/'%' . $1 . '$' . ($2 || 's')/eg;
    $class->_debug("output format: $format\n") if $DEBUG;
    sprintf($format, @args);
    # accept numerical flags like %0 %1 %2 as well as %s
#    my $n = 0;
#    $format =~ s/%(?:(s)|(\d+))/$1 ? $args[$n++] : $args[$2]/ge;
#    return $format;
}

sub _debug {
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

=head1 EXPORTABLE FUNCTIONS

=head2 UTILS

Exports a C<UTILS> constant which contains the name of the C<Badger::Utils>
class.  This can be used to call C<Badger::Utils> class methods without 
having to hard-code the C<Badger::Utils> class name in your code.

    use Badger::Utils 'UTILS';
    
    UTILS->load_module('My::Module');

=head2 blessed($ref)

Exports a reference to the L<Scalar::Util> L<blessed()|Scalar::Util/blessed()>
function.

=head2 reftype($ref)

Exports a reference to the L<Scalar::Util> L<reftype()|Scalar::Util/reftype()>
function.

=head2 md5_hex

Exports a reference to the L<Digest::MD5> L<md5_hex()|Digest::MD5/md5_hex()>
function.

=head2 is_object($class,$object)

Returns true if the C<$object> is a blessed reference which isa C<$class>.

    use Badger::Filesystem 'FS';
    use Badger::Utils 'is_object';
    
    if (is_object( FS => $object )) {       # FS == Badger::Filesystem
        print $object, ' isa ', FS, "\n";
    }

=head2 params(@args)

Method to coerce a list of named paramters to a hash array reference.  If the
first argument is a reference to a hash array then it is returned.  Otherwise
the arguments are folded into a hash reference.

    params({ a => 10 });            # { a => 10 }
    params( a => 10 );              # { a => 10 }

=head1 METHODS

NOTE: I'm planning to change the class methods listed below to be exportable
subroutines.

=head2 module_file($name)

Returns the module name passed as an argument as a relative filesystem path
suitable for feeding into C<require()>

    print UTILS->module_file('My::Module');     # My/Module.pm

=head2 load_module($name)

Loads the Perl module specified as a parameter.  Returns the module name 
as returned by L<module_file()>.  Throws an error if the 
module cannot be found or loaded.

    use Badger::Utils 'UTILS';
    print UTILS->load_module('My::Module');     # My/Module.pm

=head2 maybe_load_module($name)

A wrapper around L<load_module()> which catches any errors thrown by missing
or invalid modules and returns zero.

    if (UTILS->maybe_load_module('My::Module')) {
        print "loaded\n";
    }
    else {
        print "no loaded\n";
    }

=head2 xprintf($format,@args)

A wrapper around C<sprintf()> which provides some syntactic sugar for 
embedding positional parameters.

    UTILS->xprintf('The <2> sat on the <1>', 'mat', 'cat');
    UTILS->xprintf('The <1> costs <2:%.2f>', 'widget', 11.99);

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
