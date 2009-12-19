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
    debug     => 0,
    uber      => 'Badger::Class',
    hooks     => 'item path names default',
    words     => 'ITEM ITEMS',
    utils     => 'plural permute_fragments',
    import    => 'CLASS',
    constants => 'DELIMITER ARRAY HASH',
    constant  => {
        PATH_SUFFIX  => '_PATH',
        NAMES_SUFFIX => '_NAMES',
        FACTORY      => 'Badger::Factory',
    };
# chicken and egg
#    exports   => {
#        fail  => \&_export_fail_hook,
#    };

CLASS->export_before(\&_export_before_hook);
CLASS->export_fail(\&_export_fail_hook);

# catch a hook that has the same name as the items, i.e. widgets

sub _export_before_hook {
    my ($class, $target) = @_;
    my $klass = class($target, $class);
    # special-case: we don't want to force the factory base class on 
    # Badger::Class if it's loading this module as the uber parent of a
    # Factory::Class subclass (e.g. Template::TT3::Factory::Class).
    return if $target eq 'Badger::Class';
    $class->debug("$class setting $klass ($target) base class to ", $class->FACTORY)
        if DEBUG;
    $klass->base($class->FACTORY);
}


sub _export_fail_hook {
    my ($class, $target, $symbol, $symbols) = @_;
    my $klass = class($target, $class);
    my $items = $klass->var(ITEMS);

    # look for $ITEMS or fall back on plural($ITEM)
    unless ($items) {
        my $item = $klass->var(ITEM);
        $items = plural($item) if $item;
    }

#    $target->debug("looking for $items to match $symbol\n");

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


sub default {
    my ($self, $item) = @_;
    $self->var( DEFAULT => $item );
    return $self;
}


sub item {
    my ($self, $item) = @_;
    $self->var( ITEM => $item );
    return $self;
}


sub items {
    my ($self, $items) = @_;
    $self->var( ITEMS => $items );
    return $self;
}


sub path {
    my ($self, $path) = @_;
    my $type = $self->var(ITEM)
        || croak "\$ITEM is not defined for $self.  Please add an 'item' option";
    my $var = uc($type) . PATH_SUFFIX;

    $path = [ map { permute_fragments($_) } split(DELIMITER, $path) ]
        unless ref $path eq ARRAY;

    $self->debug("adding $var => [", join(', ', @$path), "]") if DEBUG;
#    $self->base(FACTORY);

    # we use import_symbol() rather than var() so that it gets declared 
    # properly, thus avoiding undefined symbol warnings
    $self->import_symbol( $var => \$path );
    
    return $self;
}


sub names {
    my ($self, $map) = @_;
    my $type = $self->var(ITEM)
        || croak "\$ITEM is not defined for $self.  Please add an 'item' option";
    my $var = uc($type) . NAMES_SUFFIX;

    $self->debug("$self adding names $var => {", join(', ', %$map), "}") if DEBUG;

    # we use import_symbol() rather than var() so that it gets declared 
    # properly, thus avoiding undefined symbol warnings
    $self->import_symbol( $var => \$map );
    
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
        },
        names   => {
            html  => 'HTML',
            color => 'Colour',
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

You can specify the path as a reference to a list of module bases, e.g.

    use Badger::Factory::Class
        item => 'widget',
        path => ['My::Widget', 'Your::Widget'];

Or as a single string containing multiple values separated by whitespace.

    use Badger::Factory::Class
        item => 'widget',
        path => 'My::Widget Your::Widget';

If you specify it as a single string then you can also include optional 
and/or alternate parts in parentheses.  For example the above can be 
written more concisely as:

    use Badger::Factory::Class
        item => 'widget',
        path => '(My|Your)::Widget';

If the parentheses don't contain a vertical bar then then enclosed fragment
is treated as being optional.  So instead of writing something like:

    use Badger::Factory::Class
        item => 'widget',
        path => 'Badger::Widget BadgerX::Widget';

You can write:

    use Badger::Factory::Class
        item => 'widget',
        path => 'Badger(X)::Widget';

See the L<permute_fragments()|Badger::Utils/permute_fragments()> function in
L<Badger::Utils> for further details on how fragments are expanded.

=head2 names($names)

A reference to a hash array of name mappings. This can be used to handle any
unusual spellings or capitalisations. See L<Badger::Factory> for further
details.

=head2 default($name)

The default name to use when none is specified in a request for a module.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2009 Andy Wardley.  All Rights Reserved.

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
