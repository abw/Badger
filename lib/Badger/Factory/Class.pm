#========================================================================
#
# Badger::Factory::Class
#
# DESCRIPTION
#   Subclass of Badger::Class for creating Badger::Factory sub-classes.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Factory::Class;

use Carp;
use Badger::Class
    version   => 0.01,
    uber      => 'Badger::Class',
    hooks     => 'item path',
    words     => 'ITEM ITEMS',
    utils     => 'plural',
    import    => 'CLASS',
    constants => 'DELIMITER ARRAY HASH',
    constant  => {
        PATH_SUFFIX => '_PATH',
        FACTORY     => 'Badger::Factory',
    };
#    exports   => {
#        fail  => _export_fail_hook,
#    };

CLASS->export_fail(\&_export_fail_hook);

# catch a hook that has the same name as the items, i.e. widgets

sub _export_fail_hook {
    my ($class, $target, $symbol, $symbols) = @_;
    my $klass = class($target, $class);
    my $items = $klass->var(ITEMS);

    # look for $ITEMS or fall back on plural($ITEM)
    unless ($items) {
        my $item = $klass->var(ITEM);
        $items = plural($item) if $item;
    }

    # if the import symbols matches $items (e.g. widgets) then push the 
    # next argument into the relevant package var (e.g. $WIDGETS)
    if ($items && $items eq $symbol) {
        croak "You didn't specify a value for the '$items' load option."
            unless @$symbols;
        $klass->var( uc($items) => shift @$symbols );
    }
    else {
        $class->_export_fail($target, $symbol, $symbols);
    }
}

sub item {
    my ($self, $item) = @_;
    $self->base(FACTORY);
    $self->var( ITEM => $item );
    return $self;
}

sub items {
    my ($self, $items) = @_;
    $self->base(FACTORY);
    $self->var( ITEMS => $items );
    return $self;
}

sub path {
    my ($self, $path) = @_;
    my $type = $self->var(ITEM)
        || croak "\$ITEM is not defined for $self.  Please add an 'item' option";
    my $var = uc($type) . PATH_SUFFIX;

    $path = [ split(DELIMITER, $path) ]
        unless ref $path eq ARRAY;

    $self->base(FACTORY);
    $self->var( $var => $path );
    return $self;
}


=head1 NAME

Badger::Factory::Class - class module for Badger::Factory sub-classes

=head1 SYNOPSIS

This module can be used to create subclasses of L<Badger::Factory>.

    package My::Widgets;
    
    use Badger::Factory::Class
        version => 0.01,
        item    => 'widget',
        path    => 'My::Widget Your::Widget',
        widgets => {
            extra => 'Another::Widget::Module',
            super => 'Golly::Gosh',
        };

    package main;
    
    # class method
    my $widget = My::Widgets->widget( foo => @args );
    
    # object method
    my $widgets = My::Widgets->new;
    my $widget  = $widgets->widget( foo => @args );

=head1 DESCRIPTION

This module is a subclass of L<Badger::Class> specialised for the purpose
of creating L<Badger::Factory> subclasses.  It is used by the 
L<Badger::Codecs> module among others.

=head1 METHODS

The following methods are provided in addition to those inherited 
from the L<Badger::Class> base class.

=head2 item($name)

The singular name of the item that the factory manages.  This is used
to set the C<$ITEM> package variable for L<Badger::Factory> to use.

=head2 items($name)

The plural name of the item that the factory manages.  This is used
to set the C<$ITEMS> package variable for L<Badger::Factory> to use.

=head2 path($name)

A list of module names that form the search path when loading modules. This
will set the relevant package variable depending on the value of C<$ITEMS> (or
the regular plural form of C<$ITEM> if C<$ITEMS> is undefined).  For example,
is C<$ITEMS> is set to C<widgets> then this method will set C<$WIDGETS_PATH>.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Factory>, L<Badger::Codecs>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:



1;
