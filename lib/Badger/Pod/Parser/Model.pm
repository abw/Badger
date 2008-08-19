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
    constants => 'LAST',
    accessors => 'body';


sub parse {
    my $self = shift->prototype;
    local $self->{ body  } = $self->node('body');
    local $self->{ stack } = [ $self->{ body } ];
    $self->SUPER::parse(@_);
    return $self->{ body };
}

sub focus {
    my $self = shift;
    push(@{ $self->{ stack } }, @_) if @_;
    return $self->{ stack }->[LAST];
}

sub add_focus {
    my $self  = shift;
    my $stack = $self->{ stack };
    my $node  = $stack->[LAST]->add(@_);
    push(@$stack, $node);
    return $node;
}

sub blur {
    pop(@{ $_[0]->{ stack } });
}

sub parse_code {
    my ($self, $text, $line) = @_;
    $self->debug_extract( code => $text, $line ) if $DEBUG;
    $self->focus->add(
        code => { 
            text => $text, 
            line => $line 
        } 
    );
}

sub parse_command {
    my ($self, $name, $text, $line) = @_;
    $self->debug_extract( command => "=$name$text", $line ) if $DEBUG;
    my $body = $self->SUPER::parse_paragraph($text, $line);
    $self->focus->add(
        command => {
            name => $name,
            text => '=' . $name . $text, 
            line => $line,
            body => $body,
        } 
    );
}

sub parse_verbatim {
    my ($self, $text, $line) = @_;
    $self->debug_extract( verbatim => $text, $line ) if $DEBUG;
    $self->focus->add(
        verbatim => {
            text => $text, 
            line => $line,
        } 
    );
}    

sub parse_paragraph {
    my ($self, $text, $line) = @_;
    $self->debug_extract( paragraph => $text, $line ) if $DEBUG;
    my $body = $self->SUPER::parse_paragraph($text, $line);
    $self->focus->add(
        paragraph => { 
            text => $text, 
            line => $line,
            body => $body,
        } 
    );
}

sub parse_format {
    my ($self, $name, $lparen, $rparen, $line, $content) = @_;
    $self->debug_extract( format => "$name$lparen...$rparen", $line ) if $DEBUG;
    return [$name, $lparen, $rparen, $line, $content];
}

    
1;