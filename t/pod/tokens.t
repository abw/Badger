#============================================================= -*-perl-*-
#
# t/pod/tokens.t
#
# Test the Badger::Pod::Tokens factory module.
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
use Badger::Pod 'Tokens';
use Badger::Test
    tests => 15,
    debug => 'Badger::Pod::Tokens Badger::Factory Badger::Class',
    args  => \@ARGV;
    
my $tokens = Tokens;
ok( $tokens, 'got tokens class' );

# named parameters
my $code  = $tokens->item( code => text => 'example' );

$code  = $tokens->token( code => 'example' );
ok( $code, 'got code node' );
is( ref $code, 'Badger::Pod::Token::Code', 'checked code node class' );
is( $code->text, 'example' );
is( $code->line, 1 );

ok( $code->code, 'code is code' );
#ok( ! $code->pod, 'code is not pod' );
#ok( ! $code->paragraph, 'code is not paragraph' );

