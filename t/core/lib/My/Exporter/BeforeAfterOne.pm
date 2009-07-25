package My::Exporter::BeforeAfterOne;

our ($DONE_BEFORE, $DONE_AFTER);

use base 'My::Exporter::BeforeAfter';

__PACKAGE__->export_any('wibble wobble wubble');

__PACKAGE__->export_before(
    sub {
        my ($class, $target, $imports) = @_;
#       print "sub one before export [$class] [$target] [$imports]\n";
        pop @$imports;
        push(@$imports, 'wobble');
        $DONE_BEFORE = 1;
        return $imports;
    }
);

__PACKAGE__->export_after(
    sub {
        my ($class, $target) = @_;
        $DONE_AFTER = 1;
#       print "sub one after export [$class] [$target]\n";
    }
);

sub wibble {
    return 'wibblesome';
}

sub wobble {
    return 'wobblesome';
}

sub wubble {
    return 'wubblesome';
}

1;
