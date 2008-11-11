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
    tests => 11,
    args  => \@ARGV;

use Badger::Exception trace => 1;

sub baz {
    shift->throw;
}

sub bar {
    baz(@_);
}

sub foo {
    bar(
        Badger::Exception->new(
            type  => 'food', 
            info  => 'bread is not fresh',
        )
    );
}

eval { foo() };
my $catch = $@;

like( $catch, qr/called from/, 'stack trace in text' );
my $stack = $catch->stack;
ok( $stack, 'got stack' );
is( scalar(@$stack), 4, 'stack has four frames' );
like( $stack->[0]->[1], qr/trace\.t/, 'called from trace.t' );
is( $stack->[0]->[2],  29, 'called from line 29' );
is( $stack->[0]->[3], 'main::baz', 'called from baz' );
is( $stack->[1]->[2], 33, 'called from line 33' );
is( $stack->[1]->[3], 'main::bar', 'called from bar' );
is( $stack->[2]->[2], 41, 'called from line 41' );
is( $stack->[2]->[3], 'main::foo', 'called from foo' );
is( $stack->[3]->[3], '(eval)', 'called from eval' );



__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
