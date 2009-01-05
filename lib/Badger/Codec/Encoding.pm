#========================================================================
#
# Badger::Codec::Encoding
#
# DESCRIPTION
#   A codec wrapper for Encode that binds a specific encoding with it.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Codec::Encoding;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Codec',
    import    => 'class',
    constants => 'PKG',
    constant  => {
        encoding => 'ASCII',
    };

use Encode qw();
use bytes;

sub encode {
    # replace $self with $self->encoding
    unshift(@_, shift->encoding);
    # you don't need to turn away, this isn't your average GOTO - it's a 
    # special kind of subroutine call that Larry called goto for a laugh
    goto &Encode::encode;
}

sub decode {
    # as above: monkey with the args so the goto works as expected
    unshift(@_, shift->encoding);
    goto &Encode::decode;
}

sub encoder {
    my $self = shift;
    my $enc  = $self->encoding;
    return sub { 
        unshift(@_, $enc);
        goto &Encode::encode
    };
}

sub decoder {
    my $self = shift;
    my $enc  = $self->encoding;
    return sub { 
        unshift(@_, $enc);
        goto &Encode::decode
    };
}


#-----------------------------------------------------------------------
# generate subclasses for various UTF encodings
#-----------------------------------------------------------------------

my $base = __PACKAGE__;
my @encs = qw( utf8 UTF-8 UTF-16BE UTF-16LE UTF-32BE UTF-32LE );

for my $enc (@encs) {
    my $name = $enc;
    $name =~ s/\W//g;

    # fetch a Badger::Class object for the subclass so we can define 
    # a base class and set the constant encoding() method
    my $subclass = class($base.PKG.$name);
    $subclass->base($base);
    $subclass->constant( encoding => $enc );
    
    $base->debug("$name => $enc => ", $subclass->name->encoding, "\n") if $DEBUG;
}    
1;


__END__

=head1 NAME

Badger::Codec::Encoding - base class codec for different encodings

=head1 SYNOPSIS

    package My::Encoding::utf8;
    use base 'Badger::Codec::Encoding';
    use constant encoding => 'utf8';

    package main;
    my $codec = My::Encoding::utf8->new;
    my $encoded = $codec->encode("...some utf8 data...");
    my $decoded = $codec->decode($encoded);

=head1 DESCRIPTION

This module is a subclass of L<Badger::Codec> which itself acts as a base
class for various specific encoding modules.

=head1 METHODS

=head2 encoding()

This constant method returns the encoding for the codec.  Subclasses are
expected to redefine this method to return a string representing their
specific encoding.

=head2 encode($data)

Method for encoding data.  It uses the L<encoding()> method to determine
the encoding type and then calls the L<Encode> L<encode()|Encode/encode()> 
subroutine to do all the hard work.

    $encoded = $codec->encode($uncoded);

=head2 decode($data)

Method for decoding data.  It uses the L<encoding()> method to determine
the encoding type and then calls the L<Encode> L<decode()|Encode/decode()> 
subroutine to do all the hard work.

    $decoded = $codec->decode($encoded);

=head2 encoder()

This method returns a subroutine reference which can be called to encode
data. 

    my $encoder = $codec->encode;
    $encoded = $encoder->($data);

=head2 decoder()

This method returns a suboroutine reference which can be called to decode
data.

    my $decoder = $codec->decode;
    $decoded = $decoder->($data);

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2005-2009 Andy Wardley. All rights reserved.

=head1 SEE ALSO

L<Encode>, L<Badger::Codec::Encode>, L<Badger::Codec::Unicode>, 
L<Badger::Codecs>, L<Badger::Codec>, 

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

