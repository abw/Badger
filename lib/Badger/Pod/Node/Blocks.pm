#========================================================================
#
# Badger::Pod::Node::Blocks
#
# DESCRIPTION
#   Subclass of Badger::Pod::Node::List specialised for dealing with a 
#   list of Pod blocks (raw code or pod sections)
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Node::Blocks;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Pod::Node::List';


sub all {
    shift->each;
}

sub code {
    shift->each('code');
}

sub pod {
    shift->each('pod');
}



1;

__END__
