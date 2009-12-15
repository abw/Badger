#============================================================= -*-perl-*-
#
# t/filesystem/visitor
#
# Test the Badger::Filesystem::Visitor module.
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
use File::Spec;
use Badger::Filesystem 'FS';
use Badger::Test 
    tests => 25,
    debug => 'Badger::Filesystem::Visitor',
    args  => \@ARGV;

our $here = -d 't' ? FS->dir(qw(t filesystem)) : FS->dir;
our $tdir = $here->dir('testfiles')->must_exist;
our $vdir = $tdir->dir('visitor')->must_exist;


my ($visitor, @files);

#-----------------------------------------------------------------------
# basic tests
#-----------------------------------------------------------------------

$visitor = $tdir->visit( 
    recurse => 1, 
    dirs    => 0, 
    files   => 'foo'
);
ok( $visitor, 'got visitor' );
is( ref $visitor, 'Badger::Filesystem::Visitor', 'isa visitor object' );

@files = $visitor->collect;
is( scalar @files, 3, 'got 3 foo files' );

@files = $tdir->visit( 
    recurse => 1, 
    dirs    => 0, 
    files   => ['foo', 'bar'],
)->collect;
is( scalar @files, 5, 'got 5 foo and bar files' );

@files = $tdir->visit( 
    dirs        => 0, 
    files       => qr/foo|bar/,
    in_dirs     => 1,
    not_in_dirs => '.svn',
)->collect;
is( scalar @files, 5, 'got 5 foo or bar files via regex' );


#-----------------------------------------------------------------------
# wildcards
#-----------------------------------------------------------------------

# all html files
@files = $vdir->visit( 
    dirs        => 0, 
    files       => '*.html',
    in_dirs     => 1,
    not_in_dirs => '.svn',
)->collect;

print STDERR "HTML files: \n", join("\n  ", @files), "\n" if $DEBUG;

is( scalar @files, 2, 'got 2 HTML files' );
is( join(' ', sort map { $_->name } @files), 
    'goodbye.html hello.html',
    'got all HTML files' );

# all goodbye files with a 3 character extension
@files = $vdir->visit( 
    dirs        => 0, 
    files       => 'goodbye.???',
    in_dirs     => 1,
    not_in_dirs => '.svn',
)->collect;

print STDERR "goodbye files: \n", join("\n  ", @files), "\n" if $DEBUG;

is( scalar @files, 2, 'got 2 goodbye files' );
is( join(' ', sort map { $_->name } @files), 
    'goodbye.bak goodbye.txt',
    'got all goodbye files' );

# same again using wilder wildcard (checks that '.' is not wild)
@files = $vdir->visit( 
    dirs        => 0, 
    files       => '*.???',
    in_dirs     => 1,
    not_in_dirs => ['.svn', 'tm?'],
)->collect;

print STDERR "wild files: \n", join("\n  ", @files), "\n" if $DEBUG;

is( scalar @files, 3, 'got 3 wild files' );
is( join(' ', sort map { $_->name } @files), 
    'goodbye.bak goodbye.txt hello.txt',
    'got all wild files' );

# same again with tighter wildcard
@files = $vdir->visit( 
    dirs        => 0, 
    files       => 'g*.???',
    in_dirs     => 1,
    not_in_dirs => ['.svn', 'tm?'],
)->collect;

print STDERR "wild goodbye files: \n", join("\n  ", @files), "\n" if $DEBUG;

is( scalar @files, 2, 'got 2 wild goodbye files' );
is( join(' ', sort map { $_->name } @files), 
    'goodbye.bak goodbye.txt',
    'got all wild goodbye files' );



#-----------------------------------------------------------------------
# subroutine filters
#-----------------------------------------------------------------------


# small files
@files = $vdir->visit( 
    dirs        => 0, 
    files       => sub { shift->size < 100 },
    in_dirs     => 1,
    not_in_dirs => '.svn',
)->collect;

print STDERR "small files: \n", join("\n  ", @files), "\n" if $DEBUG;

is( scalar @files, 6, 'got 6 small files' );
is( join(' ', sort map { $_->name } @files), 
    'README goodbye.bak hello.txt mushroom small snake',
    'got all small files' );


# medium files
@files = $vdir->visit( 
    dirs        => 0, 
    files       => sub { my $size = shift->size; $size >= 100 && $size < 420 },
    in_dirs     => 1,
    not_in_dirs => '.svn',
)->collect;

print STDERR "medium files: \n", join("\n  ", @files), "\n" if $DEBUG;

is( scalar @files, 3, 'got 3 medium files' );
is( join(' ', sort map { $_->name } @files), 
    'badger goodbye.txt medium',
    'got all small files' );

# large files
@files = $vdir->visit( 
    dirs        => 0, 
    files       => sub { shift->size > 420 },
    in_dirs     => 1,
    not_in_dirs => ['.svn', 'tmp'],
)->collect;

print STDERR "large files: \n", join("\n  ", @files), "\n" if $DEBUG;

is( scalar @files, 3, 'got 3 large files' );
is( join(' ', sort map { $_->name } @files), 
    'goodbye.html hello.html large',
    'got all large files' );

# directories containing a README file
@files = $vdir->visit( 
    dirs        => sub { shift->file('README')->exists },
    files       => 0,
    in_dirs     => 1,
    not_in_dirs => '.svn',
)->collect;

print STDERR "dirs with README files: \n", join("\n  ", @files), "\n" if $DEBUG;

is( scalar @files, 1, 'got 1 dir with README' );
is( join(' ', sort map { $_->name } @files), 
    'tmp',
    'got all dirs with README files in' );



#-----------------------------------------------------------------------
# all-in-one test with default arguments
#-----------------------------------------------------------------------

@files = grep { $_ !~ /svn/ } $vdir->collect;

print STDERR "default files: \n", join("\n  ", @files), "\n" if $DEBUG;

is( scalar @files, 6, 'got  default files' );
is( join(' ', sort map { $_->name } @files), 
    'large medium one small tmp two',
    'got all default files' );



#-----------------------------------------------------------------------
# visitor callbacks
#-----------------------------------------------------------------------

my $n = 0;
@files = $vdir->visit(
    at_file => sub { $n++ }
);
is( $n, 3, 'visited three files via a callback' );



#-----------------------------------------------------------------------
# subclass
#-----------------------------------------------------------------------

package My::Test::Visitor;
use base 'Badger::Filesystem::Visitor';

our $FILES       = qr/^good/;
our $DIRS        = 0;
our $IN_DIRS     = 1;
our $NOT_IN_DIRS = ['.svn', 'tmp'];

package main;

@files = $vdir->collect( My::Test::Visitor->new );
print STDERR "subclass files: \n", join("\n  ", @files), "\n" if $DEBUG;
is( join(' ', sort map { $_->name } @files), 
    'goodbye.bak goodbye.html goodbye.txt',
    'got all subclass files' );
