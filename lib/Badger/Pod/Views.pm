#========================================================================
#
# Badger::Pod::Views
#
# DESCRIPTION
#   Factory module for loading and instantiating Badger::Pod::View::*
#   modules.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Views;

use Badger::Factory::Class
    version  => 0.01,
    debug    => 0,
    item     => 'view',
    path     => 'Badger::Pod::View BadgerX::Pod::View',
    views    => {
        HTML => 'Badger::Pod::View::HTML',
    };

1;
