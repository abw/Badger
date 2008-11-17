#============================================================= -*-perl-*-
#
# t/schema/fields.t
#
# Test the definition of Badger::Schema fields
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
use Badger::Test
    tests => 5,
    debug => 'Badger::Schema',
    args  => \@ARGV;

use Badger::Schema 'Schema SCHEMA';
my $schema;

pass( 'loaded Badger::Schema' );


#-----------------------------------------------------------------------
# specify fields as constructor parameter
#-----------------------------------------------------------------------

$schema = Schema(
    fields => {
        foo => 'text',
        bar => {
            type    => 'int',
            aliases => 'BAR Bar',
        },
    },
);
ok( $schema, 'created schema' );
is( $schema->fields->{ foo }->{ type }, 'text', 'got foo text field' );


#-----------------------------------------------------------------------
# define $FIELDS in a subclass
#-----------------------------------------------------------------------

package Badger::Schema::Test1;

use base 'Badger::Schema';
our $FIELDS = {
    bar => 'number',
};

package main;

$schema = Badger::Schema::Test1->new;
ok( $schema, 'created subclass schema' );
is( $schema->fields->{ bar }->{ type }, 'number', 'got bar field' );

