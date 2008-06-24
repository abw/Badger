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
    ARRAY           => 'ARRAY',
    HASH            => 'HASH',
    CODE            => 'CODE',
    REGEX           => 'Regexp',
    
    # generally useful constants
    LAST            => -1,          
    OFF             => 0,            # in the beginning was the void...
    ON              => 1,            # let there be light!
    ALL             => 'all',        # used to enable various things
    NONE            => 'none',       # used to disable various things
    DEFAULT         => 'default',    # used to explicitly select the default option
};

CONSTANTS->export_any(qw( 
    CONSTANTS LAST OFF ON ALL NONE DEFAULT
));

CONSTANTS->export_tags({
    types => [qw( 
        ARRAY HASH CODE REGEX
    )],
});

1;

__END__

=head1 NAME

Badger::Constants - defines constants for other TT modules

=head1 SYNOPSIS

    use Badger::Constants 'HASH';
    
    if (ref $something eq HASH) {
        # rejoice!
    }
    
=head1 DESCRIPTION

This module defines a number of constants used by other C<Badger> modules.
Badger Toolkit.  They can be used by specifying the L<Badger::Constants> 
package explicitly as part of the name:

    use Badger::Constants;
    print Badger::Constants::HASH;   # HASH

Constants may be imported into the caller's namespace by naming them as 
options to the C<use Badger::Constants> statement:

    use Badger::Constants 'HASH';
    print HASH;   # HASH

Alternatively, one of the tagset identifiers may be specified
to import different sets of constants.

    use Badger::Constants ':types';
    print HASH;   # HASH

=head1 EXPORTABLE TAG SETS

The following tag sets and associated constants are defined: 

  :types
   HASH
   ARRAY
   CODE
   REGEX

  :all              # all the above constants.

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
