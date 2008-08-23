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

#use Badger::Debug 'debug_caller';
use Badger::Factory::Class
    version   => 0.01,
    debug     => 0,
    constants => 'HASH',
    item      => 'node',
    path      => 'Badger::Pod::Node BadgerX::Pod::Node';

our $NODES      = {
    # any nodes with non-standard mappings from name to module can go here, 
    # but in the general case we grok the module name from the $NODE_BASE
};
our $LIST_NODES = {
    # nodes which are list-based require custom handling of config args
    map { $_ => 1 }
    qw( list blocks )           # Badger::Node::List, Blocks
};


# custom type_args() which handles the case of the 'list' node which is
# a list-based object expecting a list of node refs rather than a hash
# config.

sub type_args {
    my $self = shift;
    my $type = shift;
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

package Badger::Pod::Node::Pod;
use Badger::Pod::Node::Class
    base => 'Badger::Pod::Node',
    type => 'pod';

package Badger::Pod::Node::Code;
use Badger::Pod::Node::Class
    base => 'Badger::Pod::Node',
    type => 'code';

package Badger::Pod::Node::Data;
use Badger::Pod::Node::Class
    base => 'Badger::Pod::Node',
    type => 'data';

package Badger::Pod::Node::Verbatim;
use Badger::Pod::Node::Class
    base => 'Badger::Pod::Node',
    type => 'verbatim';

package Badger::Pod::Node::Command;
use Badger::Pod::Node::Class
    base => 'Badger::Pod::Node',
    type => 'command';

package Badger::Pod::Node::Text;
use Badger::Pod::Node::Class
    base => 'Badger::Pod::Node',
    type => 'text';


#=======================================================================
# ...then then individual model elements
#=======================================================================

package Badger::Pod::Node::Model;
use Badger::Pod::Node::Class
    base   => 'Badger::Pod::Node::Body',
    type   => 'model',
    accept => 'head1 head2 head3 head4 over begin for paragraph verbatim code';

package Badger::Pod::Node::Head;
use Badger::Pod::Node::Class
    base      => 'Badger::Pod::Node::Body',
    type      => 'head',
    accessors => 'title';

sub prepare {
    my ($self, $parser) = @_;
    $self->{ title } = $parser->parse_formatted(@$self{qw( text line )}); 
}

sub text {
    my $self  = shift;
    my $title = $self->{ title }->text;
    return $title . "\n" . '-' x length($title) . "\n\n" . $self->SUPER::text;
}

package Badger::Pod::Node::Head1;
use Badger::Pod::Node::Class
    base   => 'Badger::Pod::Node::Head',
    type   => 'head1',
    accept => 'head2 head3 head4 over begin for paragraph verbatim code';

package Badger::Pod::Node::Head2;
use Badger::Pod::Node::Class
    base   => 'Badger::Pod::Node::Head',
    type   => 'head1',
    accept => 'head3 head4 over begin for paragraph verbatim code';

package Badger::Pod::Node::Head3;
use Badger::Pod::Node::Class
    base   => 'Badger::Pod::Node::Head',
    type   => 'head3',
    accept => 'head4 over begin for paragraph verbatim code';

package Badger::Pod::Node::Head4;
use Badger::Pod::Node::Class
    base   => 'Badger::Pod::Node::Head',
    type   => 'head4',
    accept => 'over begin for paragraph verbatim code';

package Badger::Pod::Node::Over;
use Badger::Pod::Node::Class
    base   => 'Badger::Pod::Node::Body',
    type   => 'over',
    accept => 'over item begin for paragraph verbatim code',
    expect => 'back';

sub prepare {
    my ($self, $parser) = @_;
    my $text = $self->{ text };
#    $self->debug("indent text: $text\n");
    $self->{ indent } = $text;
}

package Badger::Pod::Node::Item;
use Badger::Pod::Node::Class
    base   => 'Badger::Pod::Node::Body',
    type   => 'item',
    accept => 'over begin for paragraph verbatim code';

package Badger::Pod::Node::Begin;
use Badger::Pod::Node::Class
    base   => 'Badger::Pod::Node::Body',
    type   => 'begin',
    accept => 'paragraph verbatim code',
    expect => 'end';

package Badger::Pod::Node::For;
use Badger::Pod::Node::Class
    base   => 'Badger::Pod::Node::Body',
    type   => 'for';

package Badger::Pod::Node::Paragraph;
use Badger::Pod::Node::Class
    base => 'Badger::Pod::Node::Body',
    type => 'paragraph';

sub prepare {
    my ($self, $parser) = @_;
#    $self->debug("preparing ", $self->type, "\n");
    $self->{ body } = $parser->parse_formatted($self->{ text }, $self->{ line });
}

sub text {
    my $self = shift;
    $self->SUPER::text . "\n\n";
}

package Badger::Pod::Node::Format;
use Badger::Pod::Node::Class
    base      => 'Badger::Pod::Node::Body',
    type      => 'format',
    constants => 'PKG',
    import    => 'class CLASS';

our $FORMATS = {
    B => 'Bold',
    C => 'Code',
    E => 'Entity',
    I => 'Italic',
    L => 'Link',
    S => 'Space',
    X => 'Index',
    Z => 'Zero'
};

# generate stubs for all the format subclasses
my $name;

foreach $name (values %$FORMATS) {
    class(class.PKG.$name)
        ->base(class)
        ->type(lc $name);
}

sub init {
    my ($self, $config) = @_;
    my $body = $config->{ body } || [ ];
    my $code = $config->{ name };
    my $name = $FORMATS->{ $code }
        || $self->error("Invalid format code: $code");

    $self->SUPER::init($config);

    $self->{ name   } = $config->{ name };
    $self->{ lparen } = $config->{ lparen };
    $self->{ rparen } = $config->{ rparen };
    $self->{ body   } = $self->node( list => @$body );

    # re-bless into subclass, e.g Badger::Pod::Node::Format::Bold
    my $class = ref($self) . PKG . $name;
    bless $self, $class;

    return $self;
}

sub text {
    shift->{ body }->text;
}



1;