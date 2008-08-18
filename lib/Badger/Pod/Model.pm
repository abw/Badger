#========================================================================
#
# Badger::Pod::Model
#
# DESCRIPTION
#   Subclass of Badger::Pod::Parser which parser a Pod document into a 
#   document object model.  Just like Pod::POM.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Model;

use Badger::Pod 'Nodes';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Pod::Parser',
    constants => 'LAST',
    accessors => 'nodes body';

sub init {
    my ($self, $config) = @_;
    $self->{ nodes } = Nodes->new;
    $self->{ body  } = $self->{ nodes }->node('body');
    $self->{ stack } = [ $self->{ body } ];
    $self->init_parser($config);
}

sub parse {
    my $self = shift;
    $self = $self->new unless ref $self;
    $self->parse_blocks(@_);
}

sub node {
    shift->nodes->node(@_);
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
    $self->debug_extract( code => $text, $line );
    $self->focus->add(
        code => { 
            text => $text, 
            line => $line 
        } 
    );
}

sub parse_command {
    my ($self, $name, $text, $line) = @_;
    $self->debug_extract( command => "=$name$text", $line );
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

sub debug_extract {
    my ($self, $type, $text, $line) = @_;
    $text =~ s/\n/\\n/g;
    $text = substr($text, 0, 61) . '...' if length $text > 64;
    $self->debug_up(1, "[$type\@$line|$text]\n");
}
    
1;