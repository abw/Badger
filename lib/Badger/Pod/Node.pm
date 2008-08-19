#========================================================================
#
# Badger::Pod::Node
#
# DESCRIPTION
#   Base class object for a node in a Pod document.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Node;

use Badger::Pod 'Nodes';
use Badger::Debug 'debug_caller';
use Badger::Class
    version   => 0.01,
    debug     => 1,
    base      => 'Badger::Base',
    import    => 'class',
    accessors => 'document text line nodes',
    constants => 'TRUE',
    constant  => {
        type  => 'node',
    },
    messages  => {
        bad_add => 'Elements cannot be added to a Pod %s',
    };

our @NODE_TYPES = qw( code pod command verbatim paragraph format );

use overload
    '""'     => \&text,
    bool     => \&TRUE,
    fallback => 1;

sub init {
    my ($self, $config) = @_;
    $self->{ nodes } = $config->{ nodes } || Nodes;
    $self->{ text  } = $config->{ text };
    $self->{ line  } = $config->{ line } || 0;
    return $self;
}

sub node {
#    $_[0]->debug("--- node(", join(', ', @_), ")\n");
#    $_[0]->debug_caller;
    shift->nodes->node(@_);
}

sub add {
    my $self = shift;
    $self->error_msg( bad_add => $self->type );
}

# define nullary methods for code(), pod(), etc., that subclasses can 
# redefine to return themselves and/or their matching children 

class->methods(
    map { $_ => \&nothing }
    @NODE_TYPES,
);

sub nothing { ( ) }


1;