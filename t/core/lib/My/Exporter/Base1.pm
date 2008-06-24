package My::Exporter::Base1;
use base 'Badger::Exporter';

__PACKAGE__->export_all( qw($FOO @FOO %FOO foo) );
__PACKAGE__->export_any( qw($BAR @BAR %BAR bar) );

use vars qw( $FOO $BAR @FOO @BAR %FOO %BAZ );

$FOO = 1;
$BAR = 2;
@FOO = (10, 100, 1000);
@BAR = (20, 200, 2000);
%FOO = (ten => 10, hundred => 100, thousand => 1000);
%BAR = (twenty => 20, two_hundred => 200, two_thousand => 2000);
sub foo { return 'this is foo' };
sub bar { return 'this is bar' };

1;
