#============================================================= -*-perl-*-
#
# t/misc/yup.t
#
# Test the Badger::Yup module.
#
# Copyright (C) 2019 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ../../lib );
use Badger;
use Badger::Test
    skip   => "Move along, there's nothing to see",
    tests  => 71,
    debug  => 'Badger::Yup',
    args   => \@ARGV;

use Badger::Yup 'Yup';

my $yup = Yup;
ok(Yup, "Yup is defined: $yup");

#-----------------------------------------------------------------------------
# string
#-----------------------------------------------------------------------------

my $str = Yup->string("This value must be a string");

ok( $str, "Yup.string is defined: $str" );

is( $str->validate(123), 123, "123 is a valid string" );
catch_ok( $str, { x => 123 }, 'This value must be a string' );

# string.required
catch_ok( Yup->string->required, '', 'Value is required' );
catch_ok( Yup->string->required('You numpty'), '', 'You numpty' );

# check missing args get reported
eval { Yup->string->required->min };
is(
    $@, "yup.element.string.required error - string.min requires an argument for 'min'",
    "error for missing argument: $@"
);

# string.min
my $min5 = Yup->string->required->min(5);
is( $min5->validate("wibble"), "wibble", "wibble is long enough" );
catch_ok($min5, 'foop', 'String must be 5 characters or longer');

$min5 = Yup->string->required->min(5, 'Too short');
is( $min5->validate("wobble"), "wobble", "wibble is long enough" );
catch_ok($min5, 'flop', 'Too short');

# string.max
my $max5 = Yup->string->required->max(5);
is( $max5->validate("pooch"), "pooch", "pooch is short enough" );
catch_ok($max5, 'wabble', 'String must be 5 characters or shorter');

$max5 = Yup->string->required->max(5, 'Too long');
is( $max5->validate("pauch"), "pauch", "pauch is short enough" );
catch_ok($max5, 'wubble', 'Too long');

# string.match
my $match = Yup->string->matches(qr/^(.*)sex$/, "Not a sexy county");
is( $match->validate("Sussex"), "Sussex", "string.match Sussex" );
is( $match->validate("Essex"), "Essex", "string.match Essex" );
catch_ok($match, "No Sex Please, We're British", "Not a sexy county" );
catch_ok($match, 'Dorset', 'Not a sexy county');

catch_ok(Yup->string->matches('parp'), 'farp', 'String must match the pattern: parp');

# string.trim
is( Yup->string->trim->validate("  hello  "), "hello", "string.trim" );

# string.uppercase
is( Yup->string->uppercase->validate("hello"), "HELLO", "string.uppercase" );

# string.lowercase
is( Yup->string->lowercase->validate("HELLO"), "hello", "string.lowercase" );

# string.capitalize
is( Yup->string->capitalize->validate("hello"), "Hello", "string.capitalize" );

#-----------------------------------------------------------------------------
# number
#-----------------------------------------------------------------------------

test_pass_fail(
    Yup->number->positive, "number.positive",
    "5", "5",
    "-5", "Number must be positive"
);

test_pass_fail(
    Yup->number->negative, "number.negative",
    "-5", "-5",
    "5", "Number must be negative"
);

test_pass_fail(
    Yup->number->min(10), "number.min",
    "11", "11",
    "4", "Number must be 10 or larger"
);

test_pass_fail(
    Yup->number->max(10), "number.max",
    "9", "9",
    "11", "Number must be 10 or smaller"
);

test_pass_fail(
    Yup->number->nonzero, "number.nonzero",
    "5", "5",
    "0", "Number must not be zero"
);

test_pass_fail(
    Yup->number->integer, "number.integer",
    "3", "3",
    "3.14", "Number must be an integer"
);

is( Yup->number->floor->validate(1.23), 1, "number.floor" );
is( Yup->number->ceiling->validate(1.23), 2, "number.ceiling" );
is( Yup->number->ceil->validate(1.23), 2, "number.ceil" );
is( Yup->number->round->validate(1.49), 1, "positive number.round down" );
is( Yup->number->round->validate(1.51), 2, "positive number.round up" );
is( Yup->number->round->validate(-1.49), -1, "negative number.round down" );
is( Yup->number->round->validate(-1.51), -2, "negative number.round up" );
is( Yup->number->truncate->validate(1.49), 1, "positive number.truncate 1" );
is( Yup->number->truncate->validate(1.51), 1, "positive number.truncate 2" );
is( Yup->number->truncate->validate(-1.49), -1, "negative number.truncate 1" );
is( Yup->number->truncate->validate(-1.51), -1, "negative number.truncate 2" );

is( Yup->default(10)->number->validate(), 10, "number.default defaults to 10" );
is( Yup->default(10)->number->validate(11), 11, "number.default uses provided value" );

my $stringer = Yup->build([
    ['required'],
    ['string'],
    ['trim'],
    ['uppercase'],
    ['max', 10, 'Too much matey'],
    ['min', 5, 'Needs a bit more'],
]);
is( $stringer->validate('foo bar'), 'FOO BAR', "string builder" );
is( $stringer->validate('foo bar'), 'FOO BAR', "string builder" );
catch_ok($stringer, 'flopsy bunny', 'Too much matey');
catch_ok($stringer, 'flop', 'Needs a bit more');

my $building = Yup->build([
    ['required'],
    ['number'],
    ['max', 10],
    ['min', 1],
]);



sub test_pass_fail {
    my ($validator, $name, $good, $expect, $bad, $error) = @_;
    is(
        $validator->validate($good),
        $expect,
        $name
    );
    is(
        $validator->catch(catcher($error))->validate($bad),
        'error reported',
        'error reported'
    );
}


sub catch_ok {
    my ($yup, $value, $expect) = @_;
    is(
        $yup->catch(catcher($expect))->validate($value),
        'error reported',
        "error reported"
    );
}

sub catcher {
    my $expect = shift;
    return sub {
        my ($value, $error) = @_;
        if ($expect) {
            is( $error, $expect, "Caught expected error: $error" );
        }
        else {
            pass("caught error: $error");
        }
        return 'error reported';
    }
}



#print $str->dump;
