#========================================================================
#
# Badger::Pod
#
# DESCRIPTION
#   Badger sub-system for working with Plain Old Documentation (Pod).
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod;

use Badger::Class
    version    => 0.01,
    debug      => 1,
    base       => 'Badger::Base',
    import     => 'class',
    constant   => {
        POD      => 'Badger::Pod',
        NODES    => 'Badger::Pod::Nodes',
        PARSER   => 'Badger::Pod::Parser',
        BLOCKS   => 'Badger::Pod::Blocks',
        DOCUMENT => 'Badger::Pod::Document',
    },
    exports    => {
        any => 'Pod Nodes Parser Blocks Document 
                POD NODES PARSER Blocks DOCUMENT',
    };

our $LOADED = { };

*Pod = \&Document;

sub Nodes { 
    POD->load_nodes unless $LOADED->{ NODES };
    return @_ 
        ? POD->nodes(@_)
        : NODES
}

sub Parser { 
    POD->load_parser unless $LOADED->{ PARSER };
    return @_ 
        ? POD->parser(@_)
        : PARSER
}

sub Blocks { 
    POD->load_blocks unless $LOADED->{ BLOCKS };
    return @_ 
        ? POD->blocks(@_)
        : BLOCKS
}

sub Document { 
    POD->load_document unless $LOADED->{ DOCUMENT };
    return @_ 
        ? POD->document(@_)
        : DOCUMENT
}


#-----------------------------------------------------------------------
# methods
#-----------------------------------------------------------------------

sub nodes {
    my $self = shift;
    ($LOADED->{ NODES } ||= $self->load_nodes)->new(@_);
}

sub parser {
    my $self = shift;
    ($LOADED->{ PARSER } ||= $self->load_parser)->new(@_);
}

sub blocks {
    my $self = shift;
    ($LOADED->{ BLOCKS } ||= $self->load_blocks)->new(@_);
}

sub document {
    my $self  = shift;
    ($LOADED->{ DOCUMENT } ||= $self->load_document)->new(@_);
}


#-----------------------------------------------------------------------
# loaders
#-----------------------------------------------------------------------

sub load_nodes    { class(shift->NODES)->load->name    }
sub load_parser   { class(shift->PARSER)->load->name   }
sub load_blocks   { class(shift->BLOCKS)->load->name   }
sub load_document { class(shift->DOCUMENT)->load->name }

    
1;