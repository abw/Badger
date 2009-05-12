#============================================================= -*-perl-*-
#
# t/filesystem/encoding.t
#
# Test the Badger::Filesystem::File encoding options.
#
# Written by Andy Wardley <abw@wardley.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use lib qw( ./lib ../lib ../../lib );
use Badger::Test 
    tests => 2,
    debug => 'Badger::Filesystem::File',
    args  => \@ARGV;

use Badger
    Filesystem => 'Cwd',
    Codecs     => [ codec => 'utf8' ];

my $dir = Cwd->dir('testfiles')->must_exist;


# This is 'moose...' (with slashes in the 'o's them, and the '...' as one char).
my $moose = "m\x{f8}\x{f8}se\x{2026}";

# This is the same data UTF8 encoded complete with BOM
#my $data  = "\x{ef}\x{bb}\x{bf}m\x{c3}\x{b8}\x{c3}\x{b8}se\x{e2}\x{80}\x{a6}";
my $data  = "m\x{c3}\x{b8}\x{c3}\x{b8}se\x{e2}\x{80}\x{a6}";

# write data to file - we do this as raw so we can pass the BOM through
my $file = $dir->file('utf8_data');
$file->raw->print($data);

# read the text back in
my $text = $file->utf8->text;

ok( utf8::is_utf8($text), 'text is utf8' );

is( reasciify($text), reasciify($moose), 'data is unchanged' );


#------------------------------------------------------------------------
# reascify($string)
#
# escape all the high and low chars to \x{..} sequences
#------------------------------------------------------------------------

sub reasciify {
    my $string = shift;
    $string = join '', map {
        my $ord = ord($_);
        ($ord > 127 || ($ord < 32 && $ord != 10))
            ? sprintf '\x{%x}', $ord
            : $_
        } split //, $string;
    return $string;
}

