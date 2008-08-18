#============================================================= -*-perl-*-
#
# t/pod/patterns.t
#
# Test the regular expressions defined by Badger::Pod::Patterns.
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
use Badger::Pod::Patterns ':all';
use Badger::Test tests => 51;


#-----------------------------------------------------------------------
# $BLANK matches whitespace but not newlines
# qr/ [\s^\n] /x;
#-----------------------------------------------------------------------

like( ' ', $BLANK, '$BLANK matches space' );
like( "\t", $BLANK, '$BLANK matches tab' );
like( "\x{85}", $BLANK, '$BLANK matches \x{85}' );
like( "\x{2028}", $BLANK, '$BLANK matches \x{2028}' );
like( "\x{2029}", $BLANK, '$BLANK matches \x{2029}' );

unlike( "\n", $BLANK, '$BLANK does not match newline' );
unlike( "\r", $BLANK, '$BLANK does not match carriage return' );


#-----------------------------------------------------------------------
# $BLANK_LINE matches zero or more $BLANK characters and a newline
# qr/ (?: $BLANK* \n ) /x;
#-----------------------------------------------------------------------

like( "\n", qr/^$BLANK_LINE$/, '$BLANK_LINE matches newline' );
like( " \n", qr/^$BLANK_LINE$/, '$BLANK_LINE matches space and newline' );
like( " \t\n", qr/^$BLANK_LINE$/, '$BLANK_LINE matches space, tab and newline' );
like( " \x{85}\x{2028}\x{2029}\n", qr/^$BLANK_LINE$/, '$BLANK_LINE matches unicode spaces' );

unlike( " \t", qr/^$BLANK_LINE$/, '$BLANK_LINE does not match spaces without newline' );
unlike( "x\n", qr/^$BLANK_LINE$/, '$BLANK_LINE does not match non-space' );


#-----------------------------------------------------------------------
# $BLANK_LINES matches one or more blank lines
# qr/ (?: \n $BLANK_LINE+ ) /x;
#-----------------------------------------------------------------------

like( "\n\n", qr/^$BLANK_LINES$/, '$BLANK_LINES matches two newlines' );
like( "\n \t\n", qr/^$BLANK_LINES$/, '$BLANK_LINES matches two newlines with spaces' );
like( "\n\n\n", qr/^$BLANK_LINES$/, '$BLANK_LINES matches multiple newlines' );
like( "\n \t \n\t\t \n", qr/^$BLANK_LINES/, '$BLANK_LINES matches multiple newlines with spaces' );

unlike( " \t", qr/^$BLANK_LINES$/, '$BLANK_LINE does not match with leading whitespace' );
unlike( "x\n\n", qr/^$BLANK_LINES$/, '$BLANK_LINE does not match leading non-space' );
unlike( "\nx\n", qr/^$BLANK_LINES$/, '$BLANK_LINE does not match intermediate non-space' );


#-----------------------------------------------------------------------
# $WHITE_LINE and $WHITE_LINES match a single or multiple lines which
# contain at least one whitespace character, i.e. non-empty blank lines.
#-----------------------------------------------------------------------

like( " \n", qr/^$WHITE_LINE$/, '$WHITE_LINE matches space and newline' );
unlike( "\n", qr/^$WHITE_LINE$/, '$WHITE_LINE does not match newline' );

like( "\t\n \n", qr/^$WHITE_LINES$/, '$WHITE_LINES matches white lines' );
unlike( "\t\n\n", qr/^$WHITE_LINES$/, '$WHITE_LINE does not match with blank line' );


#-----------------------------------------------------------------------
# $PARA_SEPARATOR matches one or more blank lines or EOF 
# qr/ ($BLANK_LINES | $) /x;
#-----------------------------------------------------------------------

like( "", qr/^$PARA_SEPARATOR$/, '$PARA_SEPARATOR matches empty string' );
like( "\n", qr/^$PARA_SEPARATOR$/, '$PARA_SEPARATOR matches single newline' );
like( "\n\n", qr/^$PARA_SEPARATOR$/, '$PARA_SEPARATOR matches two newlines' );
like( "\n \t\n", qr/^$PARA_SEPARATOR$/, '$PARA_SEPARATOR matches two newlines with spaces' );
like( "\n\n\n", qr/^$PARA_SEPARATOR$/, '$PARA_SEPARATOR matches multiple newlines' );
like( "\n \t \n\t\t \n", qr/^$PARA_SEPARATOR$/, '$PARA_SEPARATOR matches multiple newlines with spaces' );


#-----------------------------------------------------------------------
# $OPTION_LINE matches an optional (space + text) up to the EOL or EOF
# qr/ (?: $BLANK+ .* )? (?: \n | $ ) /x;
#-----------------------------------------------------------------------

like( "", qr/^$OPTION_LINE$/, '$OPTION_LINE matches empty string' );
like( "\n", qr/^$OPTION_LINE$/, '$OPTION_LINE matches newline' );
like( " \n", qr/^$OPTION_LINE$/, '$OPTION_LINE matches space with newline' );
like( " blurb", qr/^$OPTION_LINE$/, '$OPTION_LINE matches blurb' );
like( " blurb\n", qr/^$OPTION_LINE$/, '$OPTION_LINE matches blurb with newline' );

unlike( "blurb\n", qr/^$OPTION_LINE$/, '$OPTION_LINE does not match blurb without space' );


#-----------------------------------------------------------------------
# $COMMAND_FORMAT matches the word after a =begin, =end, etc
#-----------------------------------------------------------------------

like(" word  \n\n", $COMMAND_FORMAT, '$COMMAND_FORMAT matches word with space and newlines' );
like(" word\n\n", $COMMAND_FORMAT, '$COMMAND_FORMAT matches word with newlines' );
like(" word\n", $COMMAND_FORMAT, '$COMMAND_FORMAT matches word with newline' );
like(" word", $COMMAND_FORMAT, '$COMMAND_FORMAT matches word' );
like("word", $COMMAND_FORMAT, '$COMMAND_FORMAT matches word without space' );

unlike("badger badger", $COMMAND_FORMAT, '$COMMAND_FORMAT does not match badger badger' );


#-----------------------------------------------------------------------
# $FORMAT_START and $FORMAT_END match the start/end of L<...> formats
#-----------------------------------------------------------------------

like("A<", qr/^$FORMAT_START$/, '$FORMAT_START matches A<' );
like("B<< ", qr/^$FORMAT_START$/, '$FORMAT_START matches B<< ' );
like("C<<< ", qr/^$FORMAT_START$/, '$FORMAT_START matches C<<< ' );

unlike('*<', qr/^$FORMAT_START$/, '$FORMAT_START does not match *<' );
unlike('A[', qr/^$FORMAT_START$/, '$FORMAT_START does not match A[' );
unlike("B<<", qr/^$FORMAT_START$/, '$FORMAT_START does not match B<<' );

like(">", qr/^$FORMAT_END$/, '$FORMAT_END matches >' );
like(" >>", qr/^$FORMAT_END$/, '$FORMAT_END matches  >>' );

unlike(">>", qr/^$FORMAT_END$/, '$FORMAT_END does not match >>' );

