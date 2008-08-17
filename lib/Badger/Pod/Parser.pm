#========================================================================
#
# Badger::Pod::Parser
#
# DESCRIPTION
#   Pod parser for Badger.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Parser;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    constants => 'OFF ON LAST',
    constant  => {
        PADDED => -1,
        FORMAT  => 0,
        LPAREN  => 1,
        RPAREN  => 2,
        LINE    => 3,
        CONTENT => 4,
    },
    exports   => {
        tags  => {
            merge => 'OFF ON PADDED',
        },
    },
    messages  => {
        cut_fail     => 'Failed to match to end of pod',
        mismatch     => "Format mismatch - opening '%s' does not match '%s' at line %s",
        unterminated => "Interminated %s%s format starting at line %s",
        unexpected   => "Unexpected '%s' at line %s",
    };

our $TAB_WIDTH      = 4;
our $PARA_SEPARATOR = qr/ (\n (?: \s* \n )+ | \z) /smx;
our $WHITE_LINES    = qr/ ^ \n (?: [ \t]+ \n )+ $ /x;
our $FORMAT_START   = qr/ ([A-Z]) ( < (?: <+ \s )? ) /x; 
our $FORMAT_END     = qr/ ( (?: \s >+ )? > ) /x; 
our $FORMAT_TOKEN   = qr/ (?: $FORMAT_START | $FORMAT_END ) /x;
our $SCAN_TO_POD    = qr/ \G (.*?) (^=\w+ | \z) /smx;
our $SCAN_TO_CUT    = qr/ \G (.*?) (^=cut (?-s: \n | [ \t].*?\n ) | \z) /smx;
our $SCAN_COMMAND   = qr/ \G =(\w+) (.*?) $PARA_SEPARATOR /smx;
our $SCAN_VERBATIM  = qr/ \G (\s+ .*?)    $PARA_SEPARATOR /smx;
our $SCAN_PARAGRAPH = qr/ \G (.+?)        $PARA_SEPARATOR /smx;
our $SCAN_FORMAT    = qr/ \G (.*?)        $FORMAT_TOKEN   /smx;

*init  = \&init_parser;
*parse = \&parse_blocks;


sub init_parser {
    my ($self, $config) = @_;
    $self->{ merge_verbatim } = $config->{ merge_verbatim } || 0;
    $self->{ expand_tabs    } = $config->{ expand_tabs    } || 0;
    $self->{ tab_width      } = $config->{ tab_width      } || $TAB_WIDTH;
#   $self->{ untrimmed      } = $config->{ untrimmed      } || 0;
    return $self;
}

sub parse_blocks {
    my ($self, $text, $line) = @_;
    my ($code, $pod);
    $line ||= 1;

    # scan for a block of up to the first Pod command
    while ($text =~ /$SCAN_TO_POD/g) {
        ($code, $pod) = ($1, $2);
        
        # leading text can be empty if Pod =cmd starts on the first character 
        if (length $code) {
            $self->parse_code($code, $line);
            $line += ($code =~ tr/\n//);
        }
        
        # Pod block can be empty if the file ends with a non-Pod section
        if (length $pod) {
            $text =~ /$SCAN_TO_CUT/g || return $self->error_msg('cut_fail');
            $pod .= $1 . $2;
            $self->parse_pod($pod, $line);
            $line += ($pod =~ tr/\n//);
        }
    }

    return $self;
}

sub parse_code {
    # nothing to do in base class
    shift 
}

sub parse_pod {
    my ($self, $text, $line) = @_;
    my ($type, $body, $gap);
    my $vmerge = $self->{ merge_verbatim } || 0;
    my $vtabs  = $self->{ expand_tabs };
    my $vtab   = ' ' x ($self->{ tab_width } || $TAB_WIDTH) if $vtabs;

    # TODO: handle first =pod cmd and last =cut command ?

    while (1) {
        if ($text =~ /$SCAN_COMMAND/cg) {
            ($type, $body, $gap) = ($1, $2, $3);
            $self->parse_command($type, $body, $line);
        }
        elsif ($text =~ /$SCAN_VERBATIM/cg) {
            ($body, $gap) = ($1, $2);

            if ($vmerge) {
                # merge_verbatim can be set to PADDED to only merge 
                # consecutive verbatim paragraphs if they are separated by 
                # line(s) that contain at least one whitespace character,
                # any other true value value merges them unconditionally
                while ( 
                    ($vmerge == PADDED ? $gap =~ $WHITE_LINES : 1) 
                    && $text =~ /$SCAN_VERBATIM/cg ) {
                    $body .= $gap . $1;
                    $gap = $2;
                }
            }

            # expand tabs if expand_tabs option set
            $body =~ s/\t/$vtab/g if $vtabs;

            $self->parse_verbatim($body, $line);
        }
        elsif ($text =~ /$SCAN_PARAGRAPH/cg) {
            ($body, $gap) = ($1, $2);
            $self->parse_paragraph($body, $line);
        }
        else {
            # the $SCAN_PARAGRAPH regex will gobble any remaining characters
            # to EOF, so if that fails then we've exhausted all the input
            last;
        }

        # update line count
        for ($body, $gap) {
            $line += ($_ =~ tr/\n//);
        }
    }
}

sub parse_command {
    my ($self, $type, $text, $line) = @_;
}    

sub parse_verbatim {
    my ($self, $text, $line) = @_;
}    

sub parse_paragraph {
    my ($self, $text, $line) = @_;
    my ($body, $type, $paren, $lparen, $rparen, $format, $where);
    my @stack = ( 
        # format, lparen, rparen, $line, $content
        [ '', '', '', $line, [] ] 
    );
    $line ||= 1;
    $self->debug("parsing paragraph at line $line\n") if $DEBUG;

    while ($text =~ /$SCAN_FORMAT/g) {
        ($body, $type, $lparen, $rparen) = ($1, $2, $3, $4);
        
        if (length $body) {
            push(@{ $stack[LAST]->[CONTENT] }, $body);
            $line += ($body =~ tr/\n//);
        }

        if (defined $type) {
            $self->debug("format start @ $line: $type$lparen\n") if $DEBUG;
            # construct right paren that we expect to match (without spaces)
            for ($rparen = $lparen) {
                s/\s$//;
                tr/</>/;
            }
            push(@stack, [ $type, $lparen, $rparen, $line, [ ] ]);
        }
        elsif (defined $rparen) {
            $self->debug("format end @ $line: $rparen\n") if $DEBUG;
            # strip whitespace for comparison against expected rparen
            for ($paren = $rparen) {
                s/^\s+//;
            }
            if ($paren eq $stack[LAST]->[RPAREN]) {
                # in the usual case, the token closes the current format...
                $format = pop(@stack);
                $format->[RPAREN] = $rparen;    # save actual closing token
                $format = $self->parse_format(@$format);
            }
            elsif (@stack > 1) {
                # ...but we also have to warn for lparen/rparen mismatch
                $where  = $stack[LAST]->[LINE];
                $where .= '-' . $line unless $line == $where;
                $self->warn_msg( mismatch => $stack[LAST]->[LPAREN], $rparen, $where );
                $format = $rparen;
            }
            else {
                # ...or if we get an end-of-format marker before any start
                $self->warn_msg( unexepected => $rparen, $line );
                $format = $rparen;
            }
            push(@{ $stack[LAST]->[CONTENT] }, $format);
        }
    }

    while (@stack > 1) {
        $format = pop @stack;
        $self->warn_msg( unterminated => @$format[FORMAT, LPAREN, LINE] );
        push(
            @{ $stack[-1]->[CONTENT] }, 
            $self->parse_format(@$format)
        );
    }
    $format = $stack[LAST];

    return wantarray
        ? @$format
        :  $format;
}

sub parse_format {
    my ($self, $type, $lparen, $rparen, $line, $content) = @_;
    return [$type, $lparen, $rparen, $line, $content];
}

1;

__END__        

while(@stack) {
    $result = $stack[-1]->add($self, $type, $para);
    if (! defined $result) {
        $self->warning($stack[-1]->error(), $name, $$line);
        last;
    }
    elsif (ref $result) {
        push(@stack, $result);
        last;
    }
    elsif ($result == REDUCE) {
        pop @stack;
        last;
    }
    elsif ($result == REJECT) {
        $self->warning($stack[-1]->error(), $name, $$line);
        pop @stack;
    }
    elsif (@stack == 1) {
        $self->warning("unexpected $type", $name, $$line);
        last;
    }
}
