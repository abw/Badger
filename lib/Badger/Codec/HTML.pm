#========================================================================
#
# Badger::Codec::HTML
#
# DESCRIPTION
#   Module for encoding (escaping) and decoding (unescaping) HTML
#
# AUTHOR
#   Andy Wardley <abw@wardley.org> based on code extracted from 
#   Lincoln Stein's CGI.pm module.
#
#========================================================================

package Badger::Codec::HTML;

use strict;
use warnings;
use Badger::Class
    version => 0.01,
    base    => 'Badger::Codec';

our $CHARSET = {
    'ISO-8859-1'   => \&fix_windows,
    'WINDOWS-1252' => \&fix_windows,
};

sub encode {
    my ($class, $html, $charset) = @_;
    my $filter;

    return undef unless defined($html);

    for ($html) {
        s/&/&amp;/g;
        s/\"/&quot;/g;
        s/>/&gt;/g;
        s/</&lt;/g;
    }

    # pass resulting HTML through any corresponding filter for the 
    # character set (if specified)
    if ($charset && ($filter = $CHARSET->{ $charset })) {
        $html = &$filter($html);
    }
        
    return $html;
}

sub decode {
    my ($class, $html) = @_;
    return undef unless defined($html);

    # Thanks to Randal Schwartz for the correct solution to this one.
    $html =~ s[ &(.*?); ] {
        local $_ = $1;
        /^amp$/i	   ? "&" :
        /^quot$/i	   ? '"' :
        /^gt$/i		   ? ">" :
        /^lt$/i		   ? "<" :
        /^#(\d+)$/	   ? chr($1) :
        /^#x([0-9a-f]+)$/i ? chr(hex($1)) :
        $_
    }gex;

    return $html;
}

sub fix_windows {
    my $html = shift;

    # work around bug in some inferior browsers 
    for ($html) {
        s/'/&#39;/g;
        s/\x8b/&#8249;/g;
        s/\x9b/&#8250;/g;
    }
    return $html;
}

1;

__END__

=head1 NAME

Badger::Codec::HTML - encode and decode reserved characters in HTML

=head1 SYNOPSIS

    use Badger::Codec::HTML;
    
    # class methods
    my $enc = Badger::Codec::HTML->encode("http://foo.com/bar.html");
    my $dec = $codec->decode($enc);
    
    # object methods
    my $codec = Badger::Codec::HTML->new();
    my $enc   = $codec->encode("http://foo.com/bar.html");
    my $dec   = $codec->decode($enc);

=head1 DESCRIPTION

This module implements a subclass of L<Badger::Codec> for encoding and
decoding HTML.  It is based on code extracted from Lincoln Stein's
CGI.pm module.

The L<encode()> method encodes HTML by converting any reserved characters
to the correct HTML entities.  

The L<decode()> method reverses this process.  

=head1 METHODS

=head2 encode($html, $charset)

Encodes the HTML text passed as the first argument.

    $encoded = Badger::Codec::HTML->encode($html);   

The optional second argument can be used to indicate the character set
in use.  If this is set to C<ISO-8859-1> C<WINDOWS-1252> then the
encoded data will undergo some additional processing in order to work
around some known bugs in Microsoft's web browsers.  See L<fix_windows()>.

=head2 decode($html)

Decodes the encoded HTML text passed as the first argument.

    $html = Badger::Codec::HTML->decode($encoded);

=head2 fix_windows($text)

This method is used internally to repair the damage caused by bugs in 
certain inferior browsers.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2005-2009 Andy Wardley. All rights reserved.

=head1 ACKNOWLEDGEMENTS

This code is derived from Lincoln D. Stein's CGI module.

=head1 SEE ALSO

L<Badger::Codec>

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

