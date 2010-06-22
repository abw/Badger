#============================================================= -*-perl-*-
#
# t/core/modules.t
#
# Test the Badger::Modules module.
#
# Copyright (C) 2006-2010 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( core/lib t/core/lib ./lib ../lib ../../lib );
use Badger::Test 
    debug => 'Badger::Modules',
    args  => \@ARGV,
    tests => 13;

use Badger::Modules;
pass('Loaded Badger::Modules');


#-----------------------------------------------------------------------
# define a modules object
#-----------------------------------------------------------------------

my $modules = Badger::Modules->new(
    path     => ['My', 'Your'],
    tolerant => 1,
);

ok( $modules, 'Created module manager' );

# this should be located in the first path, e.g. My::Widget
my $widget = $modules->module('widget');
is( $widget, 'My::Widget', "got widget module: $widget" );

# this should be located in the second path, e.g. Your::Doodah
my $doodah = $modules->module('doodah');
ok( $doodah, "got doodah module: $doodah" );

# this should fail because we can't automatically capitalise it
my $url = $modules->module('url');
ok( ! $url, "could not find url" );

# provide a name lookup
$modules->names(
    url => 'URL',
);

# should find it now
$url = $modules->module('url');
ok( $url, "got URL module: $url" );

# should also be able to define the name mapping up front
$modules = Badger::Modules->new(
    item  => 'thingy',
    path  => ['My', 'Your'],
    names => {
        url => 'URL',
    },
);
ok( $modules->module('url'), 'got url module again' );

# this should fail
eval { $modules->module('fail') };

if ($@) {
    like( $@, qr/Can't locate Some.+Module/, "error thrown on missing module" );
    print "caught: ", "$@\n";
    print "error: ", $modules->error, "\n";

}
else {
    fail('Should have failed to load "fail" module');
};


#-----------------------------------------------------------------------
# define a modules subclass
#-----------------------------------------------------------------------

package My::Modules;

use Badger::Class
    base => 'Badger::Modules';

our $ITEM       = 'thing';
our $THING_PATH = ['My', 'Your'];
our $THINGS     = {
    dangly  =>  'My::Extra::Wudget',
    spangly => ['My::Extra::Wudget', 'My::Extra::Wudgetola'],
};


#-----------------------------------------------------------------------
# define a class inline to illustrate autoload defeating
#-----------------------------------------------------------------------

package Your::Sparkly;

use Badger::Class
    version   => 1,     # defines VERSION to indicate class is already loaded
    base      => 'Badger::Base',
    accessors => 'name';

sub init {
    my ($self, $config) = @_;
    $self->{ name } = $config->{ name };
    return $self;
}
        

#-----------------------------------------------------------------------
# test it with modules loaded from $THING_PATH
#-----------------------------------------------------------------------

package main;

$widget = My::Modules->module('Widget');
is( $widget, 'My::Widget', 'My::Widget' );

# should also work in lower case
my $wodget = My::Modules->module('wodget');
is( $wodget, 'My::Wodget', 'My::Wodget' );


#-----------------------------------------------------------------------
# test it with Your::Sparkly module defined inline above
#-----------------------------------------------------------------------

my $sparkly = My::Modules->module('sparkly');
is( $sparkly, 'Your::Sparkly', 'Your::Sparkly' );


#-----------------------------------------------------------------------
# test that it still loads a module, even if a (limited) symbol table
# already exists
#-----------------------------------------------------------------------

BEGIN {
    no warnings 'once';
    $Your::Answer::DEBUG = 1;
}

my $answer = My::Modules->module('answer');
is( $answer, 'Your::Answer', 'Your::Answer' );
is( Your::Answer::answer(), 42, 'Your::Answer is 42' );



__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
