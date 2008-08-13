#============================================================= -*-perl-*-
#
# t/core/constants.t
#
# Test the Badger::Constants module.
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
use Badger::Constants ':types';
use Badger::Test 
    tests => 7,
    debug => 'Badger::Constants',
    args  => \@ARGV;


ok(1, 'loaded Badger::Constants' );
is( HASH, Badger::Constants::HASH, 'HASH is ' . HASH );


#-----------------------------------------------------------------------
# test WILDCARD and DELIMITER
#-----------------------------------------------------------------------

use Badger::Constants 'WILDCARD DELIMITER';

  like( '*.html',     WILDCARD, '*.html matched by WILDCARD' );
  like( 'foo.*',      WILDCARD, 'foo.* matched by WILDCARD' );
  like( 'foo??.html', WILDCARD, 'foo??.html matched by WILDCARD' );
unlike( 'foo.html',   WILDCARD, 'foo.html NOT matched by WILDCARD' );

my @stuff = split DELIMITER, 'foo bar,baz, bam';
is( join('|', @stuff), 'foo|bar|baz|bam', 'split using DELIMITER' );



__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
