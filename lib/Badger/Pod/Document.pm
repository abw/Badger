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

use Badger::Pod 'Nodes';
use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Pod::Parser',
    filesystem  => 'File',
    get_methods => 'text file name',
    constants   => 'SCALAR',
    constant    => {
        TEXT_NAME => '<input text>',
    },
    messages   => {
        no_input => 'No text or file parameter specified',
    };


our $TEXT_NAME = '<input text>';

sub init {
    my ($self, $config) = @_;
    my ($text, $file, $name);
    
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
    
    $self->{ nodes } = Nodes->new;

    return $self->init_parser($config);
}

sub content {
    my $self = shift;
    return $self->{ content } 
       ||= $self->parse_blocks($self->{ text });
}

sub blocks {
    shift->content->blocks;
}

sub parse_blocks {
    my $self   = shift;
    my @blocks;
    $self->{ blocks } = \@blocks;
    $self->SUPER::parse_blocks(@_);
    $self->{ nodes }->node( list => { content => \@blocks } );
}    

sub parse_code {
    my ($self, $text, $line) = @_;
    $self->debug("<pod:code\@$line>$text</pod:code>\n") if $DEBUG;
    push(
        @{ $self->{ blocks } }, 
        $self->{ nodes }->node( code => { text => $text, line => $line } )
    );
}

sub parse_pod {
    my ($self, $text, $line) = @_;
    $self->debug("<pod:pod\@$line>$text</pod:pod>\n") if $DEBUG;
    push(
        @{ $self->{ blocks } }, 
        $self->{ nodes }->node( pod => { text => $text, line => $line } )
    );
    $self->SUPER::parse_pod($text, $line);
}

sub parse_command {
    my ($self, $type, $text, $line) = @_;
    $self->debug("<pod:command\@$line>=$type$text</pod:command>\n") if $DEBUG;
}

sub parse_verbatim {
    my ($self, $text, $line) = @_;
    $self->debug("<pod:verbatim\@$line>$text</pod:verbatim>\n") if $DEBUG;
}    

sub parse_paragraph {
    my ($self, $text, $line) = @_;
    $self->debug("<pod:paragraph\@$line>$text</pod:paragraph>\n") if $DEBUG;
    my $body = $self->SUPER::parse_paragraph($text, $line);
}

sub parse_format {
    my ($self, $type, $lparen, $rparen, $line, $content) = @_;
    $self->debug("<pod:format\@$line>$type$lparen...$rparen</pod:format>\n") if $DEBUG;
    return [$type, $lparen, $rparen, $line, $content];
}

1;