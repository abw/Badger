#========================================================================
#
# t/codec/base64.t
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
use Badger::Codec::Base64;
use Badger::Test 
    tests => 1,
    debug => 'Badger::Codec Badger::Codecs',
    args  => \@ARGV;

use constant Codec => 'Badger::Codec::Base64';

my $input = '**&@£foobar';
my $encode = Codec->encode($input);
my $decode = Codec->decode($encode);
is( $decode, $input, 'decoded output matches input' );

__END__

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

