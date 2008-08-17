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
    version     => 0.01,
    debug       => 1,
    base        => 'Badger::Base',
    get_methods => 'document text line',
    constants   => 'TRUE',
    constant    => {
        type    => 'node',
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
    $self->debug("got nodes: $self->{ nodes }\n");
    return $self;
}

1;