#============================================================= -*-perl-*-
#
# t/pod/verbatim.t
#
# Test that merging of verbatim paragraphs works as expected.
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
use Badger::Pod 'Pod Nodes';
use Badger::Test
    tests => 12,
    debug => 'Badger::Pod::Parser Badger::Pod::Document',
    args  => \@ARGV;
    
my ($text, $pod, @blocks);

$text =<<EOF;
This is pre-amble

=head1 Badger::Pod::Parser Tests

This is a test document for the Badger::Pod::Parser tests in t/pod/parser.t.

    This is some verbatim text
    This is the next line

    This is the next block of verbatim text.
    There is a blank line before it
    
    This is the third block of verbatim text.
    There are four spaces on the line above it

This is another normal paragraph.
EOF



#-----------------------------------------------------------------------
# subclass parser to save verbatim blocks only
#-----------------------------------------------------------------------

package My::Pod::Parser;

use Badger::Class
    base => 'Badger::Pod::Parser';
    

sub parse {
    my $self = shift;
    $self->{ nodes  } = main::Nodes->new;
    $self->{ blocks } = [ ];
    $self->parse_blocks(@_);
}

sub parse_verbatim {
    my ($self, $text, $line) = @_;
    my $node = $self->{ nodes }->node( verbatim => {
        text => $text,
        line => $line,
    } );
    push(@{ $self->{ blocks } }, $node);
}

sub blocks {
    my $self = shift;
    my $blocks = $self->{ blocks };
    return wantarray
        ? @$blocks
        :  $blocks;
}

package main;

#-----------------------------------------------------------------------
# try first without mergin verbatim blocks
#-----------------------------------------------------------------------

#$pod = Pod( text => $text, %config );
$pod = My::Pod::Parser->new->parse($text);
ok( $pod, 'parsed pod' );
@blocks = $pod->blocks;
is( scalar(@blocks), 3, 'got 3 verbatim blocks' );
like( $blocks[0], qr/^\s*This is some verbatim text.*the next line$/s, 'first verbatim block' );
like( $blocks[1], qr/^\s*This is the next block.*before it$/s, 'second verbatim block' );
like( $blocks[2], qr/^\s*This is the third block.*above it$/s, 'third verbatim block' );


#-----------------------------------------------------------------------
# this time merge them unconditionally
#-----------------------------------------------------------------------

$pod = My::Pod::Parser->new( merge_verbatim => 1 )->parse($text);
ok( $pod, 'parsed pod with verbatim merged' );
@blocks = $pod->blocks;
is( scalar(@blocks), 1, 'got 1 verbatim block' );
like( $blocks[0], qr/^\s*This is some verbatim text.*above it$/s, 'one verbatim block' );


#-----------------------------------------------------------------------
# now try the PADDED (-1) option which only joins consecutive verbatim
# paras that are separated by non-empty blank lines.
#-----------------------------------------------------------------------

$pod = My::Pod::Parser->new( merge_verbatim => -1 )->parse($text);
ok( $pod, 'parsed pod with merged padded verbatim blocks' );
@blocks = $pod->blocks;
is( scalar(@blocks), 2, 'got 2 merged verbatim blocks' );
like( $blocks[0], qr/^\s*This is some verbatim text.*the next line$/s, 'first merged verbatim block' );
like( $blocks[1], qr/^\s*This is the next block.*before it.*above it$/s, 'second merged verbatim block' );
