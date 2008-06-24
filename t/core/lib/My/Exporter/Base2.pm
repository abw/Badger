package My::Exporter::Base2;
use base 'Badger::Exporter';

__PACKAGE__->export_all('$HELLO');
__PACKAGE__->export_tags({
    foo => [qw($FOO @FOO %FOO foo)],
    bar => [qw($BAR @BAR %BAR bar)],
});

use vars qw( $HELLO $FOO $BAR @FOO @BAR %FOO %BAZ );

$HELLO = 'world';
$FOO = 3;
$BAR = 4;
@FOO = (30, 40);
@BAR = (50, 60);
%FOO = (seventy => 70);
%BAR = (eighty  => 80);
sub wiz { return 'this is wiz' };
sub waz { return 'this is waz' };

1;
