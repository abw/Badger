#========================================================================
#
# Badger::Pod::Node::Class
#
# DESCRIPTION
#   Subclass of Badger::Class which adds some specialised methods/hooks
#   for creating Badger::Pod::Node::* subclasses.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Node::Class;

use Carp;
use Badger::Class
    version   => 0.01,
    uber      => 'Badger::Class',
    hooks     => 'type accept expect',
    constants => 'DELIMITER ARRAY HASH';

sub self { $_[0] }

sub type {
    my ($self, $type) = @_;
    my $visit = 'visit_' . $type;

    $self->methods( 
        $type => \&self,            # $obj->$type   ==> $obj
        type  => sub { $type },     # $obj->type    ==> $type
        visit => sub {
            my ($this, $visitor, @args) = @_;
            $visitor->$visit($this, @args);
        }
    );
}

sub accept {
    my ($self, $nodes) = @_;
    my $accept = $self->var_default( ACCEPT => { } );

    $nodes = [ split(DELIMITER, $nodes) ]
        unless ref $nodes;
    
    $nodes = {
        map { $_ => $_ }
        @$nodes
    } if ref $nodes eq ARRAY;

    croak("Invalid list of accept nodes specified: $nodes")
        unless ref $nodes eq HASH;

    @$accept{ keys %$nodes } = values %$nodes;
    
    return $self;
}

sub expect {
    my ($self, $node) = @_;
    $self->var( EXPECT => $node );
}


=head1 NAME

Badger::Pod::Node::Class - class module for Badger::Pod::Node classes

=head1 SYNOPSIS

This module is used by L<Badger::Pod::Nodes> to generate node subclasses.

    package Badger::Pod::Node::Code;
    
    use Badger::Pod::Node::Class
        base => 'Badger::Pod::Node',
        type => 'code';

    package Badger::Pod::Node::Verbatim;
    
    use Badger::Pod::Node::Class
        base => 'Badger::Pod::Node',
        type => 'verbatim';

=head1 DESCRIPTION

This module is a subclass of L<Badger::Class> specialised for the purpose
of creating L<Badger::Pod::Node> subclasses.  It is used by the 
L<Badger::Pod::Nodes> module as shown in the L<SYNOPSIS> above.

=head1 METHODS

The following methods are provided in addition to those inherited 
from the L<Badger::Class> base class.

=head2 type($name)

This method defines a L<type()> subroutine for the class which returns
the value passed as the C<$name> argument.  It is typically called using
the L<type> import hook.

    package Badger::Pod::Node::Example;
    
    use Badger::Pod::Node::Class
        base => 'Badger::Pod::Node',
        type => 'example';

Using the C<type> import hook has the same effect as calling the C<type()>
method on the C<Badger::Pod::Node::Class> object.

    package Badger::Pod::Node::Example;
    
    use Badger::Pod::Node::Class
        base   => 'Badger::Pod::Node',
        import => 'class';
    
    class->type('example');

The effect is to create a C<type()> method in the class's package
which returns the C<$name> value passed as an argument.

    my $node = Badger::Pod::Node::Example->new;
    print $node->type;          # example

It also creates a method of the same name as the argument which 
return the C<$self> object reference.

    $node->example;             # return $node

This is typically used for filtering purposes:

    grep { $_->example } @nodes;

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Class>, L<Badger::Pod::Nodes>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:



1;
