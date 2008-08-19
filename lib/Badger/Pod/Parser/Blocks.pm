#========================================================================
#
# Badger::Pod::Parser::Blocks
#
# DESCRIPTION
#   Subclass of Badger::Pod::Parser which splits a source document into
#   code blocks and Pod blocks.  Nothing else.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Parser::Blocks;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Pod::Parser';

sub parse {
    my $self = shift->prototype;
    local $self->{ blocks } = $self->node('blocks');
    $self->SUPER::parse(@_);
    return $self->{ blocks };
}

sub parse_code {
    my ($self, $text, $line) = @_;
    $self->debug_extract( code => $text, $line ) if $DEBUG;
    $self->add(
        code => { 
            text => $text, 
            line => $line 
        } 
    );
}

sub parse_pod {
    my ($self, $text, $line) = @_;
    $self->debug_extract( pod => $text, $line ) if $DEBUG;
    $self->add(
        pod => { 
            text => $text, 
            line => $line 
        } 
    );
}

sub add {
    my $self = shift;
    $self->{ blocks }->push( $self->{ nodes }->node(@_) );
}

1;