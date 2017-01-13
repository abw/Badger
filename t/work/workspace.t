#============================================================= -*-perl-*-
#
# t/work/workspace.t
#
# Test the Badger::Workspace module.
#
# Copyright (C) 2008-2014 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib => ' ../../lib',
    Utils => 'Bin';

use Badger::Test
    debug => 'Badger::Workspace',
    args  => \@ARGV;

eval "require Badger::Codec::YAML";
if ($@) {
    skip_all($@);
}
else {
    plan(25);
}

use Badger::Debug ':all';
use Badger::Workspace;
use constant WORKSPACE => 'Badger::Workspace';

my $workspace = WORKSPACE->new(
    root => Bin->dir( test_files => 'workspace1' ),
);

ok( $workspace, 'created workspace' );
is( $workspace->config('example.foo'), 'The Foo Item', 'got example.foo from config' );
is( $workspace->config('example.bar'), 'The Bar Item', 'got example.bar from config' );
is( $workspace->config('name'), 'Test Workspace', 'got workspace name from config' );

my $goodbye = $workspace->file('goodbye.txt');
ok( $goodbye, 'got goodbye.txt file' );
ok( $goodbye->exists, 'goodbye.txt file exists' );

my $txt = $goodbye->text;
chomp $txt;
is( $txt, 'Goodbye World!', 'got file text' );

my $greetings = $workspace->config('greetings');
ok( $greetings, 'got greetings config' );
is( $greetings->{ hello }, 'Hello World!', 'got hello greeting' );
is( $workspace->config('greetings.hello'), 'Hello World!', 'got greetings.hello' );


#-----------------------------------------------------------------------------
# 'dirs' config section in config/workspace.yaml maps 'first' and 'second'
# directories onto 'one' and 'two'
#-----------------------------------------------------------------------------

my $dir1 = $workspace->dir('first');
ok( $dir1, 'got first dir' );
is( $dir1->name, 'one', 'first dir is mapped to one' );


my $foo1 = $workspace->file('one/foo');
ok( $foo1, 'got one/foo' );

my $foo2 = $workspace->file('first/foo');
ok( $foo2, 'got first/foo' );
is( $foo1->text, $foo2->text, 'file contents match ' );

my $text = $foo2->text;
chomp($text);
is( $text, 'This is one/foo', $text );


#-----------------------------------------------------------------------------
# This workspace has a separate config/dirs.yaml file
#-----------------------------------------------------------------------------

my $workspace2 = WORKSPACE->new(
    root => Bin->dir( test_files => 'workspace2' ),
);

ok( $workspace2, 'got second workspace' );
my $five = $workspace2->file('charlie/five');
ok( $five, 'got charlie/five file' );

is( $five->parent->name, 'four', 'charlie dir is actually five' );

my $text2 = $five->text;
chomp($text2);
is( $text2, 'This is three/four/five', $text2 );


#-----------------------------------------------------------------------------
# Attach the second workspace to the first
#-----------------------------------------------------------------------------

$workspace2->attach($workspace);

my $greets2 = $workspace2->parent_config('greetings');
ok( $greets2, 'got greetings from parent config' );
is( $greets2->{ hello }, 'Hello World!', 'got parent hello greeting' );

my $greets3 = $workspace2->config('greetings');
ok( $greets3, 'got greetings config inherited from parent' );
is( $greets3->{ hello }, 'Hello World!', 'got hello greeting' );


# I had some inheritance rules in for a while, but it made things too
# complicated.  For now we assume that all configuration data can be inherited
# from a parent workspace
#ok( ! $workspace2->config('fruit'), 'no local or inherited fruit' );

ok( $workspace2->config('fruit'), 'inherited fruit' );
