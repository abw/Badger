#============================================================= -*-perl-*-
#
# t/pod/errors.t
#
# Test that various Pod errors are detected by Badger::Pod::Parser and co.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2008 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Pod 'Pod';
use Badger::Test
    tests => 13,
    debug => 'Badger::Pod::Parser Badger::Pod::Document',
    args  => \@ARGV;
    
my $pod;
my @errs;

sub on_warn {
    push(@errs, @_);
}

#-----------------------------------------------------------------------
# =cut is not allowed as the first command in a POD section
#-----------------------------------------------------------------------

$pod = Pod( text => <<EOF, on_warn => \&on_warn )->model;
This is some code

=cut This is Not Allowed

This is more code
EOF

ok( $pod, 'parsed pod with bad cut' );
is( scalar(@errs), 1, 'one error for bad cut' );
is( $errs[0], 'Invalid =cut at the start of a POD section at line 3', 'got bad cut error' );


#-----------------------------------------------------------------------
# =begin and =end must have formats specified
#-----------------------------------------------------------------------

@errs = ();
$pod = Pod( text => <<EOF, on_warn => \&on_warn )->model;
This is some code

=begin

This is in the begin block

=end
EOF

ok( $pod, 'parsed pod with bad begin' );
is( scalar(@errs), 2, 'two errors for bad begin' );
is( $errs[0], 'No format specified for =begin command at line 3', 'got bad begin error' );
is( $errs[1], 'No format specified for =end command at line 7', 'got bad end error' );


#-----------------------------------------------------------------------
# =begin and =end formats must match
#-----------------------------------------------------------------------

@errs = ();
$pod = Pod( text => <<EOF, on_warn => \&on_warn )->model;
=begin cheese

This is in the begin block

=end crackers
EOF

ok( $pod, 'parsed pod with bad begin/end' );
is( scalar(@errs), 1, 'one errors for bad begin/end' );
is( $errs[0], "Format mismatch: '=begin cheese' at line 1 does not match '=end crackers' at line 5",
    'got bad begin/end error' );


#-----------------------------------------------------------------------
# missing =back for =over
#-----------------------------------------------------------------------

@errs = ();
$pod = Pod( text => <<EOF, on_warn => \&on_warn )->model;
=over hello

=item one

This is item one

=head1 cheese

Not allowed
EOF

ok( $pod, 'parsed pod with missing back' );
is( scalar(@errs), 1, 'one errors for missing back' );
is( $errs[0], "Missing =back to terminate =over at line 7",
    'got missing back error' );

