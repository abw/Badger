#========================================================================
#
# Badger::Pod::Node::List
#
# DESCRIPTION
#   Object respresenting a list of Pod nodes.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
# TODO
#   Move this into Badger::Pod::Content?
#
#========================================================================

package Badger::Pod::Node::List;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Pod::Node',
    constant    => {
        type => 'list',
    };

sub init {
    my ($self, $config) = @_;
    $self->SUPER::init($config);
    $self->{ content } = $config->{ content } || [ ];
    return $self;
}

sub push {
    my $self = shift;
    CORE::push(@{ $self->{ content } }, @_);
}

sub text {
    my $self = shift;
    return join(
        '', 
        map { $_->text } 
        @{ $self->{ content } }
    );
}

# NOTE: name mismatch

sub blocks {
    my $self = shift;
    my $blocks = $self->{ content };
    return wantarray
        ? @$blocks
        :  $blocks;
}
    
1;
