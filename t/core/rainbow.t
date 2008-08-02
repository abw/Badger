#============================================================= -*-perl-*-
#
# t/core/rainbow.t
#
# Test the Badger::Rainbow module.
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
use Badger::Rainbow ANSI => 'dark bold red green blue yellow';
use Badger::Test 
    tests  => 3, 
    debug  => 'Badger::Rainbow',
    args   => \@ARGV;


my $red    = red("This is red");
my $green = green("This is green");
my $blue  = blue("This is blue");

is( $red,   "\e[31mThis is red\e[0m",   $red);
is( $green, "\e[32mThis is green\e[0m", $green);
is( $blue,  "\e[34mThis is blue\e[0m",  $blue);


__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
