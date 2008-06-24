# test the export_fail method
package My::Exporter8;
use base 'Badger::Exporter';

__PACKAGE__->export_fail( \&foo_fail );
__PACKAGE__->export_any('$THINGY');

our $THINGY = 'FOO THINGY';
our $BUFFER = '';
our $DEBUG  = 0 unless defined $DEBUG;

sub foo_fail {
    my ($class, $target, $symbol, $rest) = @_;
    if ($symbol eq 'foo') {
        my $value = shift @$rest;
        print STDERR "foo_fail [foo => $value]\n" if $DEBUG;
        $BUFFER .= "[$symbol:$value]";
        return 1;
    }
    return 0;
}



1;
