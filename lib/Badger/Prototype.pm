#========================================================================
#
# Badger::Prototype
#
# DESCRIPTION
#   Base class module for a protoype class that has a default instance
#   that can be created on demand.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Prototype;

use Badger::Class
    base      => 'Badger::Base',
    version   => 0.01,
    debug     => 0,
    constants => 'PKG REFS ONCE',
    words     => 'PROTOTYPE';

sub prototype {
    my $class = shift;
    return $class if ref $class;
    no strict   REFS;
    no warnings ONCE;
    
    if (@_ == 1 && ! defined $_[0]) {
        # if only a single undef argument is provided, then clear any 
        # prototype from $PROTOTYPE and return a reference to it.
        my $proto = ${$class.PKG.PROTOTYPE};
        undef ${$class.PKG.PROTOTYPE};
        return $proto;
    }
    elsif (@_) {
        # if any other arguments are provided then it forces us to create
        # a new prototype with the fresh configuration options.
        undef ${$class.PKG.PROTOTYPE};
    }
    
    # return the cached value (assuming we didn't just clear it) or create 
    # a new one (if we did, or if there wasn't a previous value)
    return ${$class.PKG.PROTOTYPE} ||= $class->new(@_);
}

sub has_prototype {
    my $self  = shift;
    my $class = ref $self || $self;
    no strict   REFS;
    no warnings ONCE;
    defined ${$class.PKG.PROTOTYPE};
}
    

1;

__END__

=head1 NAME

Badger::Prototype - base class for creating prototype classes

=head1 SYNOPSIS

    package Badger::Example;
    use base 'Badger::Prototype';
    
    sub greeting {
        my $self = shift;
        
        # get prototype object if called as a class method
        $self = $self->prototype() unless ref $self;
        
        # continue as normal, now $self is an object
        if (@_) {
            # set greeting if called with args
            return ($self->{ greeting } = shift);
        }
        else {
            # otherwise get greeting
            return $self->{ greeting };
        }
    }

=head1 DESCRIPTION

This module is a subclass of L<Badger::Base> that additionally provides
the L<prototype()> method.  It is used as a base class for modules that
have methods that can be called as either class or object methods.

    # object method
    my $object = Badger::Example->new();
    $object->greeting('Hello World');

    # class method
    Badger::Example->greeting('Hello World');

The L<prototype()> method returns a singleton object instance which can be 
used as a default object by methods that have been called as class methods. 

Here's an example of a C<greeting()> method that can be called with an argument 
to set a greeting message:

    $object->greeting('Hello World');

Or without any arguments to get the current message:

    print $object->greeting;            # Hello World

As well as being called as an object method, we want to be able to call it
as a class method:

    Badger::Example->greeting('Hello World');
    print Badger::Example->greeting();  # Hello World

Here's what the C<greeting()> method looks like.

    package Badger::Example;
    use base 'Badger::Prototype';
    
    sub greeting {
        my $self = shift;
        
        # get prototype object if called as a class method
        $self = $self->prototype() unless ref $self;
        
        # continue as normal, now $self is an object
        if (@_) {
            # set greeting if called with args
            return ($self->{ greeting } = shift);
        }
        else {
            # otherwise get greeting 
            return $self->{ greeting };
        }
    }

We use C<ref $self> to determine if C<greeting()> has been called as an object
method (C<$self> contains an object reference) or as a class method (C<$self>
contains the class name, in this case C<Badger::Example>). In the latter
case, we call L<prototype()> as a class method (remember, C<$self> contains
the C<Badger::Example> class name at this point) to return a prototype 
object instance which we then store back into C<$self>.

        # get prototype object if called as a class method
        $self = $self->prototype() unless ref $self;

For the rest of the method we can continue as if called as an object 
method because C<$self> now contains a C<Badger::Example> object
either way.

Note that the prototype object reference is stored in the C<$PROTOTYPE>
variable in the package of the calling object's class.  So if you call
prototype on a C<Badger::Example::One> object that is subclassed from 
C<Badger::Prototype> then the prototype object will be stored in the 
C<$Badger::Example::One::PROTOTYPE> package variable.

=head1 METHODS

=head2 prototype(@args)

Constructor method to create a prototype object and cache it in the
C<$PROTOTYPE> package variable for subsequent use.  This is usually 
called from inside methods that can operate as class or object methods, 
as shown in the earlier example.

    sub example {
        my $self = shift;
        
        # upgrade $self to an object when called as a class method
        $self = $self->prototype() unless ref $self;
        
        # ...code follows...
    }

If you prefer a more succint idiom and aren't too worried about calling the
L<prototype> method unneccessarily, then you can write it like this:

    sub greeting {
        my $self = shift->prototype;
        # ...code follows...
    }

If any arguments are passed to the C<prototype()> method then it
forces a new prototype object to be created, replacing any existing
one cached in the C<$PROTOTYPE> package variable.  The arguments are
forwarded to the C<new()> constructor method called to create the
object.

If a single undefined value is passed as an argument then any existing
prototype is released by setting the C<$PROTOTYPE> package variable to 
C<undef>.  The existing prototype is then returned, or undef if there was
no prototype defined.

=head2 has_prototype()

Returns true or false to indicate if a prototype is defined for a class.
It can be called as a class or object method.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2006-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
