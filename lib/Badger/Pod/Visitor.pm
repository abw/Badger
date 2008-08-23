#========================================================================
#
# Badger::Pod::Visitor
#
# DESCRIPTION
#   Base class visitor for traversing a Pod document model.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Visitor;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    import    => 'class';

our @NODES = qw(
    model pod code data verbatim command text 
    head head1 head2 head3 head4 over item begin for paragraph 
    format bold code entity italic link space index zero
);

class->methods(
    map {
        my $type = $_;
        "visit_$type" => sub {
            $_[0]->debug("visiting $type: $_[1]\n") if $DEBUG;
            return '';
        }
    }
    @NODES
);

1;

