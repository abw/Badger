#============================================================= -*-perl-*-
#
# t/exception.t
#
# Test the Badger::Exception module.
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
use Badger::Test 
    tests => 37,
    debug => 'Badger::Exception',
    args  => \@ARGV;

use Badger::Utils 'refaddr';
use Badger::Exception;
use constant 
    Exception => 'Badger::Exception';

my $format = \$Badger::Exception::FORMAT;
my $default = $Badger::Exception::TYPE;


#------------------------------------------------------------------------
# constructor without args for all defaults
#------------------------------------------------------------------------

my $ex1 = Exception->new();
ok( $ex1, 'created first exception' );
is( $ex1->type(), $default, 
    "default exception type is '$default'" );
is( $ex1->info(), 'no information', 'no info by default' );
is( $ex1->file(), 'unknown', 'unknown file' );
is( $ex1->line(), 'unknown', 'unknown line' );


#------------------------------------------------------------------------
# default type defined in subclass
#------------------------------------------------------------------------

package My::Exception;
use base 'Badger::Exception';

our $TYPE = 'wibble';

package main;

$ex1 = My::Exception->new();
is( $ex1->type(), 'wibble', 'wibble type' );


#------------------------------------------------------------------------
# passing contstructor arguments
#------------------------------------------------------------------------

$ex1 = Exception->new({
    type => 'wibble',
    info => 'failed to wibble',
});

is( $ex1->type(), 'wibble', 'wibble error type' );
is( $ex1->info(), 'failed to wibble', 'wibble error info' );
is( $ex1->file(), 'unknown', 'unknown wibble error file' );
is( $ex1->line(), 'unknown', 'unknown wibble error line' );

$ex1 = Exception->new({
    type => 'wobble',
    info => 'failed to wobble',
    file => 'wobbly/file',
    line => 42,
});

is( $ex1->type(), 'wobble', 'wobble error type' );
is( $ex1->info(), 'failed to wobble', 'wobble error info' );
is( $ex1->file(), 'wobbly/file', 'wobble error file' );
is( $ex1->line(), '42', 'wobble error line' );


#------------------------------------------------------------------------
# call type() and info() to set/get
#------------------------------------------------------------------------

my $ex2 = Exception->new();

is( $ex2->type('food'), 'food', "set type to 'food'" );
is( $ex2->info('cheese roll'), 'cheese roll', "set info to 'cheese roll'" );
is( $ex2->type(), 'food', "got type 'food'" );
is( $ex2->info(), 'cheese roll', "got info 'cheese roll'" );

$Badger::Exception::FORMAT = '<type>/<info>';

is( $ex2->text(), 'food/cheese roll', 
    "text is '" . $ex2->text() . "'");

is( $ex2->text('<info>/<type>'), 'cheese roll/food', 
    "text is 'cheese roll/food'");


#------------------------------------------------------------------------
# structured exception types
#------------------------------------------------------------------------

my $ex4 = Exception->new( type => 'ex4.foo.bar', 
                          info => 'information about ex4' );

ok( $ex4, 'created exception' );
is( $ex4->type(), 'ex4.foo.bar', 'ex4.type' );
is( $ex4->info(), 'information about ex4', 'ex4.info' );

is( $ex4->match_type('foo', 'ex4', 'ex4.foo', 'ex4.foo.bar'),
    'ex4.foo.bar', 'hander matched ex4.foo.bar' );
is( $ex4->match_type('bar', 'ex4', 'ex4.foo', 'ex4.bar.foo.bar'),
    'ex4.foo', 'hander matched ex4.foo' );
is( $ex4->match_type('bar', 'ex4', 'ex4.bar', 'ex4.bar.foo.bar'),
    'ex4', 'hander matched ex4' );
ok( ! defined $ex4->match_type('bar', 'baz', 'ex4.bar', 'ex4.bar.foo.bar'),
    'no handler matched' );


#-----------------------------------------------------------------------
# test throw()
#-----------------------------------------------------------------------

$Badger::Exception::FORMAT = '<type> error: <info>';

sub bar {
    shift->throw;
}

sub foo {
    bar(@_);
}    

my $throw = Exception->new( 
    type  => 'food', 
    info  => 'bread is not fresh',
    trace => 1
);

eval { foo($throw) };
my $catch = $@;

is( refaddr $throw, refaddr $catch, 'caught that which was thrown' );

like( $catch, qr/called from/, 'stack trace in text' );
my $stack = $catch->stack;
ok( $stack, 'got stack' );
is( scalar(@$stack), 3, 'stack has three frames' );
like( $stack->[0]->[1], qr/exception\.t/, 'called from exception.t' );
is( $stack->[0]->[2], 139, 'called from line 139' );
is( $stack->[0]->[3], 'main::bar', 'called from bar' );
is( $stack->[1]->[2], 148, 'called from line 148' );
is( $stack->[1]->[3], 'main::foo', 'called from foo' );
is( $stack->[2]->[3], '(eval)', 'called from eval' );



__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
