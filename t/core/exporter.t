#============================================================= -*-perl-*-
#
# t/exporter.t
#
# Test the Badger::Exporter.pm module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( t/core/lib ../t/core/lib ./lib ../lib ../../lib );
use Badger::Exporter;
use Badger::Test 
    tests => 74,
    debug => 'Badger::Exporter',
    args  => \@ARGV;

#------------------------------------------------------------------------
# test default import args
#------------------------------------------------------------------------

package test_base1;
use My::Exporter::Base1;
use Badger::Test;

is( $FOO, 1, '$FOO is 10' );
is( $FOO[0], 10, '$FOO[0] is 10' );
is( $FOO[1], 100, '$FOO[1] is 100' );
is( $FOO[2], 1000, '$FOO[2] is 1000' );
is( $FOO{ten}, 10, '$FOO{ten} is 10' );
is( $FOO{hundred}, 100, '$FOO{hundred} is 100' );
is( $FOO{thousand}, 1000, '$FOO{thousand} is 1000' );
is( foo(), 'this is foo', 'foo() sub is defined' );
{
    no strict;
    no warnings;
    ok( ! defined $BAR, '$BAR is not defined' );
    ok( ! defined $BAR[0], '$BAR[0] is not defined' );
    ok( ! defined $BAR{twenty}, '$BAR{twenty} is not defined' );
}


#------------------------------------------------------------------------
# test specific import args
#------------------------------------------------------------------------

package test_base2;
use My::Exporter::Base1 qw( $FOO $BAR );
use Badger::Test;

is( $FOO, 1, '$FOO is 10' );
is( $BAR, 2, '$BAR is 10' );
{
    no strict;
    no warnings;
    ok( ! defined $FOO[0], '$FOO[0] is not defined' );
    ok( ! defined $BAR[0], '$BAR[0] is not defined' );
}


#------------------------------------------------------------------------
# test illegal import args
#------------------------------------------------------------------------

package test_base3;
use Badger::Test;
eval "use My::Exporter::Base1 qw( \$NONSUCH \$NOTEVER)";
like( $@, qr/\$NONSUCH is not exported by My::Exporter::Base1/, '$NONSUCH error' );
like( $@, qr/\$NOTEVER is not exported by My::Exporter::Base1/, '$NOTEVER error' );


#------------------------------------------------------------------------
# test import tags
#------------------------------------------------------------------------

package test_base4;
use My::Exporter::Base2;
use Badger::Test;

is( $HELLO, 'world', '$HELLO is world' );
{
    no strict;
    no warnings;
    ok( ! defined $FOO, '$FOO is not defined' );
    ok( ! defined $BAR, '$BAR is not defined' );
}

package test_base5;
use My::Exporter::Base2 ':foo';
use Badger::Test;

is( $FOO, 3, '$FOO is 3' );
{
    no strict;
    no warnings;
    ok( ! defined $HELLO, '$HELLO is not defined' );
    ok( ! defined $BAR, '$BAR is not defined' );
}


#------------------------------------------------------------------------
# test default import args with subclass
#------------------------------------------------------------------------

package test_base10;
use My::Exporter::Subclass1;
use Badger::Test;

is( $FOO, 50, '$FOO is 50' );
is( $FOO[0], 10, '$FOO[0] is 10' );
is( $FOO[1], 100, '$FOO[1] is 100' );
is( $FOO{ten}, 10, '$FOO{ten} is 10' );
is( foo(), 'this is the new foo', 'foo() sub is the new foo' );
is( $GOODBYE, 'see ya', '$GOODBYE is "see ya"' );
{
    no strict;
    no warnings;
    ok( ! defined $BAR, '$BAR is not defined' );
    ok( ! defined $BAR[0], '$BAR[0] is not defined' );
    ok( ! defined $BAR{twenty}, '$BAR{twenty} is not defined' );
}

#------------------------------------------------------------------------
# test specific import args with subclass
#------------------------------------------------------------------------

package test_base11;
use My::Exporter::Subclass1 qw( $FOO $BAR );
use Badger::Test;

is( $FOO, 50, '$FOO is 50' );   # from sub class
is( $BAR, 2, '$BAR is 20' );    # from base class
{
    no strict;
    no warnings;
    ok( ! defined $FOO[0], '$FOO[0] is not defined' );
    ok( ! defined $BAR[0], '$BAR[0] is not defined' );
}


#------------------------------------------------------------------------
# test import tags with subclass
#------------------------------------------------------------------------

package test_base12;
use My::Exporter::Subclass2 qw( :foo :bar :baz $HELLO );
use Badger::Test;

is( $FOO, 50, '$FOO is 50' );
is( $BAR, 4, '$BAR is 4' );
is( $BAZ, 999, '$BAZ is 999' );
is( $BAZ[0], 987, '$BAZ[0] is 987' );
is( $BAZ[1], 654, '$BAZ[1] is 654' );
is( $HELLO, 'world', '$HELLO is world' );


#------------------------------------------------------------------------
# test :default tag
#------------------------------------------------------------------------

package test_base20;
use My::Exporter::Subclass2 qw( $FOO :default );
use Badger::Test;

is( $FOO, 50, '$FOO is 50' );
is( $HELLO, 'world', '$HELLO is world' );
is( $GOODBYE, 'see ya', '$GOODBYE is "see ya"' );
{
    no strict;
    no warnings;
    ok( ! defined $FOO[0], '$FOO[0] is not defined' );
    ok( ! defined $BAR[0], '$BAR[0] is not defined' );
}

#------------------------------------------------------------------------
# test :all tag
#------------------------------------------------------------------------

package test_base21;
use My::Exporter::Subclass2 qw( :all );
use Badger::Test;

is( $FOO, 50, '$FOO is 50' );
is( $BAR, 4, '$BAR is 4' );
is( $BAZ, 999, '$BAZ is 999' );
is( $HELLO, 'world', '$HELLO is world' );
is( $GOODBYE, 'see ya', '$GOODBYE is "see ya"' );
is( $FOO[0], 30, '$FOO[0] is 30' );
is( $BAR[0], 50, '$BAR[0] is 50' );


#-----------------------------------------------------------------------
# test single string split into multiple exports
#-----------------------------------------------------------------------

package test_base22;
use My::Exporter::Subclass2 ':foo :bar :baz $HELLO';
use Badger::Test;

is( $FOO,        50, '$FOO is 50 from string import' );
is( $BAR,         4, '$BAR is 4 from string import' );
is( $BAZ,       999, '$BAZ is 999 from string import' );
is( $BAZ[0],    987, '$BAZ[0] is 987 from string import' );
is( $BAZ[1],    654, '$BAZ[1] is 654 from string import' );
is( $HELLO, 'world', '$HELLO is world from string import' );



#-----------------------------------------------------------------------
# test quoted exports
#-----------------------------------------------------------------------

package test_base5q;
use My::Exporter5;
use Badger::Test;
is( $ping, 'wiz', 'ping is wiz' );
is( $pong, 'bang', 'ping is bang' );


#-----------------------------------------------------------------------
# test hashes of export tags which map an alias name to a symbol
#-----------------------------------------------------------------------


package main;
use My::Exporter6 qw(:methods);

is( foo(), 'Did foo', 'called imported foo method' );
is( bar(), 'Did bar', 'called imported bar method' );


#-----------------------------------------------------------------------
# test export hooks
#-----------------------------------------------------------------------

package main;
use My::Exporter7 foo => 10, foo => 20, 'bar', foo => 30;

is( $My::Exporter7::BUFFER, "[foo:10][foo:20][bar][foo:30]", 'foo bar import hooks' );

#-----------------------------------------------------------------------
# test export fail
#-----------------------------------------------------------------------

package main;
use My::Exporter9 foo => 10, foo => 20, 'bar', foo => 30;

is( $My::Exporter8::BUFFER, "[foo:10][foo:20][bar][foo:30]", 'foo bar import fail hooks' );


#-----------------------------------------------------------------------
# test exporter which uses explicit package symbols and code refs
#-----------------------------------------------------------------------

package main;
use My::Exporter::Explicit ':math :science';

is( E, 2.718, 'imported E' );
is( PI, 3.141, 'imported PI' );
is( PHI, 1.618, 'imported PHI' );
is( $ANSWER, 42, 'got the answer (42)' );
is( physics, "E=mc^2", 'got physics' );
is( biology, "evolution", 'got biology' );
is( chemistry, "2 H2O -> 2 H2 + O2", 'got chemistry' );
pass("I can do science, me");



1;

__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
