#========================================================================
#
# Badger::Pod::Nodes
#
# DESCRIPTION
#   Factory module for loading and instantiating Badger::Pod::Node::*
#   modules.  Many of the standard node types are also defined below.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Nodes;

use Badger::Debug 'debug_caller';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Factory',
    constants => 'HASH';

our $ITEM       = 'node';
our $NODE_BASE  = ['Badger::Pod::Node', 'BadgerX::Pod::Node'];
our $NODES      = {
    # any nodes with non-standard mappings from name to module can go here, 
    # but in the general case we grok the module name from the $NODE_BASE
};
our $LIST_NODES = {
    # nodes which are list-based require custom handling of config args
    map { $_ => 1 }
    qw( list blocks )           # Badger::Node::List, Blocks
};

# map node() and nodes() to base class item() and items() methods
*node  = __PACKAGE__->can('item');
*nodes = __PACKAGE__->can('items');

# custom type_args() which handles the case of the 'list' node which is
# a list-based object expecting a list of node refs rather than a hash
# config.

sub type_args {
    my $self   = shift;
    my $type   = shift;
    if ($LIST_NODES->{ $type }) {
        return ($type, @_);
    }
    else {
        my $params = @_ && ref $_[0] eq HASH ? shift : { @_ };
        $params->{ $self->{ items } } ||= $self;
        return ($type, $params);
    }
}


#=======================================================================
# Badger::Pod::Node::* subclasses - first the basic block elements...
#=======================================================================

package Badger::Pod::Node::Code;
use Badger::Pod::Node::Class
    base => 'Badger::Pod::Node',
    type => 'code';

package Badger::Pod::Node::Verbatim;
use Badger::Pod::Node::Class
    base => 'Badger::Pod::Node',
    type => 'verbatim';

package Badger::Pod::Node::Pod;
use Badger::Pod::Node::Class
    base => 'Badger::Pod::Node',
    type => 'pod';

package Badger::Pod::Node::Command;
use Badger::Pod::Node::Class
    base => 'Badger::Pod::Node',
    type => 'command';

package Badger::Pod::Node::Paragraph;
use Badger::Pod::Node::Class
    base => 'Badger::Pod::Node',
    type => 'paragraph';



#=======================================================================
# ...then then individual model elements
#=======================================================================

package Badger::Pod::Node::Model;
use Badger::Pod::Node::Class
    base => 'Badger::Pod::Node::Body',
    type => 'model';


1;