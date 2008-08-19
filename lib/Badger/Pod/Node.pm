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

use Badger::Class
    version   => 0.01,
    debug     => 1,
    base      => 'Badger::Base',
    accessors => 'document text line nodes',
    constants => 'TRUE',
    constant  => {
        type  => 'node',
    },
    messages  => {
        bad_add => 'Elements cannot be added to a Pod %s',
    };

use overload
    '""'     => \&text,
    bool     => \&TRUE,
    fallback => 1;

sub init {
    my ($self, $config) = @_;
    $self->{ nodes } = $config->{ nodes };
    $self->{ text  } = $config->{ text };
    $self->{ line  } = $config->{ line } || 0;
    return $self;
}

sub add {
    my $self = shift;
    $self->error_msg( bad_add => $self->type );
}

    
1;