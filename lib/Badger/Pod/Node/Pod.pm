#========================================================================
#
# Badger::Pod::Node::Pod
#
# DESCRIPTION
#   Object respresenting a chunk of Pod markup code in a Pod document.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Node::Pod;

use Badger::Class
    version     => 0.01,
    debug       => 1,
    base        => 'Badger::Pod::Node',
    constant    => {
        type => 'pod',
    };

1;
