#============================================================= -*-perl-*-
#
# t/pod/html.t
#
# Test the Badger::Pod::View::HTML module.
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
use Badger::Pod 'Pod Views';
use Badger::Test
    tests => 10,
    debug => 'Badger::Pod::View::HTML Badger::Pod::View',
    args  => \@ARGV;
    

local $/ = undef;
my $text = <DATA>;
$text =~ s/==END.*$//s;
my $pod  = Pod( text => $text )->model;
my $view = Views->view('HTML');
print $pod->visit($view);

__DATA__
=pod 

This is a paragraph with B<bold> text and I<italic> text.

==END
some code 

=head1 Heading 1

This is the first paragraph

=head1 Heading 2

This is the second paragraph

    This is a block of verbatim code

=over

=item one

This is item one

=item two

This is item two

=back

This is some B<bold text> and some I<italic text>.
