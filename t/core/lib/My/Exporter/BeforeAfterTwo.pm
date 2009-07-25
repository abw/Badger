package My::Exporter::BeforeAfterTwo;

our ($DONE_BEFORE, $DONE_AFTER);

use Badger::Class
    base    => 'My::Exporter::BeforeAfter',
    exports => {
        before => \&before_export,
        after  => \&after_export,
        any    => 'wibble wobble wubble',
    };

sub before_export {
    my ($class, $target, $imports) = @_;
#   print "sub two before export [$class] [$target] [$imports]\n";
    pop(@$imports);                 # remove 99
    push(@$imports, 'wobble');      # push wobble
    $DONE_BEFORE = 1;
    return $imports;
}

sub after_export {
    my ($class, $target) = @_;
    $DONE_AFTER = 1;
#   print "sub two after export [$class] [$target]\n";
}

sub wibble {
    return 'wibbly';
}

sub wobble {
    return 'wobbly';
}

sub wubble {
    return 'wubbly';
}

1;
