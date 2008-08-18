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

use Badger::Pod::Patterns ':scan :misc $WHITE_LINES';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    utils     => 'self_params',
    constants => 'OFF ON LAST CODE',
    constant  => {
        PADDED  => -1,
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
        bad_cut      => 'Invalid =cut at the start of a POD section at line %s',
        mismatch     => "Format mismatch - opening '%s' does not match '%s' at line %s",
        unterminated => "Interminated %s%s format starting at line %s",
        unexpected   => "Unexpected '%s' at line %s",
        bad_command  => 'Invalid handler for %s command: %s',
        no_format    => 'No format specified for %s command at line %s',
        bad_format   => "Format mismatch: '%s %s' at line %s does not match '%s %s' at line %s",
    };

our $TAB_WIDTH  = 4;
our $COMMANDS   = {
    begin => 'parse_command_begin',     # requires special handling
    cut   => 'parse_command_cut',     
};

*init  = \&init_parser;
*parse = \&parse_blocks;


sub init_parser {
    my ($self, $config) = @_;
    $self->{ merge_verbatim } = $config->{ merge_verbatim } || 0;
    $self->{ expand_tabs    } = $config->{ expand_tabs    } || 0;
    $self->{ tab_width      } = $config->{ tab_width      } || $TAB_WIDTH;
    $self->init_commands(
        $self->class->hash_vars( COMMANDS => $config->{ commands } )
    );

    # save rest of config for other methods to reference on demand
    $self->{ config } = $config;
    
    return $self;
}

sub init_commands {
    my ($self, $cmds) = self_params(@_);
    my $c;
    
    $self->{ commands } = {
        # command handlers can be code refs or methods names
        map {
            $c = $cmds->{ $_ };
            $c = $self->can($c) 
              || $self->error_msg( bad_command => $_, $c )
                 unless ref $c eq CODE;
            $_ => $c;
        }
        keys %$cmds
    };

    $self->debug(
        "command handlers: ", 
        $self->dump_data($self->{ commands }), 
        "\n"
    ) if $DEBUG;

    return $self->{ commands };
}

sub parse_blocks {
    my ($self, $text, $line) = @_;
    my ($code, $pod);
    $line ||= 1;

    # scan for a block of up to the first Pod command
    while ($text =~ /$SCAN_TO_POD/cg) {
        ($code, $pod) = ($1, $2);

        # leading text can be empty if Pod =cmd starts on the first character 
        if (length $code) {
            $self->parse_code($code, $line);
            $line += ($code =~ tr/\n//);
        }
        
        $text =~ /$SCAN_TO_CODE/cg;
        $pod .= $1;
        $self->parse_pod($pod, $line);
        $line += ($pod =~ tr/\n//);
    }
    
    # consume any remaining text after the last (or no) pod command
    if ($text =~ /$SCAN_TO_EOF/) {
        $self->parse_code($1, $line) if length $1;
    }

    return $self;
}

sub parse_code {
    # nothing to do in base class
    shift 
}

sub parse_pod {
    my ($self, $text, $line) = @_;
    my $cmds   = $self->{ commands };
    my $vmerge = $self->{ merge_verbatim } || 0;
    my $vtabs  = $self->{ expand_tabs };
    my $vtab   = ' ' x ($self->{ tab_width } || $TAB_WIDTH) if $vtabs;
    my $para   = 1;     # paragaph count
    my ($name, $body, $gap, $handler);
    $line ||= 1;

    # TODO: handle first =pod cmd and last =cut command ?
    # TODO: check for =cut as first command and throw error

    while (1) {
        if ($text =~ /$SCAN_COMMAND/cg) {
            # a command is a paragraph starting with '=\w+'
            ($name, $body, $gap) = ($1, $2, $3);
            
            # some commands (like =begin and =cut) define custom handlers, 
            # otherwise we call the parse_command() method
            if ($handler = $cmds->{ $name }) {
                $self->debug("calling custom handler for $name command\n") if $DEBUG;
                $handler->($self, $name, $body, $line, $para, $gap, \$text);
            }
            else {
                $self->parse_command($name, $body, $line, $para, $gap, \$text);
            }
        }
        elsif ($text =~ /$SCAN_VERBATIM/cg) {
            # a verbatim block starts with whitespace
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

            $self->parse_verbatim($body, $line, $para, $gap, \$text);
        }
        elsif ($text =~ /$SCAN_PARAGRAPH/cg) {
            # a regular paragraph is anything that isn't command or verbatim
            ($body, $gap) = ($1, $2);
            $self->parse_paragraph($body, $line, $para, $gap, \$text);
        }
        else {
            # the $SCAN_PARAGRAPH regex will gobble any remaining characters
            # to EOF, so if that fails then we've exhausted all the input
            last;
        }

        # update line count and paragraph count
        for ($body, $gap) {
            $line += ($_ =~ tr/\n//);
        }
        $para++;
    }
}

sub parse_paragraph {
    my ($self, $text, $line) = @_;
    my ($body, $name, $paren, $lparen, $rparen, $format, $where);
    my @stack = ( 
        # format, lparen, rparen, $line, $content
        [ '', '', '', $line, [] ] 
    );
    $line ||= 1;
    $self->debug("parsing paragraph at line $line\n") if $DEBUG;

    while ($text =~ /$SCAN_FORMAT/g) {
        ($body, $name, $lparen, $rparen) = ($1, $2, $3, $4);
        
        if (length $body) {
            push(@{ $stack[LAST]->[CONTENT] }, $body);
            $line += ($body =~ tr/\n//);
        }

        if (defined $name) {
            $self->debug("format start @ $line: $name$lparen\n") if $DEBUG;
            # construct right paren that we expect to match (without spaces)
            for ($rparen = $lparen) {
                s/\s$//;
                tr/</>/;
            }
            push(@stack, [ $name, $lparen, $rparen, $line, [ ] ]);
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
    $format = $stack[LAST]->[CONTENT];

    return wantarray
        ? @$format
        :  $format;
}

sub parse_format {
    my ($self, $name, $lparen, $rparen, $line, $content) = @_;
    return [$name, $lparen, $rparen, $line, $content];
}

sub parse_verbatim {
    shift;
}    

sub parse_command {
    shift;
}


#-----------------------------------------------------------------------
# specialised handlers for commands that require additional processing
#-----------------------------------------------------------------------

sub parse_command_cut {
    my ($self, $name, $text, $line, $para, $gap, $podref) = @_;
    
    if ($para == 1) {
        # =cut must not appear as the first command paragraph in a POD section
        $self->warn_msg( bad_cut => $line );
    }
    else {
        $self->parse_command($name, $text, $line, $para, $podref);
    }
}

sub parse_command_begin {
    my ($self, $name, $text, $line, $para, $gap, $podref) = @_;
    my $lines = ($text =~ tr/\n//) + ($gap =~ tr/\n//);
    my $format;

    $self->debug("begin command: [$name] [$text]\n") if $DEBUG;
    
    if ($text =~ $COMMAND_FORMAT) {
        $format = $1;
        $self->debug("=begin $format") if $DEBUG;
    }
    else {
        # =begin must have a format string defined
        $self->warn_msg( no_format => '=' . $name, $line );
        $format = '';
    }
    
    if ($format =~ /^:/) {
        # if the name of a begin/end format starts with ':' then the content
        # is treated as regular pod
        return $self->parse_command($name, $text, $line);
    }
    else {
        # otherwise everything up to the =end is a raw code block - we scan
        # ahead using the $podref text reference to update the global regex
        # position - this effectively consumes the next block of text
        $$podref =~ /$SCAN_TO_END/cg
            || return $self->error('missing =end');     # TODO
        
        my ($code, $option) = ($1, $2);
        my $code_line = $line + $lines;
        $lines += ($code =~ tr/\n//);
        if ($option =~ $COMMAND_FORMAT) {
            $self->debug("=end $1") if $DEBUG;
            $self->warn_msg( bad_format => '=begin', $format, $line, '=end', $1, $line + $lines)
                unless $1 eq $format;
        }
        else {
            $self->warn_msg( no_format => '=end', $line + $lines);
        }

        # generate three events to mark the =begin, intermediate code and =end
        $self->parse_command( begin => $text, $line);
        $self->parse_code($code, $code_line);
        $self->parse_command( end => $text, $line);
    }
}


1;

__END__        
