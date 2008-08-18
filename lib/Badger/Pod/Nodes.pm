#========================================================================
#
# Badger::Pod::Nodes
#
# DESCRIPTION
#   Factory module for loading and instantiating Badger::Pod::Node::*
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Nodes;

use Badger::Class
    version => 0.01,
    debug   => 1,
    base    => 'Badger::Factory';

our $ITEM      = 'node';
our $NODE_BASE = ['Badger::Pod::Node', 'BadgerX::Pod::Node'];
our $NODES     = {
    # any nodes with non-standard mappings from name to module can go here, 
    # but in the general case we grok the module name from the $NODE_BASE
};

*node  = __PACKAGE__->can('item');
*nodes = __PACKAGE__->can('items');


#=======================================================================
# Badger::Pod::Node::* subclasses
#=======================================================================

package Badger::Pod::Node::Code;

use Badger::Class
    base     => 'Badger::Pod::Node',
    constant => { type => 'code' };


package Badger::Pod::Node::Verbatim;

use Badger::Class
    base      => 'Badger::Pod::Node',
    accessors => 'name',
    constant  => { type => 'verbatim' };


package Badger::Pod::Node::Command;

use Badger::Class
    base      => 'Badger::Pod::Node::Body',
    accessors => 'name',
    constant  => { type => 'command' };

sub init {
    my ($self, $config) = @_;
    $self->{ name } = $config->{ name };
    $self->SUPER::init($config);
}


package Badger::Pod::Node::Paragraph;

use Badger::Class
    base     => 'Badger::Pod::Node::Body',
    constant => { type => 'paragraph' };

1;