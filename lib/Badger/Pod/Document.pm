#========================================================================
#
# Badger::Pod::Document
#
# DESCRIPTION
#   Object respresenting a Pod document.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Document;

use Badger::Pod 'Nodes Blocks';
use Badger::Debug ':dump';
use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Pod::Parser',
    filesystem  => 'File',
    get_methods => 'text file name nodes body',
    constants   => 'SCALAR LAST',
    constant    => {
        TEXT_NAME => '<input text>',
    },
    messages   => {
        no_input => 'No text or file parameter specified',
    };

our $TEXT_NAME = '<input text>';


sub init {
    my ($self, $config) = @_;
    my ($text, $file, $name, $nodes);
    
    if ($file = $config->{ file }) {
        $file = File($file);
        $self->{ file } = $file;
        $self->{ text } = $file->text;
        $self->{ name } = $file->name;
    }
    elsif ($text = $config->{ text }) {
        $self->{ text } = ref $text eq SCALAR
            ? $$text 
            :  $text . '';  # force stringification of text objects
        $self->{ name } = $self->TEXT_NAME;
    }
    else {
        return $self->error_msg('no_input');
    }
    
    $self->{ nodes  } = Nodes->new;
    $self->{ body   } = $self->{ nodes }->node('body');
    $self->{ stack  } = [ $self->{ body } ];
    
    $self->init_parser($config);
    $self->parse_blocks($self->{ text });
}

sub blocks {
    my $self = shift;
    # method of convenience which used Badger::Pod::Blocks to parse source
    # into simple code/pod blocks.
    $self->{ blocks } 
        ||= Blocks->new($self->{ config })->parse($self->{ text });
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
    $self->debug("<pod:code\@$line>$text</pod:code>\n") if $DEBUG;
    $self->focus->add(
        code => { 
            text => $text, 
            line => $line 
        } 
    );
}

sub parse_command {
    my ($self, $name, $text, $line) = @_;
    $self->debug("<pod:command\@$line>=$name$text</pod:command>\n") if $DEBUG;
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
    $self->debug("<pod:verbatim\@$line>$text</pod:verbatim>\n") if $DEBUG;
    $self->focus->add(
        verbatim => {
            text => $text, 
            line => $line,
        } 
    );
}    

sub parse_paragraph {
    my ($self, $text, $line) = @_;
    $self->debug("<pod:paragraph\@$line>$text</pod:paragraph>\n") if $DEBUG;
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
    $self->debug("<pod:format\@$line>$name$lparen...$rparen</pod:format>\n") if $DEBUG;
    return [$name, $lparen, $rparen, $line, $content];
}

1;