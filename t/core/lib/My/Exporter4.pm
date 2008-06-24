package My::Exporter4;
use base 'Badger::Exporter';

My::Exporter4->export_tags({
    one => [qw( $A $B )],
    two => [qw( $C $D )],
});
our ($A, $B, $C, $D) = (1, 2, 3, 4);


1;
