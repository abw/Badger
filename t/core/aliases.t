#============================================================= -*-perl-*-
#
# t/core/aliases.t
#
# Test the Badger::Class::Aliases module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( t/codon/lib ../t/codon/lib ./lib ../lib ../../lib );
use Badger::Test
    tests => 8,
    debug => 'Badger::Class::Aliases',
    args  => \@ARGV;


#-----------------------------------------------------------------------
# Alice 
#-----------------------------------------------------------------------

package Alice;

use Badger::Class
    base => 'Badger::Base';
    
use Badger::Class::Aliases
    type => 'driver',
    name => 'database',
    user => 'username',
    pass => 'password';

sub init {
    my ($self, $config) = @_;
    $self->init_aliases($config);
    @$self{ keys %$config } = values %$config;
    return $self;
}
    
package main;

my $alice = Alice->new( driver => 'abc', name => 'xyz', username => 'tom' );
ok( $alice, 'created Alice' );

is( $alice->{ type }, 'abc', 'Alice type' );
is( $alice->{ name }, 'xyz', 'Alice name' );
is( $alice->{ user }, 'tom', 'Alice user' );


#-----------------------------------------------------------------------
# Bob 
#-----------------------------------------------------------------------

package Bob;

use Badger::Class
    base => 'Badger::Base',
    aliases => {
        type => 'driver',
        name => 'database',
        user => 'username',
        pass => 'password',
    };

sub init {
    my ($self, $config) = @_;
    $self->init_aliases($config);
    @$self{ keys %$config } = values %$config;
    return $self;
}
    
package main;

my $bob = Alice->new( driver => 'ABC', name => 'XYZ', username => 'TOM' );
ok( $bob, 'created Bob' );

is( $bob->{ type }, 'ABC', 'Bob type' );
is( $bob->{ name }, 'XYZ', 'Bob name' );
is( $bob->{ user }, 'TOM', 'Bob user' );
