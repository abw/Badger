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

1;