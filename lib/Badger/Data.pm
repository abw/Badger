#========================================================================
#
# Badger::Data
#
# DESCRIPTION
#   Base class module for objects representing various different data
#   types.
# 
# AUTHOR
#   Andy Wardley <abw@wardley.org>
#
#========================================================================

package Badger::Data;

use Badger::Class
    version      => 0.01,
    debug        => 0,
    base         => 'Badger::Prototype',
    import       => 'class CLASS',
    utils        => 'md5_hex self_params refaddr',
    auto_can     => 'method',      # anything in $METHODS can become a method
    constants    => 'HASH TRUE FALSE',
    constant     => {
        # tell Badger what class to strip off to generate id()
        base_id  => __PACKAGE__,
        id       => 'type',
    },
    alias        => {
        # alias type() to id() method provided by Badger::Base
        type     => 'id',
    };


# Define a lexical scope with a $METADATA table for storing any out-of-band
# information about text objects.  The methods defined below can be called 
# as subroutines (as part of the vmethod mechanism), so the first argument
# can be a non-reference text string in place of the usual $self object
# reference (which itself is just a blessed reference to a scalar text
# string).  To handle this case, we use an md5_hex encoding of the text
# to determine a unique handle for it (or close enough to unique for 
# practical purposes)

{
    my $METADATA = { };
    
    sub metadata {
        my $meta = $METADATA->{ 
            $_[0] && ref $_[0]
                ? refaddr $_[0]
                : md5_hex $_[0]
        } ||= { };

        # short-cut: return metadata hash when called without arguments
        return $meta if @_ == 1;

        # short-cut: return item in the metadata hash when called with a 
        # single (non-hashref) item
        return $meta->{ $_[1] } if @_ == 2 && ref $_[1] ne HASH;
        
        # add metadata items when called with a HASH ref or multiple args
        my ($self, $params) = self_params(@_);
        @$meta{ keys %$params } = values %$params;
        return $meta;
    }
}

# This is a throwback to the Template::TT3::Type object on which this is
# based... these methods probably won't be staying here - they should be 
# in Badger::Data::Type

our $METHODS = {
    method    => \&method,       # TODO: can() as alias to method()?
    methods   => \&methods,
    type      => \&type,
    ref       => \&ref,
    def       => \&defined,
    undef     => \&undefined,
    defined   => \&defined,
    undefined => \&undefined,
    true      => \&true,
    false     => \&false,
};


sub init {
    my ($self, $config) = @_;

    # merge everything in $config into $self for now
    @$self{ keys %$config } = values %$config;
    
    # merge all config methods with class $METHODS
    $self->{ methods } = $self->class->hash_vars( 
        METHODS => $config->{ methods } 
    );
    
    return $self;
}


sub method {
    my $self = shift->prototype;
    
    # return item from hash or the hash itself when called without arguments
    return @_
        ? $self->{ methods }->{ $_[0] }
        : $self->{ methods };
}


sub methods {
    my $self = shift->prototype;
    
    # return hash ref when called without argument
    return $self->{ methods } unless @_;
                
    # add items to hash when called with hash ref or multiple args
    my $items = @_ == 1 && ref $_[0] eq HASH ? shift : { @_ };
    my $hash  = $self->{ methods };
    @$hash{ keys %$items } = values %$items;
    return $hash;
}


sub ref {
    return CORE::ref($_[0]);
}


sub defined {
    CORE::defined $_[0] ? TRUE : FALSE;
}


sub undefined {
    CORE::defined $_[0] ? FALSE : TRUE;
}


sub true {
    $_[0] ? $_[0] : FALSE;
}


sub false {
    $_[0] ? FALSE : TRUE;
}


1;

__END__

=head1 NOTE

This is being merged in from Template::TT3::Type.  The documentation still
refers to the old name and relates to TT-specific use.

=head1 NAME

Badger::Data - base class for data object

=head1 SYNOPSIS

    # defining a subclass data type
    package Badger::Data::Thing;
    use base 'Badger::Data';
    
    our $METHODS = {
        wibble => \&wibble,
        wobble => \&wobble,
    };
    
    sub wibble {
        my $self = shift;
        # some wibble code...
    }
    
    sub wobble {
        my $self = shift;
        # some wobble code...
    }

=head1 PLEASE NOTE

This module is being merged in from the prototype C<Template-TT3> code. The
implementation is subject to change and the documentation may be incomplete or
incorrect in places.

=head1 DESCRIPTION

The C<Badger::Data> module implements a base class for the
L<Badger::Data::Text>, L<Badger::Data::List> and L<Badger::Data::Hash> data
objects.

=head1 METHODS

The following methods are defined in addition to those inherited from 
L<Badger::Prototype> and L<Badger::Base>.

=head2 init(\%config)

Initialialisation method to handle any per-object initialisation. This is
called by the L<new()|Badger::Base/new()> method inherited from
L<Badger::Base> . In this base class, the method simply copies all items in
the C<$config> hash array into the C<$self> object.

=head2 clone()

Create a copy of the current object.

    my $clone = $object->clone();

Additional named parameters can be provided.  These are merged with
the items defined in the parent object and passed to the cloned
object's L<init()> method.

    my $clone = $object->clone( g => 0.577 );

=head2 methods()

Returns a reference to a hash array containing the content of the
C<$METHODS> package variable in the current class and any base classes.

    my $methods = $object->methods;

=head2 method($name)

Returns a reference to a particular method from the hash reference 
returned by the L<methods()> method.

    my $method = $object->method('ref');


When called without any arguments, it returns a reference to the
entire hash reference, as per L<methods()>.

    my $method = $object->method->{ foo };

=head2 metadata($name,$value)

This method provides access to an out-of-band (i.e. stored separately from the 
data itself) hash array of metadata for the data item.  It returns a reference
to a hash array when called without arguments.

    # fetch metadata hash and add an entry
    my $metadata = $data->metadata;
    $metadata->{ author } = 'Arthur Dent';
    
    # later... print the metadata
    print $data->metadata->{ author };

It returns the value of an item in the metadata hash when called with a single
argument.

    print $data->metadata('author');

It sets the value of an item when called with two arguments.

    $data->metadata( author => 'Ford Prefect' );

=head2 ref()

Returns the name of the object type, e.g. C<Template::TT3::Type>,
C<Template::TT3::Type::Text>, L<Template::TT3::Type::List>, etc., exactly as
Perl's C<ref()> function does.

=head2 defined()

Returns a true/false (C<1>/C<0>) value to indicate if the target data is 
defined.

=head2 undefined()

Returns a true/false (C<1>/C<0>) value to indicate if the target data is 
undefined.

=head2 true()

Returns a true/false (C<1>/C<0>) value to indicate if the target data has 
a true value (using by Perl's definition of what constitutes truth).

=head2 false()

Returns a true/false (C<1>/C<0>) value to indicate if the target data has 
a false value (using by Perl's definition of what constitutes truth).

=head1 AUTHOR

Andy Wardley  L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO.

L<Template::TT3::Type::Text>, L<Template::TT3::Type::List> and L<Template::TT3::Type::Hash>.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:


