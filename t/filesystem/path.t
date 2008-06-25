#============================================================= -*-perl-*-
#
# t/filesystem/path.t
#
# Test the Badger::Filesystem::Path module
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ./lib ../lib ../../lib );
use strict;
use warnings;
use Badger::Filesystem::Path;
use Test::More tests => 2;

our $DEBUG = $Badger::Filesystem::Path::DEBUG = grep(/^-d/, @ARGV);
our $PATH  = 'Badger::Filesystem::Path';

my $path = $PATH->new('foo');
ok( $path, 'created a new file' );

test_path( 'foo', path => 'foo' );

sub test_path {
    my $path  = $PATH->new(shift);
    my %tests = @_;
    while (my ($key, $value) = each %tests) {
        is( $path->$key, $value, "$path $key is " . (defined $value ? $value : 'undefined') );
    }
}
    