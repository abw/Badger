#============================================================= -*-perl-*-
#
# t/pod/model.t
#
# Test the Badger::Pod::Parser::Model and B::P::Node::Model modules.
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
use Badger::Pod 'Pod Model_parser';
use Badger::Test
    tests => 10,
    debug => 'Badger::Pod::Parser::Model Badger::Pod::Node::Body',
    args  => \@ARGV;
    

#use Badger::Debug ':dump';
#my $parser = Model_parser->new;
#my $para   = $parser->parse_formatted("Hello World B<xxx>");
#print main->dump_data($para);
#use Data::Dumper;
#print Dumper($para);
#print "para: $para\n";
#print $para->text;

my $pod = Pod( text => <<EOF, on_warn => \&on_warn )->model;
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

EOF

print "POD $pod\n";

__END__
#-----------------------------------------------------------------------
# comment...
#-----------------------------------------------------------------------

$pod = Pod( text => <<EOF, on_warn => \&on_warn )->model;
=head1 Heading 1

This is the first B<paragraph>
EOF

ok( $pod, 'parsed pod' );

use Badger::Debug ':dump';
print main->dump_data($pod);
print "POD: $pod\n";

use Data::Dumper;
print Dumper($pod);
