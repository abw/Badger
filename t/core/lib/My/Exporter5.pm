package My::Exporter5;
use My::Exporter4 ':all';
use base 'My::Exporter4';

our $DEBUG;
#My::Exporter5->debugging(1);

My::Exporter5->exports( all => '$ping $pong' );

#My::Exporter5->export_tags({
#    pingpong => '$ping $pong',
#    three => '$E $F',
#    four  => [qw( $G $H )],
#});
our ($E, $F, $G, $H) = (5, 6, 7, 8);
our ($ping, $pong) = qw( wiz bang );


1;
