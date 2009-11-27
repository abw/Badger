#============================================================= -*-perl-*-
#
# t/data/data.t
#
# Test the Badger::Data module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ./lib ../lib ../../lib );

use Badger::Test 
    debug  => 'Badger::Data',
    args   => \@ARGV,
    tests  => 23;

use Badger::Constants 'HASH';
use Badger::Data;
pass('loaded Badger::Data');

my $Data = 'Badger::Data';


#------------------------------------------------------------------------
# methods() and method() as class methods
#------------------------------------------------------------------------

my ($methods, $method);

$methods = $Data->methods();
ok( $methods, 'got methods table from methods()' );
is( ref $methods, 'HASH', 'methods is a hash from methods()' );
ok( defined $methods->{ ref }, 'got ref method from methods()' );

$methods = $Data->method();
ok( $methods, 'got methods table from method()' );
is( ref $methods, 'HASH', 'methods is a hash from method()' );
ok( defined $methods->{ ref }, 'got ref method from method()' );
is( $methods->{ ref }->({ }), HASH, 'ref method "works"' );

$method = $Data->method('ref');
ok( $method, 'got ref() method direct from method()' );
is( $method->({ }), HASH, 'ref method still "works"' );


#------------------------------------------------------------------------
# new() constructor method
#------------------------------------------------------------------------

my $obj;

$obj = $Data->new();
ok( $obj, 'created an object' );

$obj = $Data->new( pi => 3.14 );
ok( $obj, 'created a pi object' );
is( $obj->{ pi }, 3.14, 'pi is 3.14' );


#------------------------------------------------------------------------
# init() method
#------------------------------------------------------------------------

ok( $obj->init({ pi => 3.14159 }), 'called init() on object' );
is( $obj->{ pi }, 3.14159, 'pi is now 3.14159' );


#------------------------------------------------------------------------
# ref() and type()
#------------------------------------------------------------------------

is( $obj->ref(), 'Badger::Data', 'object isa Badger::Data' );
is( $obj->type(), 'type', 'object isa type' );


#-----------------------------------------------------------------------
# metadata()
#-----------------------------------------------------------------------

my $metadata = $obj->metadata;
ok( $metadata, 'fetched object metadata' );
$metadata->{ author } = 'Andy Wardley';

is( $obj->metadata->{ author }, 'Andy Wardley', 'got author from hash' );
is( $obj->metadata('author'), 'Andy Wardley', 'got author from method' );

ok( $obj->metadata( author => 'Arthur Dent' ), 'changed author via method' );
is( $obj->metadata->{ author }, 'Arthur Dent', 'got new author from hash' );
is( $obj->metadata('author'), 'Arthur Dent', 'got new author from method' );






__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
