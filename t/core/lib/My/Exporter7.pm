# test the export_hooks method
package My::Exporter7;
use base 'Badger::Exporter';

__PACKAGE__->export_hooks( foo => \&foo_hook, bar => \&bar_hook );

our $BUFFER = '';
our $DEBUG  = 0 unless defined $DEBUG;

sub foo_hook {
    my ($class, $target, $symbol, $rest) = @_;
    my $value = shift(@$rest);
    print STDERR "running foo_hook [$symbol:$value]\n" if $DEBUG;
    $BUFFER .= "[$symbol:$value]";
}

sub bar_hook {
    my ($class, $target, $symbol, $rest) = @_;
    print STDERR "running bar_hook [$symbol]\n" if $DEBUG;
    $BUFFER .= "[$symbol]";
}


1;
