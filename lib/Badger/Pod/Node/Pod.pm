#========================================================================
#
# Badger::Pod::Node::Pod
#
# DESCRIPTION
#   Object respresenting a chunk of Pod markup code in a Pod document.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Node::Pod;

use Badger::Class
    version     => 0.01,
    debug       => 1,
    base        => 'Badger::Pod::Node::Body',
    constant    => { type => 'pod' };

sub paragraph {
    my $self = shift;
    $self->body_type('paragraph');
}

sub command {
    my $self = shift;
    $self->body_type('command');
}

sub verbatim {
    my $self = shift;
    $self->body_type('verbatim');
}

sub code {
    my $self = shift;
    $self->body_type('code');
}

1;
