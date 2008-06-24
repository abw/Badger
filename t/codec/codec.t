#========================================================================
#
# t/codec/codec.t
#
# Test the Badger::Codec module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Codec;
use Test::More tests => 1;
$Badger::Codec::DEBUG = grep(/^-d/, @ARGV);

ok(1, 'Loaded Badger::Codec' );

__END__

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

