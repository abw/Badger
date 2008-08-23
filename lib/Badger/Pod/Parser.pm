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

use Badger::Pod 'Nodes';
use Badger::Pod::Patterns ':scan :misc $WHITE_LINES';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Prototype',
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
        bad_cut      => 'Invalid =cut at the start of a POD section',
        bad_command  => 'Invalid handler for %s command: %s',
        bad_format   => "Format mismatch: '%s %s' at line %s does not match '%s %s' at line %s",
        no_format    => 'No format specified for %s command',
        mismatch     => "Format mismatch - opening '%s' does not match '%s'",
        unterminated => "Interminated %s%s format",
        unexpected   => "Unexpected '%s'",
    };

our $TAB_WIDTH  = 4;

*init  = \&init_parser;


sub init_parser {
    my ($self, $config) = @_;
    $self->{ merge_verbatim } = $config->{ merge_verbatim } || 0;
    $self->{ expand_tabs    } = $config->{ expand_tabs    } || 0;
    $self->{ tab_width      } = $config->{ tab_width      } || $TAB_WIDTH;

    # save rest of config for other methods to reference on demand
    $self->{ config } = $config;
    
    return $self;
}

sub nodes {
    my $self = shift->prototype;
    $self->{ nodes } ||= Nodes->new($self->{ config });
}

sub node {
    shift->nodes->node(@_);
}

sub parse {
    my ($self, $text, $name, $line) = @_;
    $self = $self->prototype unless ref $self;
    local $self->{ name } = $name;
    $self->parse_blocks($text, $line);
}

sub parse_blocks {
    my ($self, $text, $line) = @_;
    my ($code, $pod);
    $line ||= 1;

    $self->debug("parse_blocks() at line $line\n") if $DEBUG;

    # scan for a block of text up to the first Pod command
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
    $_[0]->debug("parse_code() at line $_[2]\n") if $DEBUG;
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
    $text =~ s/\s+$//g;
    local $self->{ line } = \$line;

    $self->debug("parse_pod() at line $line\n") if $DEBUG;

    while (1) {
        if ($text =~ /$SCAN_COMMAND/cg) {
            # a command is a paragraph starting with '=\w+'
            ($name, $body, $gap) = ($1, $2, $3);

            # some commands (like =begin and =cut) define custom handlers, 
            # otherwise we call the parse_command() method
            if ($handler = $self->can('parse_command_' . $name)) {
                $self->debug("calling custom parse_command_$name handler\n") if $DEBUG;
                $handler->($self, $name, $body, $gap, $line, $para, \$text);
            }
            else {
                $self->parse_command($name, $body, $line);
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

            $self->parse_verbatim($body, $line);
        }
        elsif ($text =~ /$SCAN_PARAGRAPH/cg) {
            # a regular paragraph is anything that isn't command or verbatim
            ($body, $gap) = ($1, $2);
            $self->parse_paragraph($body, $line);
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

sub parse_command { 
    $_[0]->debug("parse_command() at line $_[2]\n") if $DEBUG;
}

sub parse_verbatim { 
    $_[0]->debug("parse_verbatim() at line $_[2]\n") if $DEBUG;
}

sub parse_paragraph {
    my ($self, $text, $line) = @_;
    $self->debug("parse_formatted() at line $line\n") if $DEBUG;
    $self->parse_formatted($text, $line);
}

sub parse_formatted {
    my ($self, $text, $line) = @_;
    my ($body, $name, $paren, $lparen, $rparen, $format, $where);
    my @stack = ( 
        # format, lparen, rparen, $line, $content
        [ '', '', '', $line, [] ] 
    );
    $line ||= 1;
    $text =~ /^\s*/scg;

    $self->debug("parse_formatted() at line $line\n") if $DEBUG;

    while ($text =~ /$SCAN_FORMAT/cg) {
        ($body, $name, $lparen, $rparen) = ($1, $2, $3, $4);
        
        if (length $body) {
            push(@{ $stack[LAST]->[CONTENT] }, $self->parse_plain_text($body, $line) );
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
                $self->warning( mismatch => $stack[LAST]->[LPAREN], $rparen, $where );
                $format = $rparen;
            }
            else {
                # ...or if we get an end-of-format marker before any start
                $self->warning( unexepected => $rparen, $line );
                $format = $rparen;
            }
            push(@{ $stack[LAST]->[CONTENT] }, $format);
        }
    }
    if ($text =~ /$SCAN_TO_EOF/g) {
        push(@{ $stack[LAST]->[CONTENT] }, $self->parse_plain_text($1, $line) );
    }

    while (@stack > 1) {
        $format = pop @stack;
        $self->warning( unterminated => @$format[FORMAT, LPAREN, LINE] );
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

sub parse_plain_text {
    my ($self, $text, $line) = @_;
    $self->debug("parse_plain_text() at line $line\n") if $DEBUG;
    return $text;
}

sub parse_format {
    my ($self, $name, $lparen, $rparen, $line, $content) = @_;
    $self->debug("parse_format($name$lparen...$rparen) at line $line\n") if $DEBUG;
    return [$name, $lparen, $rparen, $line, $content];
}

sub parse_data { 
    $_[0]->debug("parse_data() at line $_[2]\n") if $DEBUG;
}



#-----------------------------------------------------------------------
# specialised handlers for commands that require additional processing
#-----------------------------------------------------------------------

sub parse_command_cut {
    my ($self, $name, $body, $gap, $line, $para) = @_;

    # =cut must not appear as the first command paragraph in a POD section
    $self->warning( bad_cut => $line )
        if $para == 1;
}

sub parse_command_pod {
    my ($self, $name, $body, $gap, $line, $para) = @_;
    
    # =pod should not appear anywhere other than the first command
    $self->warning( bad_pod => $line )
        unless $para == 1;
}

sub parse_command_begin {
    my ($self, $name, $body, $gap, $line, $para, $textref) = @_;
    my $lines = ($body =~ tr/\n//) + ($gap =~ tr/\n//);
    my $format;

    if ($body =~ $COMMAND_FORMAT) {
        $format = $1;
        $self->debug("=begin $format at line $line\n") if $DEBUG;
    }
    else {
        # =begin must have a format string defined
        $self->warning( no_format => '=' . $name, $line );
        $format = '';
    }
    
    if ($format =~ /^:/) {
        # if the name of a begin/end format starts with ':' then the content
        # is treated as regular pod
        return $self->parse_command($name, $body, $line);
    }
    else {
        # otherwise everything up to the =end is a raw code block - we scan
        # ahead using the $podref text reference to update the global regex
        # position - this effectively consumes the next block of text
        $$textref =~ /$SCAN_TO_END/cg
            || return $self->error('missing =end');     # TODO
        
        my ($data, $end_text) = ($1, $2);
        my $data_line  = $line + $lines;
        my $data_lines = ($data =~ tr/\n//);
        my $end_line   = $line + $lines + $data_lines;
        
        if ($end_text =~ $COMMAND_FORMAT) {
            $self->debug("=end $1 at line $end_line\n") if $DEBUG;
            $self->warn_msg( 
                bad_format => '=begin', $format, $line, 
                              '=end', $1, $end_line
            ) unless $1 eq $format;
        }
        else {
            $self->warning( no_format => '=end', $end_line );
        }
        
        # generate three events to mark the =begin, intermediate data and =end
        $self->debug("triggering =begin command event at line $line\n") if $DEBUG;
        $self->parse_command( begin => $body, $line );
        $self->debug("triggering data event at line $data_line\n") if $DEBUG;
        $self->parse_data($data, $data_line);
        $self->debug("triggering =end command event at line $end_line\n") if $DEBUG;
        $self->parse_command( end => $end_text, $end_line);

        # newlines in $body and $gap will be counted by caller, we need to
        # account for newlines in $data and $end_text
        $data_lines += ($end_text =~ tr/\n//);
        $self->debug("begin block has consumed $data_lines newlines that need to be accounted for\n")
            if $DEBUG;
        $self->adjust_line($data_lines);
    }
}

sub adjust_line {
    my $self = shift;
    my $line = $self->{ line } || return;
    $$line += shift;
}


#-----------------------------------------------------------------------
# methods for error handling and debugging
#-----------------------------------------------------------------------

sub warning {
    my $self = shift;
    my $line = pop;     # $line is last argument
    my $text = $self->message(@_);
    my $name = $self->{ name };
    return $name
        ? $self->warn_msg( at_file_line => $text, $name, $line )
        : $self->warn_msg( at_line => $text, $line );
}

sub debug_extract {
    my ($self, $type, $text, $line) = @_;
    $text =~ s/\n/\\n/g;
    $text = substr($text, 0, 61) . '...' if length $text > 64;
    $self->debug_up(2, "[$type\@$line|$text]\n");
}


1;

__END__

=head1 NAME

Badger::Pod::Parser - base class Pod parser

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

This module implements a base class parser for Perl's Plain Old Documentation
(POD) format.  It is designed to be subclasses in order to do anything 
useful.

The documentation is still largely TODO. Look at the code of
L<Badger::Pod::Parser::Model> for examples of how the base class parser can be
extended.

=head1 METHODS

Any or all of these methods should be redefined in a subclass to do 
something useful.  By themselves they parse and validate the Pod document,
but don't generate or return any data.  The only exception to that rule 
is the L<parse_formatted()> method which does construct and return a
data structure representing the parsed text.

=head2 parse($text,$name,$line)

This method parses the C<$text> passed as the first argument.  A C<$name>
may be passed as an optional second argument.  This will be added to any 
warnings raised.  The third optional argument is a starting C<$line>
number.  This defaults to C<1>.

    $parser->parse($text);
    $parser->parse($text,$name);
    $parser->parse($text,$name,$line);

The method doesn't generate or return any data.  It simply starts the 
parsing process by calling L<parse_blocks()>.

=head2 parse_blocks($text,$line)

This method parses the C<$text> passed as the first argument, looking for
raw code blocks and POD markup.  For each block of code, it calls the 
L<parse_code()> method.  For each Pod block, it calls L<parse_pod()>

=head2 parse_code($text,$line)

This method is called whenever a raw code block is identified in the 
source document.  It does nothing in the base class but can be redefined
to do something useful in a subclass.

=head2 parse_pod($text,$line)

This method is called whenever a POD block is identified in the source
document. It splits the block into different paragraph types and calls the
appropriate method for each.

Command paragraphs begin with a C<=> at the start of the line.

    =head1 Example of a Command Paragaph

Verbatim paragraphs are indented, ordinary paragraphs aren't.

        Example of a verbatim paragraph (indented)
    
    Example of an ordinary paragraph

In the case of ordinary and verbatim paragraphs, the L<parse_paragraph()>
and L<parse_verbatim()> methods are called.  Consecutive verbatim paragraphs
will be merged into a single paragraph if the L<merge_verbatim> option is
set.  Verbatim paragraphs will also have any tabs expanded to spaces if the
L<expand_tabs> option is set.

In the case of command paragraphs, the method first looks to see if another
method is defined by the parser object specifically for parsing this type of
command. The method name has the form C<parse_command_$type>, e.g. 
C<parse_command_head1()>.  If a method is found (remember that the parser
object will usually be a subclass which may or may not define any of these
methods) then it will be called.  Otherwise the catch-all L<parse_command()>
method is called.

This mechanism is used to handle the fourth kind of paragraph that can
occur in a POD block.  In the case of a C<=begin> ... C<=end> block, the
block name may start with a C<:> character, in which case the content is 
treated as regular Pod markup.  

    =begin :example
    
    This is a regular POD paragraph.
    
        This is a regular POD verbatim paragraph
    
    =end

In the above example, the L<parse_command()> method will be called once
for the C<=begin> command, followed by the L<parse_paragraph()> and
L<parse_verbatim()> methods for the contained paragraph, finished off
with a final call to L<parse_command()> for the C<=end> command.

If the block name I<doesn't> begin with C<:> then the content up to the 
C<=end> command is treated as a single data block.  
    
    =begin example
    
    This is a data block
    
        This is part of the same data block.
    
    =end

In this case, the L<parse_command()> method will be called once
for the C<=begin> command, followed by a single L<parse_data()> call
for the content and then L<parse_command()> for the C<=end> command.

This is all managed by the L<parse_command_begin()> method.

=head2 parse_paragraph($text,$line)

This method is called whenever an ordinary POD paragraph is parsed.
In the base class it simply calls L<parse_formatted()>.

=head2 parse_data($text,$line)

This method is called whenever a data paragraph is encountered between
C<=begin> and C<=end> commands whose block name does I<not> begin with
C<:>.  See L<parse_pod()> for further details.

=head2 parse_formatted($text,$line)

This method scans the POD text looking for any embedded format sequences.

    This is some POD text with B<bold> and I<italic> text

For each chunk of plain text it calls the L<parse_raw_text()> method.
For each embedded format it calls the L<parse_format()> method.  The 
returns values from each of these method calls are collated into a list.

The method returns the list of items in list context of a reference to 
the list in scalar context.

=head2 parse_plain_text($text,$line)

Called whenever a block of plain text is parsed in an ordinary POD paragraph.
In the base class this method simply returs the text.

=head2 parse_format($name,$lparen,$rparen,$line,$content)

This method is called whenever an embedded format is fully parsed (i.e.
the corresponding right parenthesis is match.  The first argument gives
the format name (e.g. C<B>, C<I>, etc).  The second and third arguments
are the left and right parentheses, followed by the line number on which
the format began.  The final argument is a reference to a list of content,
each of which can be plain text (as returned by L<parse_plain_text()>) or
a nested format (as returned by this C<parse_format()> method).

In this base class, the method simply returns a reference to a list of the
above items.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Parser::Model>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
