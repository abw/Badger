#============================================================= -*-perl-*-
#
# t/core/factory.t
#
# Test the Badger::Factory module.
#
# Copyright (C) 2006-2008 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;

use lib qw( core/lib t/core/lib ./lib ../lib ../../lib );
use Badger::Test 
    tests => 29,
    debug => 'Badger::Factory',
    args  => \@ARGV;


#-----------------------------------------------------------------------
# define a factory object
#-----------------------------------------------------------------------

package Badger::Test::FactoryObject;
use Badger::Test;
use Badger::Factory;

my $factory = Badger::Factory->new(
    item => 'thingy',
    path => ['My', 'Your'],
);

ok( $factory, 'Created factory' );
my $widget = $factory->thingy('widget');
ok( $widget, 'fetched a widget from the factory' );
is( ref $widget, 'My::Widget', 'got a My::Widget object' );

# check we get a 'no default' error
ok(! $factory->try->thingy, 'No thingy' );
is( 
    $factory->reason, 
    'factory error - No default defined for thingy factory',
    'got no default error'
);

$factory->default('widget');
$widget = $factory->thingy;
ok( $widget, 'fetched a default widget from the factory' );
is( ref $widget, 'My::Widget', 'got a My::Widget object as the default' );



#-----------------------------------------------------------------------
# define a factory subclass for getting things
#-----------------------------------------------------------------------

package My::Factory;
use Badger::Class
    base => 'Badger::Factory';

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
    version   => 1,
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

$widget = My::Factory->item('Widget');
ok( $widget, 'got a widget' );
is( ref $widget, 'My::Widget', 'isa My::Widget object' );

# should also work in lower case
my $wodget = My::Factory->item('wodget');
ok( $wodget, 'got a wodget' );
is( ref $wodget, 'My::Wodget', 'isa My::Wodget object' );

# check we can pass args
$wodget = My::Factory->item( wodget => { name => 'Badger' } );
is( $wodget->name, 'Badger', 'wodget name is Badger' );

$wodget = My::Factory->item( wodget => name => 'Ferret' );
is( $wodget->name, 'Ferret', 'wodget name is Ferret' );


#-----------------------------------------------------------------------
# test it with named modules
#-----------------------------------------------------------------------

# dangly is mapped to My::Extra::Wudget module/class
my $wudget = My::Factory->item( dangly => { name => 'Dangly' } );
ok( $wudget, 'got a wudget' );
is( ref $wudget, 'My::Extra::Wudget', 'isa My::Extra::Wudget object' );
is( $wudget->name, '<< Dangly >>', 'wudget name is dangly' );

# spangly is mapped to My::Extra::Wudget module and My::Extra::Wudgetola class
$wudget = My::Factory->item( spangly => { name => 'Spangly' } );
ok( $wudget, 'got another wudget' );
is( ref $wudget, 'My::Extra::Wudgetola', 'isa My::Extra::Wudgetola object' );
is( $wudget->name, '** Spangly **', 'wudget name is spangly' );


#-----------------------------------------------------------------------
# test it with Your::Sparkly module defined inline above
#-----------------------------------------------------------------------

my $sparkly = My::Factory->item( sparkly => { name => 'Sparkly' } );
ok( $sparkly, 'got sparkly wudget' );
is( ref $sparkly, 'Your::Sparkly', 'isa Your::Sparkly object' );
is( $sparkly->name, 'Sparkly', 'sparkly name' );

my $dotted = My::Factory->item( 'extra.wudget' => { name => 'Dotted' } );
ok( $dotted, 'got dotted object' );


#-----------------------------------------------------------------------
# test Badger::Factory::Class
#-----------------------------------------------------------------------

package My::Widgets;

use Badger::Factory::Class
    item    => 'widget',
    path    => 'My You',
    widgets => {
        dangly  =>  'My::Extra::Wudget',
        spangly => ['My::Extra::Wudget', 'My::Extra::Wudgetola'],
    };

package main;

my $widgets = My::Widgets->new;
ok( $widget, 'created widgets factory' );
ok( $widgets->widget('widget'), 'got widget from class constructed factory' );
ok( $widgets->widget('wodget'), 'got wodget from class constructed factory' );
ok( $widgets->widget('dangly'), 'got dangly from class constructed factory' );


#-----------------------------------------------------------------------
# test AUTOLOAD spits out warnings
#-----------------------------------------------------------------------

ok( ! $widgets->try( answer => x => 42 ), 'cannot answer' );
like( $widgets->reason, qr/^Can't locate object method "answer" via package "My::Widgets" at/, 'Error message'  );


__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
