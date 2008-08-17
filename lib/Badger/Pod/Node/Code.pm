#========================================================================
#
# Badger::Pod::Node::Code
#
# DESCRIPTION
#   Object respresenting a chunk of non-Pod code in a Pod document.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Node::Code;

use Badger::Class
    version     => 0.01,
    debug       => 1,
    base        => 'Badger::Pod::Node',
    constant    => {
        type => 'code',
    };

1;
