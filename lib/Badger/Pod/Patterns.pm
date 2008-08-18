#========================================================================
#
# Badger::Pod::Patterns
#
# DESCRIPTION
#   Defines regular expressions for matching Pod tokens and constructs.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Patterns;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    exports   => {
        tags  => {
            space  => '$BLANK $BLANK_LINE $BLANK_LINES $WHITE_LINE $WHITE_LINES 
                       $PARA_SEPARATOR $OPTION_LINE',
            format => '$FORMAT_START $FORMAT_END $FORMAT_TOKEN', 
            scan   => '$SCAN_TO_EOF $SCAN_TO_POD $SCAN_TO_CUT $SCAN_TO_CODE 
                       $SCAN_TO_END $SCAN_COMMAND $SCAN_VERBATIM 
                       $SCAN_PARAGRAPH $SCAN_FORMAT',
            misc   => '$OPTION_LINE $COMMAND_FORMAT',
        },
    };

# whitespace, blank lines, separators, etc.
our $BLANK          = qr/ [ \t\x{85}\x{2028}\x{2029}] /x;
our $BLANK_LINE     = qr/ $BLANK* \n /x;
our $BLANK_LINES    = qr/ \n $BLANK_LINE+ /x;
our $WHITE_LINE     = qr/ $BLANK+ \n /x;
our $WHITE_LINES    = qr/ ^ $BLANK* \n $WHITE_LINE+ $ /x;
our $PARA_SEPARATOR = qr/ ($BLANK_LINES | $) /x;

# miscellaneous patterns
our $OPTION_LINE    = qr/ (?: $BLANK+ .* )? (?: \n | $ ) /x;
our $COMMAND_FORMAT = qr/ ^ $BLANK* (\S+) $BLANK* $PARA_SEPARATOR /x;

# embedded format strings
our $FORMAT_START   = qr/ ([A-Z]) ( < (?: <+ \s )? ) /x; 
our $FORMAT_END     = qr/ ( (?: \s >+ )? > ) /x; 
our $FORMAT_TOKEN   = qr/ (?: $FORMAT_START | $FORMAT_END ) /x;

# main scanning regexen
our $SCAN_TO_EOF    = qr/ \G (.+) /sx;
our $SCAN_TO_POD    = qr/ \G ( \A | .*? $BLANK_LINES) (=\w+) /smx;
our $SCAN_TO_CUT    = qr/ \G ( \A | .*? $BLANK_LINES =cut $OPTION_LINE | .*) /smx;
our $SCAN_TO_CODE   = qr/ ($SCAN_TO_CUT | $SCAN_TO_EOF) /x;
our $SCAN_TO_END    = qr/ \G (.*? $BLANK_LINES) =end ($OPTION_LINE) /smx; 
our $SCAN_COMMAND   = qr/ \G =(\w+) (.*?)  $PARA_SEPARATOR /smx;
our $SCAN_VERBATIM  = qr/ \G ($BLANK+ .*?) $PARA_SEPARATOR /smx;
our $SCAN_PARAGRAPH = qr/ \G (.+?)         $PARA_SEPARATOR /smx;
our $SCAN_FORMAT    = qr/ \G (.*?)         $FORMAT_TOKEN   /smx;



1;
__END__

