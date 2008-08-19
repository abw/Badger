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
    qw( list )              # Badger::Node::List
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
    $self->debug("node type: $type ", join(', ', @_), "\n") if $DEBUG;
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