#============================================================= -*-perl-*-
#
# t/core/logic.t
#
# Test the Badger::Timestamp module.
#
# Copyright (C) 2007-2009 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Test
    tests  => 28,
    debug  => 'Badger::Logic',
    args   => \@ARGV;

use Badger::Logic 'LOGIC Logic';
pass('loaded Badger::Logic' );

my $logic;


$logic = LOGIC->new('a and b');
ok( $logic, 'created logic via LOGIC->new()' );

$logic = Logic->new('a or b');
ok( $logic, 'created logic via Logic->new()' );

$logic = Logic('a or b and c');
ok( $logic, 'created logic via Logic()' );

sub test_logic {
    my ($text, $args, $expect) = @_;
    is( LOGIC->new($text)->evaluate($args), $expect, "$text => $expect" );
}

my $data1 = {
    a => 1,
    b => 0,
    c => 1,
    d => 0,
    e => 1,
};

test_logic('a and b', $data1, 0);
test_logic('a or b', $data1, 1);
test_logic('a and b or c', $data1, 1);
test_logic('a and b or d', $data1, 0);
test_logic('a and not b', $data1, 1);
test_logic('not a or b', $data1, 0);
test_logic('(not a) or b', $data1, 0);
test_logic('not (a or b)', $data1, 0);
test_logic('not b or a', $data1, 1);
test_logic('(not b) or a', $data1, 1);
test_logic('not a and b', $data1, 0);
test_logic('not b and a', $data1, 1);
test_logic('(not a) and b', $data1, 0);
test_logic('not (a and b)', $data1, 1);
test_logic('(a or b) and (b or c)', $data1, 1);
test_logic('(a and b) or (b and c)', $data1, 0);
test_logic('(a and b) or (b and c) or e', $data1, 1);
test_logic('not ((a or b) and (b or c))', $data1, 0);
test_logic('(not a) and (b or c)', $data1, 0);

my $logic2 = LOGIC->new('a and b or c and not d');
is( $logic2->text, 'a and b or c and not d', 'text output' );
is( $logic2->tree_text, '(a and (b or (c and (not d))))', 'canonical text output' );
is( $logic2, 'a and b or c and not d', 'auto-stringification' );

my $data2 = {
    "realm/admin" => 1,
    "realm/user"  => 0,
};
test_logic('"realm/user"', $data2, 0);
test_logic(q{ "realm/user" or 'realm/admin'}, $data2, 1);






__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
