#============================================================= -*-perl-*-
#
# t/class/config.t
#
# Test the Badger::Class module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( t/class/lib ../t/class/lib ./lib ../lib ../../lib );
use Badger::Test
    tests => 30,
    debug => 'Badger::Class::Config',
    args  => \@ARGV;

my $obj;

#-----------------------------------------------------------------------
# My::Config2 uses Badger::Class::Config directly and defines the config
# using a single string:
#
#  use Badger::Class::Config 
#      'username|user! password|pass!';
#
#-----------------------------------------------------------------------

use My::Config1;
$obj = eval { My::Config1->new( username => 'fred' ) };
ok( ! $obj, 'no object' );
is( $@->info, 'No password specified', 'no password error' );

$obj = My::Config1->new( username => 'fred', password => 'secret' );
ok( $obj, 'created object with long names' );
is( $obj->username, 'fred', 'got username' );
is( $obj->password, 'secret', 'got password' );

$obj = My::Config1->new( user => 'fred', pass => 'secret' );
ok( $obj, 'created object with short names' );
is( $obj->username, 'fred', 'got username from user' );
is( $obj->password, 'secret', 'got password from pass' );


#-----------------------------------------------------------------------
# My::Config2 defines the data with a hash ref.
#
#  use Badger::Class::Config 
#      username => {
#          fallback => ['user', 'pkg:USERNAME', 'env:MY_USERNAME'],
#          required => 1,
#      },
#      password => {
#          fallback => ['pass', 'pkg:PASSWORD', 'env:MY_PASSWORD'],
#          required => 1,
#      };
#
#-----------------------------------------------------------------------

use My::Config2;
$obj = My::Config2->new( username => 'fred', pass => 'secret' );
ok( $obj, 'created second object with mixed names' );
is( $obj->username, 'fred', 'got username from second object' );
is( $obj->password, 'secret', 'got password from second object' );


#-----------------------------------------------------------------------
# My::Config3 does it via Badger::Class
#-----------------------------------------------------------------------

use My::Config3;
$ENV{ MY_DRIVER } = 'wibble';
$obj = My::Config3->new( username => 'fred' );

ok( $obj, 'created third object with mixed names' );
is( $obj->username, 'fred', 'got username from third object' );
is( $obj->password, 'top_secret', 'got password from third object' );
is( $obj->driver, 'wibble', 'got driver from environment data' );


#-----------------------------------------------------------------------
# My::Config4 is a subclass of My::Config3 which adds extra config items
#-----------------------------------------------------------------------

use My::Config4;
$obj = My::Config4->new( username => 'fred' );
ok( $obj, 'created fourth object with mixed names' );
is( $obj->username, 'fred', 'got username from third object' );
is( $obj->password, 'top_secret', 'got password from third object' );
is( $obj->driver, 'wibble', 'got driver from environment data' );
is( $obj->extra, 'read all about it', 'got extra config item' );
is( $obj->colour, 'black', 'How much more black could this be?' );
is( $obj->volume, 10, 'most amplifiers go up to ten' );
$obj = My::Config4->new( username => 'nigel', volume => 11 );
is( $obj->volume, 11, 'this one goes up to eleven' );


#-----------------------------------------------------------------------
# My::Config5 is a subclass of My::Config5 and defines a new VOLUME
# constant.  it's one louder.
#-----------------------------------------------------------------------


use My::Config5;
$obj = My::Config5->new( username => 'nigel' );
is( $obj->volume, 11, "well, it's one louder" );
is( $obj->cat, 'felix', 'got the cat' );
is( $obj->dog, 'rover', 'got the dog' );


# test we can target a different hash
my $data = { };
My::Config5->configure({ username => 'nigel' }, $data);
is( $data->{ volume }, 11, 'got volume via hash target' );
is( $data->{ username }, 'nigel', 'got name via hash target' );

# test that a later option can default to an earlier one
$obj = My::Config5->new( pussy => 'fluffy', username => 'tibbles' );
is( $obj->cat, 'fluffy', 'The cat is a fluffy pussy' );
is( $obj->feline, 'fluffy', 'The cat is a fluffy feline' );

__END__
use My::Config2;
my $item = My::Config2->new;

