#========================================================================
#
# t/codec/timestamp.t
#
# Test the Badger::Codec::Timestamp module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ../../lib ../lib ./lib );
use Badger::Test
    tests       => 11,
    debug       => 'Badger::Codec::Timestamp',
    args        => \@ARGV;
use Badger
    Filesystem  => 'Bin',
    Timestamp   => 'TIMESTAMP Now',
    Utils       => 'is_object';


my $dir     = Bin->dir('data')->must_exist;
my $codec   = { codec => 'timestamp' };
my $infile  = $dir->file('example.ts', $codec);
my $outfile = $dir->file('testrun.ts', $codec);
my $stamp   = $infile->data;

# check we read timestamp OK
ok( $stamp, 'read timestamp from file' );
is( $stamp, '2012-04-20 16:21:02', 'got timestamp' );
is( $stamp->year,   2012,   'got year'   );
is( $stamp->month,     4,   'got month'  );
is( $stamp->day,      20,   'got day'    );
is( $stamp->hour,     16,   'got hour'   );
is( $stamp->minute,   21,   'got minute' );
is( $stamp->second,    2,   'got second' );

# write timestamp
$outfile->data(Now);
ok( "wrote timestamp file" );
ok( $outfile->exists, 'file has been created' );

$stamp = $outfile->data;
ok( is_object(TIMESTAMP, $stamp), 'read timestamp back in' );


__END__

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
