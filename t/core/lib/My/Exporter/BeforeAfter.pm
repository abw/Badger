package My::Exporter::BeforeAfter;
use base 'Badger::Exporter';

our ($DONE_BEFORE, $DONE_AFTER) = (0) x 2;

our $EXPORT_BEFORE = sub {
    my ($class, $target, $imports) = @_;
#   print "base before export [$class] [$target] [$imports]\n";
    push(@$imports, wibble => 99 );
    $DONE_BEFORE++;
    return $imports;
};

our $EXPORT_AFTER = sub {
    my ($class, $target) = @_;
    $DONE_AFTER++;
#   print "base after export [$class] [$target]\n";
};

1;
