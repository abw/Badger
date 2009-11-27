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

Template::TT3::Type - base class for Text, List and Hash objects

=head1 SYNOPSIS

    # defining a Thing subclass object
    package Template::TT3::Type::Thing;
    use base 'Template::TT3::Type';
    
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

=head1 DESCRIPTION

The C<Template::TT3::Type> module implements a base class for the
L<Template::TT3::Type::Text>, L<Template::TT3::Type::List> and
L<Template::TT3::Type::Hash> virtual objects.  These implement the virtual 
methods that can be applied to text, list and hash items using
the dot operator:

    [% text = 'Hello World' %]
    [% text.length %]            # 11

    [% list = [10, 20, 30] %]
    [% list.size %]              # 3

    [% hash = { x=10, y=20 } %]
    [% hash.size %]              # 2

They can also be used to create objects for those who prefer
to do things in a stricter object-oriented style.

    [% text = Text.new('Hello World')  %]
    [% list = List.new(10, 20, 30)     %]
    [% hash = Hash.new(x = 10, y = 20) %]

TT3 uses L<Template::TT3::Variable> objects to represent variables internally.
When a variable is first accessed in a template, the L<Template::Variables>
module responsible for managing variables creates a variable object to
represent it. 

Variables that contain scalar text (or numbers which we treat as just another
kind of text for all intents and purposes) are represented using
L<Template::TT3::Variable::Text> objects. Hash array references use
L<Template::TT3::Variable::Hash> objects, list references use
L<Template::TT3::Variable::List> reference, and so on. Undefined values get
their own special variable type, L<Template::TT3::Variable::Undef>. 

In each case, these variable objects have a corresponding
L<Template::TT3::Type> module which defines the virtual methods applicable 
to that type. 

=head1 METHODS

The following methods are defined in addition to those inherited from 
L<Template::TT3::Base> and L<Badger::Base>.

=head2 init(\%config)

Initialialisation method to handle any per-object initialisation. This is
called by the L<new()|Badger::Base/new()> method inherited from
L<Badger::Base> . In this base class, the method simply copies all items in
the C<$config> hash array into the C<$self> object.

This method can also be called directly to add any further items to
the object.  Named parameters can be provided as a list or by
reference to a hash array, as per the L<new()|Badger::Base/new()> method.

    $object->init( phi => 1.618 );

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

=head2 ref()

Returns the name of the object type, e.g. C<Template::TT3::Type>,
C<Template::TT3::Type::Text>, L<Template::TT3::Type::List>, etc., exactly as
Perl's C<ref()> function does.

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


