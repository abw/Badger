#========================================================================
#
# Badger::Pod::Blocks
#
# DESCRIPTION
#   Subclass of Badger::Pod::Parser which splits a source document into
#   code blocks and Pod blocks.  Nothing else.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Blocks;

use Badger::Pod 'Nodes';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Pod::Parser',
    accessors => 'nodes body';

*blocks = \&all;

sub init {
    my ($self, $config) = @_;
    $self->{ nodes } = Nodes->new;
    $self->{ body  } = $self->{ nodes }->node('body');
    $self->init_parser($config);
}

sub parse {
    my $self = shift;
    $self = $self->new unless ref $self;
    $self->parse_blocks(@_);
}

sub all {
    shift->body->body;
}

sub code {
    shift->body->body_type('code');
}

sub pod {
    shift->body->body_type('pod');
}

sub parse_code {
    my ($self, $text, $line) = @_;
    $self->debug("<pod:code\@$line>$text</pod:code>\n") if $DEBUG;
    $self->body->add(
        code => { 
            text => $text, 
            line => $line 
        } 
    );
}

sub parse_pod {
    my ($self, $text, $line) = @_;
    $self->debug("<pod:pod\@$line>$text</pod:pod>\n") if $DEBUG;
    $self->body->add(
        pod => { 
            text => $text, 
            line => $line 
        } 
    );
}


1;