#========================================================================
#
# Badger::Pod::Parser::Model
#
# DESCRIPTION
#   Subclass of Badger::Pod::Parser which parser a Pod document into a 
#   document object model.  Just like Pod::POM.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Parser::Model;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Pod::Parser',
    import    => 'class',
    constants => 'LAST',
    words     => 'REDUCE',
    accessors => 'model',
    messages  => {
        bad_add => '%s node returned invalid response from add() : %s',
        ignore => 'Ignoring invalid =%s section',
        missing => 'Missing =%s to terminate =%s',
    };

sub parse {
    my $self = shift->prototype;
    local $self->{ model } = $self->node('model');
    local $self->{ stack } = [ $self->{ model } ];
    $self->SUPER::parse(@_);
    return $self->{ model };
}

sub add {
    my $self  = shift;
    my $stack = $self->{ stack };
    my $node;

    while (@$stack) {
        if ($node = $stack->[LAST]->add($self, @_)) {
            # $node can be a new node object (i.e. a reference) to push on 
            # top of the stack or REDUCE to indicate successful completion
            # of an element (e.g. a =over terminated by a =back)
            if (ref $node) {
                push(@$stack, $node);
            }
            elsif ($node eq REDUCE && @$stack > 1) {
                pop(@$stack);
            }
            else {
                $self->error_msg( bad_add => ref($stack->[LAST]), $node );
            }
            last;
        }
        elsif (@$stack > 1) {
            # a false value means the node was not accepted, so we pop the
            # top item off and try the item below it
            pop @$stack;
        }
        else {
            # if we've run out of nodes then we must ignore it
            my ($type, $args) = @_;
            $self->ignore( $type, $args->{ line } );
            last;
        }
    }
    return $node;
}

# generate parse_code(), parse_verbatim() and parse_paragraph()

foreach (qw( code verbatim paragraph )) {
    my $method = $_;

    class->method( 
        "parse_$method" => sub {
            my ($self, $text, $line) = @_;
            $self->debug_extract( $method => $text, $line ) if $DEBUG;
            $self->add(
                $method => { 
                    text => $text, 
                    line => $line 
                } 
            );
        }
    );
}
    
sub parse_command {
    my ($self, $name, $text, $line) = @_;
    $self->debug_extract( command => "=$name$text", $line ) if $DEBUG;
    $self->add(
        $name => {
            text => $text, 
            line => $line,
        } 
    );
}

sub parse_plain_text {
    my ($self, $text, $line) = @_;
    $self->debug_extract( text => "$text", $line ) if $DEBUG;
    return $self->node( 
        text => {
            text => $text, 
            line => $line,
        }
    );
}

sub parse_format {
    my ($self, $name, $lparen, $rparen, $line, $content) = @_;
    $self->debug_extract( format => "$name$lparen...$rparen", $line ) if $DEBUG;
    return $self->node( 
        format => {
            name   => $name, 
            line   => $line,
            body   => $content,
            lparen => $lparen,
            rparen => $rparen,
        },
    );
}

sub parse_formatted {
    my ($self, $text, $line) = @_;
    my $body = $self->SUPER::parse_formatted($text, $line);
    $self->node( list => @$body );
}        

sub ignore {
    shift->warning( ignore => @_ );
    return 0;
}

sub missing {
    shift->warning( missing => @_ );
    return 0;
}

1;