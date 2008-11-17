#========================================================================
#
# t/codec/url.t
#
# Test the Badger::Codec::URL module.
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
    debug => 'Badger::Codec::URL',
    args  => \@ARGV;
    
use Badger::Codecs
    codec => 'url';

my $uncoded = 'http://badgerpower.com/example?message="Hello World"';
my $encoded = encode($uncoded);
is( $encoded, 'http://badgerpower.com/example?message=%22Hello%20World%22', 'URL encoded data' );
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

