#============================================================= -*-perl-*-
#
# t/core/dump.t
#
# Test the Badger::Debug module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;

use lib qw( ./lib ../lib ../../lib t/core/lib );
use Badger::Debug;
use Badger::Base;
use Badger::Test 
    tests => 1,
    debug => 'Badger::Debug',
    args  => \@ARGV;
    


#-----------------------------------------------------------------------
# test dump methods
#-----------------------------------------------------------------------

package My::Badger::Base;
use base 'Badger::Base';
use Badger::Debug ':debug :dump';

sub init{
    my ($self, $config) = @_;
    @$self{ keys %$config } = values %$config;
    return $self;
}

package My::Badger::One;
use base 'My::Badger::Base';
use Badger::Debug dumps => 'x y';

sub init{
    my ($self, $config) = @_;
    @$self{ keys %$config } = values %$config;
    return $self;
}

package My::Badger::Two;
use base 'My::Badger::Base';

sub NOT_dumper {
    my ($self, $indent) = @_;
    $self->dump_hash($self,$indent,'-hidden');
}

package My::Badger::Tre;
use base 'My::Badger::Base';
use Badger::Debug ':dump';

package main;

my $one = My::Badger::One->new( x => 10, y => 20, secret => 'password' );
my $two = My::Badger::Two->new( pi => 3.142, e => 2.718, one => $one, hidden => 'treasure' );
my $tre = My::Badger::Tre->new( 
    two    => $two,
    person => { 
        name  => 'Arthur Dent', 
        email => 'dent@tt2.org',
    },
    products => ['widget123', 'doodah99'],
);

my $text = $tre->dump;
#print $text;
like( $text, qr/one => \{\s+x => 10,\s+y => 20\s+\}/, 'partial dump of one' );
