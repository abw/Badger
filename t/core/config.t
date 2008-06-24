#============================================================= -*-perl-*-
#
# t/core/config.t
#
# Test the Badger::Config module.
#
# Copyright (C) 2008 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;

use lib qw( ./lib ../lib ../../lib );
use Badger::Config;
use Test::More tests => 3;

$Badger::Config::DEBUG = grep(/^-d$/, @ARGV);

my $pkg = 'Badger::Config';

my $config = $pkg->new({ x => 10, y => 20 });
is( $config->x, 10, 'x is 10' );
is( $config->y, 20, 'y is y0' );

eval { $config->z };
like( $@, qr/Invalid method 'z' called on Badger::Config/, 'bad method' );



__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
