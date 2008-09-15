#========================================================================
#
# Badger::Constants
#
# DESCRIPTION
#   Defines various constants used by the Badger modules
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Constants;

our $VERSION = 0.01;

use strict;
use warnings;
use base 'Badger::Exporter';
use constant {
    # this is me
    CONSTANTS       => __PACKAGE__,
    
    # various type classes
    SCALAR          => 'SCALAR',
    ARRAY           => 'ARRAY',
    HASH            => 'HASH',
    CODE            => 'CODE',
    GLOB            => 'GLOB',
    REGEX           => 'Regexp',
    
    # constant values
    FALSE           => 0,
    TRUE            => 1,
    OFF             => 0,            
    ON              => 1,            
    ALL             => 'all',
    NONE            => 'none',
    DEFAULT         => 'default',
    
    # misc constants used internally
    FIRST           =>  0,                  # first and last items in a list
    LAST            => -1,
    CRLF            => "\015\012",          # unambiguous CR+LF sequence
    PKG             => '::',                # for joining pkg names
    REFS            => 'refs',              # no strict REFS
    ONCE            => 'once',              # use warnings ONCE
    WARN            => 'warn',              # default warning handler
    BLANK           => '',                  # how much more blank could this be?
    SPACE           => ' ',                 # and the answer is none, none more blank
    DELIMITER       => qr/(?:,\s*)|\s+/,    # match a comma or whitespace
    WILDCARD        => qr/[\*\?]/,          # wildcards: *.html foo??.txt

};

CONSTANTS->export_any(qw( 
    CONSTANTS FIRST LAST CRLF PKG REFS ONCE WARN BLANK SPACE 
    DELIMITER WILDCARD 
));

CONSTANTS->export_tags({
    types => [qw( 
        SCALAR ARRAY HASH CODE GLOB REGEX
    )],
    values => [qw(
        FALSE TRUE OFF ON ALL NONE DEFAULT
    )],
});

1;

__END__

=head1 NAME

Badger::Constants - defines constants for other Badger modules

=head1 SYNOPSIS

    use Badger::Constants 'HASH';
    
    if (ref $something eq HASH) {
        # rejoice!  No need to quote the word 'HASH'
    }

=head1 DESCRIPTION

This module defines a number of constants used by other C<Badger> modules.
They can be imported into the caller's namespace by naming them as options to
the C<use Badger::Constants> statement:

    use Badger::Constants 'HASH';
    print HASH;   # HASH

Alternatively, one of the tagset identifiers may be specified
to import different sets of constants.

    use Badger::Constants ':types';
    print HASH;   # HASH

=head1 EXPORTABLE CONSTANTS

=head2 CONSTANTS

Set to C<Badger::Constants>.

=head2 SCALAR

The literal word C<SCALAR>, typically used for testing references.

    if (ref $data eq SCALAR) {
        ...
    }

=head2 ARRAY

The literal word C<ARRAY>, typically used for testing references.

    if (ref $data eq ARRAY) {
        ...
    }

=head2 HASH

The literal word C<HASH>, typically used for testing references.

    if (ref $data eq HASH) {
        ...
    }

=head2 CODE

The literal word C<CODE>, typically used for testing references.

    if (ref $data eq CODE) {
        ...
    }

=head2 GLOB

The literal word C<GLOB>, typically used for testing references.

    if (ref $data eq GLOB) {
        ...
    }

=head2 REGEX

The literal word C<Regexp>, typically used for testing references.

    if (ref $data eq REGEX) {
        ...
    }

=head2 FALSE

A false value (0)

=head2 TRUE

A true value (1)

=head2 OFF

A generic flag used to disable things (0).

=head2 ON

A generic flag used to enable things (1).

=head2 ALL

The literal string C<all>.

=head2 NONE

The literal string C<none>.

=head2 DEFAULT

The literal string C<default>.

=head2 WARN

The literal string C<warn>.

=head2 LAST

The value C<-1>, used to index the last item in an array.

    $array[LAST];

=head2 CRLF

An unambiguous carriage return and newline sequence: C<\015\012>

=head2 PKG

An alias for the C<::> symbol used to delimiter Perl packages.  Typically 
used to construct symbol references.

    use Badger::Constants 'PKG';
    use constant EXAMPLE => 'EXAMPLE';
    
    my $var = ${ $pkg.PKG.EXAMPLE };   # same as: ${"${pkg}::EXAMPLE"}

=head2 REFS

The literal string C<refs>.  Typically used like so:

    no strict REFS;

=head2 ONCE

The literal string C<once>.  Typically used like so:

    no warnings ONCE;

=head2 BLANK

An empty string.  How much more blank could this be?  And the answer is
none.  None more blank.

=head2 SPACE

A single space character. Not to be confused with the three dimensional fabric
of reality that it happens to share a name with.

=head2 DELIMITER

A regular expression used to split whitespace delimited tokens.  Also
accepts commas with optional trailing whitespace as a delimiter.

    $names = [ split DELIMITER, $names ] 
        unless ref $names eq ARRAY;

=head2 WILDCARD

A regular expression used to match strings containing the C<*> or C<?> 
wildcard characters.

    if ($path =~ WILDCARD) {
        # do someting...
    } 

=head1 EXPORTABLE TAG SETS

The following tag sets and associated constants are defined: 

=head2 :types

    SCALAR HASH ARRAY CODE REGEX

=head2 :values

    FALSE TRUE OFF ON ALL NONE DEFAULT

=head2 :all

All the constants.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

See L<Badger::Exporter> for more information on exporting variables.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
