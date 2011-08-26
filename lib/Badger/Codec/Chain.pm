#========================================================================
#
# Badger::Codec::Chain
#
# DESCRIPTION
#   Codec for encoding/decoding data via a chain of other codecs.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Codec::Chain;

use Badger::Codecs;
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Codec',
    constants => 'ARRAY',
    constant  => {
        CODECS  => 'Badger::Codecs',
        CHAIN   => __PACKAGE__,
        CHAINED => qr/\s*\+\s*/,
    },
    exports   => {
        any   => 'CHAIN CHAINED'
    };


sub new {
    my $class = shift;
    my $chain = @_ == 1 ? shift : [ @_ ];

    # single argument can be a text string or array ref
    # each argument in an array can be a codec ref or codec name/chain
    # all codec names must be upgraded to codec objects
    $chain = [ $chain ] unless ref $chain eq ARRAY;
    $chain = [ map { ref $_ ? $_ : split(CHAINED, $_) } @$chain ];
    $chain = [ map { ref $_ ? $_ : CODECS->codec($_)  } @$chain ];
    
    $class->debug("chaining codecs: ", join(' + ', @$chain), "\n") if $DEBUG;

    bless {
        chain => $chain,
    }, $class;
}

sub encode {
    my $self = shift;
    my $data = shift;
    foreach my $codec (@{ $self->{ chain } }) {
        $data = $codec->encode($data);
    }
    return $data;
}

sub decode {
    my $self = shift;
    my $data = shift;
    foreach my $codec (reverse @{ $self->{ chain } }) {
        $data = $codec->decode($data);
    }
    return $data;
}

sub encoder {
    my $self = shift;
    return $self->coder(
        map { $_->encoder } 
        @{ $self->{ chain } } 
    );
}

sub decoder {
    my $self = shift;
    return $self->coder(
        reverse map { $_->decoder } 
        @{ $self->{ chain } } 
    );
}

sub coder {
    my $self   = shift;
    my $coders = @_ && ref $_[0] eq ARRAY ? shift : [@_];
    return sub {
        my $data = shift;
        foreach my $coder (@$coders) {
            $data = $coder->($data);
        }
        return $data;
    }
}

1;

__END__

=head1 NAME

Badger::Codec::Chain - encode/decode data using multiple codecs

=head1 SYNOPSIS

    use Badger::Codec::Chain;
    
    # compact form
    my $codec = Badger::Codec::Chain->new('storable+base64');
    
    # explicit form
    my $codec = Badger::Codec::Chain->new('storable', 'base64');
    
    # encode/decode data using codec chain
    my $enc   = $codec->encode({ pi => 3.14, e => 2.718 });
    my $dec   = $codec->decode($encoded);

=head1 DESCRIPTION

This module implements a subclass of L<Badger::Codec> which chains
together any number of other codec modules.

=head1 METHODS

=head2 new(@codecs)

Constructor method to create a new codec chain.  The codecs can be 
specified by name or as references to L<Badger::Codec> objects.

    # by name
    my $codec = Badger::Codec::Chain->new('storable', 'base64');
    
    # by object reference
    my $codec = Badger::Codec::Chain->new(
        Badger::Codec->codec('storable'), 
        Badger::Codec->codec('base64'), 
    );

You can also use the compact form where multiple codec names are 
separated by C<+>.

    # compact form
    my $codec = Badger::Codec::Chain->new('storable+base64');

=head2 encode($data)

Encodes the data referenced by the first argument using all the 
codecs in the chain.

    $encoded = $codec->encode($data);   

=head2 decode($html)

Decodes the encoded data passed as the first argument using all
the codecs in the chain B<in reverse order>.

    $decoded = $codec->decode($encoded);

=head2 encoder()

Returns a reference to a subroutine which performs the encoding operation.

=head2 decoder()

Returns a reference to a subroutine which performs the decoding operation.

=head1 INTERNAL METHODS

=head2 coder(@coders)

Internal method to construct an encoder or decoder subroutine for a codec
chain.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2005-2009 Andy Wardley. All rights reserved.

=head1 SEE ALSO

L<Badger::Codecs>, L<Badger::Codec>.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

