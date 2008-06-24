#============================================================= -*-perl-*-
#
# t/utils.t
#
# Test the Badger::Utils module.
#
# Written by Andy Wardley <abw@wardley.org>.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;

use lib qw( t/core/lib ./lib ../lib ../../lib );
use Badger::Utils qw( UTILS blessed );
use Test::More tests => 2;

my $DEBUG = $Badger::Utils::DEBUG = grep(/^--?d(ebug)?/, @ARGV);

is( UTILS, 'Badger::Utils', 'got UTILS defined' );
ok( blessed bless([], 'Wibble'), 'got blessed' );


__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

