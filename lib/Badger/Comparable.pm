package Badger::Comparable;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    import    => 'CLASS',
    base      => 'Badger::Base',
    utils     => 'numlike is_object',
    methods   => {
        eq    => \&equal,
        ne    => \&not_equal,
        lt    => \&before,
        gt    => \&after,
        le    => \&not_after,
        ge    => \&not_before,
        cmp   => \&compare,
    },
    overload  => {
        '=='  => \&equal,
        '!='  => \&not_equal,
        '<'   => \&before,
        '>'   => \&after,
        '<='  => \&not_after,
        '>='  => \&not_before,
        '<=>' => \&compare,
        fallback => 1,
    };


sub compare {
    my $self = shift;
    shift->not_implemented;
}


sub equal {
    shift->compare(@_) == 0;
}


sub not_equal {
    shift->compare(@_) != 0;
}


sub before {
    shift->compare(@_) == -1;
}


sub after {
    shift->compare(@_) == 1;
}


sub not_before {
    shift->compare(@_) >= 0;
}


sub not_after {
    shift->compare(@_) <= 0;
}


1;


=head1 NAME

Badger::Comparable - base class for comparable objects

=head1 SYNOPSIS

    package Your::Comparable::Object;
    use base 'Badger::Comparable';

    # You must define a compare method that returns -1, 0 or +1 
    # if the object is less than, equal to, or greater than the 
    # object passed as an argument.

    sub compare {
        my ($this, $that) = @_;
        
        # for example: comparing by a surname field
        return  $this->surname 
            cmp $that->surname;
    }

    package main;

    # assume $obj1 and $obj2 are instance of above object class
    if ($obj1 < $obj2) {
        # do something
    }

=head1 DESCRIPTION

This module implements a base class for comparable objects.  Subclasses need
only define a L<compare()> method and can inherit all the other methods
provided.  Overloaded comparison operators are also defined.

=head1 METHODS

=head2 compare($that)

This method must be defined by subclasses.  It received the implicit C<$self>
object reference as the first argument and the object it is being compared to
as the second.  

The method can do whatever is necessary to compare the two objects.  It should
return C<-1> if the C<$self> object should be ordered I<before> the C<$that>
object, C<+1> if it should be ordered I<after>, or 0 if the two objects are
considered the same.

=head2 equal($that)

Wrapper around L<compare()> that returns true if the two objects are equal
(L<compare()> returns C<0>).

=head2 not_equal($that)

Wrapper around L<compare()> that returns true if the two objects are not 
equal (L<compare()> returns any non-zero value).

=head2 before($that)

Wrapper around L<compare()> that returns true if the C<$self> object is ordered
before the C<$that> object passed as an argument (L<compare()> returns C<-1>).

=head2 not_before($that)

Wrapper around L<compare()> that returns the logical opposite of the 
L<before()> method, returning a true value if the C<$self> object is greater
than or equal to the L<$that> object passed as an argument (L<compare()> 
returns C<0> or C<+1>).

=head2 after($that)

Wrapper around L<compare()> that returns true if the C<$self> object is ordered
after the C<$that> object passed as an argument (L<compare()> returns C<+1>).

=head2 not_after($that)

Wrapper around L<compare()> that returns the logical opposite of the 
L<after()> method, returning a true value if the C<$self> object is less
than or equal to the L<$that> object passed as an argument (L<compare()> 
returns C<-1> or C<0>).

=head1 OVERLOADED OPERATORS

=head2 ==

This is mapped to the L<equal()> method.

    if ($obja == $objb) {
        # do something
    }

=head2 !=

This is mapped to the L<not_equal()> method.

    if ($obja != $objb) {
        # do something
    }

=head2 <

This is mapped to the L<before()> method.

    if ($obja < $objb) {
        # do something
    }

=head2 >

This is mapped to the L<after()> method.

    if ($obja > $objb) {
        # do something
    }

=head2 <=

This is mapped to the L<not_after()> method.

    if ($obja <= $objb) {
        # do something
    }

=head2 >=

This is mapped to the L<not_before()> method.

    if ($obja >= $objb) {
        # do something
    }

=head1 AUTHOR

Andy Wardley L<http://wardley.org>

=head1 COPYRIGHT

Copyright (C) 2013 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
