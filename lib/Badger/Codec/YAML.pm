#========================================================================
#
# Badger::Codec::YAML
#
# DESCRIPTION
#   Codec module for encoding/decoding YAML
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Codec::YAML;

use Badger::Class
    version => 0.01,
    base    => 'Badger::Codec',
    import  => 'class CLASS';

BEGIN {
    eval { require 'YAML.pm' } 
        || CLASS->error("You don't have YAML installed");
}

sub encode {
    my $self = shift;
    YAML::Dump(shift);
}

sub decode {
    my $self = shift;
    YAML::Load(shift);
}

# shortcuts straight to the real encoder/decoder subs for efficient aliasing

sub encoder {
    \&YAML::Dump;
}

sub decoder {
    \&YAML::Load;
}


1;


__END__

=head1 NAME

Badger::Codec::YAML - encode/decode data using YAML

=head1 SYNOPSIS

    use Badger::Codec::YAML;
    my $codec   = Badger::Codec::YAML->new();
    my $encoded = $codec->encode("Hello World");
    my $decoded = $codec->decode($encoded);

=head1 DESCRIPTION

This module implements a subclass of L<Badger::Codec> which uses the
L<YAML> module to encode and decode data to and from YAML.

=head1 METHODS

=head2 encode($data)

Encodes C<$data> to YAML.

    $encoded = Badger::Codec::YAML->encode($data);   

=head2 decode($data)

Decodes C<$data> from YAML.

    $decoded = Badger::Codec::YAML->decode($encoded);

=head2 encoder()

This method returns a reference to the real subroutine that's doing
all the encoding work, i.e. the C<Dump()> subroutine in L<YAML>.

=head2 decoder()

This method returns a reference to the real subroutine that's doing
all the decoding work, i.e. the C<Load()> subroutine in L<YAML>.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2005-2008 Andy Wardley. All rights reserved.

=head1 SEE ALSO

L<Badger::Codecs>, L<Badger::Codec>, L<YAML>

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

