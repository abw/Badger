# test the export_fail method
package My::Exporter9;
use base 'My::Exporter8';

__PACKAGE__->export_fail( \&bar_fail );

our $BUFFER = '';
our $DEBUG  = 0 unless defined $DEBUG;

sub bar_fail {
    my ($class, $target, $symbol, $rest) = @_;
    if ($symbol eq 'bar') {
        print STDERR "bar_fail => [$symbol]\n" if $DEBUG;
        $My::Exporter8::BUFFER .= "[$symbol]";
        return 1;
    }
    else {
        print STDERR "bar_fail SKIP $symbol\n" if $DEBUG;
        return 0;
    }
}


1;
