#============================================================= -*-perl-*-
#
# t/filesystem/codec.t
#
# Test the Badger::Filesystem::File codec options.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ./lib ../lib ../../lib );
use Badger::Test 
    tests => 20,
    debug => 'Badger::Filesystem::File',
    args  => \@ARGV;
use constant {
    DIR  => 'testfiles',
    FILE => 'encoded.str',
};
use Badger::Filesystem 'Bin';


#-----------------------------------------------------------------------
# codec defined in the constructor
#-----------------------------------------------------------------------

my $dir  = Bin->dir(DIR)->must_exist;
my $file = $dir->file( FILE, { codec => 'storable' } );
ok( $file, 'created file object' );
is( $file->name, FILE, 'file name matches' );
is( ref $file->codec, 'Badger::Codec::Storable', 'got storable codec' );

my $data = {
    name => 'Badger',
    game => 'Tennis',
    ride => ['skateboard', 'snowboard'],
};

# slide it in...
$file->data($data);

# ...and slide it out... aaaahhh
compare( 'file constructor' => $data, $file->data );


#-----------------------------------------------------------------------
# codec defined via codec() method
#-----------------------------------------------------------------------

$file = $dir->file(FILE);
ok( $file, 'created file object without codec' );
$file->codec('storable');
$file->data($data);                                 # in 
compare( 'file method' => $data, $file->data );     # out


#-----------------------------------------------------------------------
# codec defined in parent directory, first via constructor...
#-----------------------------------------------------------------------

$dir  = Bin->dir( DIR, { codec => 'storable' } )->must_exist;
$file = $dir->file(FILE);
$file->data($data);                                 # in 
compare( 'dir constructor' => $data, $file->data ); # out

#-----------------------------------------------------------------------
# ...then via the code() method...
#-----------------------------------------------------------------------

$dir  = Bin->dir( DIR )->must_exist;
$dir->codec('storable');
$file = $dir->file(FILE);
$file->data($data);                                 # in 
compare( 'dir method' => $data, $file->data );      # out


#-----------------------------------------------------------------------
# comparison subroutine
#-----------------------------------------------------------------------

sub compare {
    my ($name, $one, $two) = @_;
    is($two->{ name }, $one->{ name }, "$name: name matches" );
    is($two->{ game }, $one->{ game }, "$name: game matches" );
    is($two->{ ride }->[0], $one->{ ride }->[0], "$name: ride.0 matches" );
    is($two->{ ride }->[1], $one->{ ride }->[1], "$name: ride.1 matches" );
}