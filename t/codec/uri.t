#========================================================================
#
# t/codec/uri.t
#
# Test the Badger::Codec::Base64 module.
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

use Badger::Test 
    tests => 2,
    debug => 'Badger::Codec::URI',
    args  => \@ARGV;
    
use Badger::Codecs
    codec => 'uri';

my $uncoded = 'Hello World&^%';
my $encoded = encode($uncoded);
is( $encoded, 'Hello%20World%26%5E%25', 'URI encoded data' );
my $decoded = decode($encoded);
is( $decoded, $uncoded, 'decoded output matches input' );

__END__

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

