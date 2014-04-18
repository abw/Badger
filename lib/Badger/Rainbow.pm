#========================================================================
#
# Badger::Rainbow
#
# DESCRIPTION
#   Colour-related functionality, used primarily for debugging.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Rainbow;

use Carp;
#use Badger::Debug ':debug';
use Badger::Class
    version   => 0.01,
    base      => 'Badger::Exporter',
    constants => 'DELIMITER ARRAY REFS PKG ALL',
    exports   => {
        any   => 'ANSI_escape ANSI_colours strip_ANSI_escapes',
        hooks => {
            ANSI => \&_export_ANSI_colours,
        },
    },
    constant => {
        ANSI_colours => {
            bold    =>  1,
            dark    =>  2,
            black   => 30,
            red     => 31,
            green   => 32,
            yellow  => 33,
            blue    => 34,
            magenta => 35,
            cyan    => 36,
            grey    => 37,
            white   => 38,
        },
    };

# can't import this via Badger::Debug as it depends on Badger::Rainbow
our $DEBUG = 0 unless defined $DEBUG;

sub _export_ANSI_colours {
    my ($class, $target, $symbol, $more_symbols) = @_;
    my $ansi = ANSI_colours;
    my $cols = shift(@$more_symbols)
        || croak "You didn't specify any ANSI colours to import";

    no strict REFS;

    $cols = [ keys %$ansi ]
        if $cols eq ALL;

    $cols = [ split(DELIMITER, $cols) ]
        unless ref $cols eq ARRAY;

    foreach my $col (@$cols) {
#        $class->debug("Exporting ANSI clolour $col to $target\n") if $DEBUG;
        my $val = $ansi->{ $col }
            || croak "Invalid ANSI colour specified to import: $col";
        *{ $target.PKG.$col } = sub(@) {
            ANSI_escape($val, @_)
        };
    }
}


#-----------------------------------------------------------------------
# ANSI_escape($attr, $text)
#
# Adds ANSI escape codes to each line of text to colour output.
#-----------------------------------------------------------------------

sub ANSI_escape {
    my $attr = shift;
    my $text = join('', grep { defined $_ } @_);
    return join("\n",
        map {
            # look for an existing escape start sequence and add new
            # attribute to it, otherwise add escape start/end sequences
            s/ \e \[ ([1-9][\d;]*) m/\e[$1;${attr}m/gx
                ? $_
                : "\e[${attr}m" . $_ . "\e[0m";
        }
        split(/\n/, $text, -1)   # -1 prevents it from ignoring trailing fields
    );
}


sub strip_ANSI_escapes {
    my $text = join('', grep { defined $_ } @_);
    $text =~ s/ \e .*? m//gx;
    return $text;
}




1;

__END__

=head1 NAME

Badger::Rainbow - colour functionality

=head1 SYNOPSIS

    use Badger::Rainbow ANSI => 'red green blue';

    print red("This is red");
    print green("This is green");
    print blue("This is blue");

=head1 DESCRIPTION

This module implements colour-related functionality.  It is currently
only used for debugging purposes but may be extended in the future.

=head1 EXPORTABLE ITEMS

=head2 ANSI_escape($code, $line1, $line2, ...)

This function applies an ANSI escape code to each line of text, with the
effect of colouring output on compatible terminals.

    use Badger::Rainbow 'ANSI_escape';
    print ANSI_escape(31, 'Hello World');     # 31 is red

=head2 strip_ANSI_escapes($text)

This function removes any ANSI escapes from the text passed as an argument.

=head2 ANSI

This is an export hook which allows you to import subroutines which
apply the correct ANSI escape codes to render text in colour on compatible
terminals.

    use Badger::Rainbox ANSI => 'red green blue';

    print red("This is red");
    print green("This is green");
    print blue("This is blue");

Available colours are: C<black>, C<red>, C<green>, C<yellow>, C<blue>,
C<magenta>, C<cyan>, C<white> and C<grey>.  The C<bold> and C<dark> styles can
also be specified.

    use Badger::Rainbox ANSI => 'dark bold red green blue';

    print bold red "Hello World\n";
    print dark blue "Hello Badger\n";

Colours and styles can be specified as a single whitespace-delimited string
or as a reference to a list of individual items.

    use Badger::Rainbox ANSI => 'red green blue';
    use Badger::Rainbox ANSI => ['red', 'green', 'blue'];

All ANSI colours can be loaded by specifying C<all>.

    use Badger::Rainbox ANSI => 'all';

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
