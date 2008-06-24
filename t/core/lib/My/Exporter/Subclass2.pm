package My::Exporter::Subclass2;
use base 'My::Exporter::Base2';

__PACKAGE__->export_all( qw($GOODBYE) );
__PACKAGE__->export_any( qw($FOO foo) );
__PACKAGE__->export_tags( baz => [qw($BAZ @BAZ)] );

use vars qw( $FOO @FOO $BAZ @BAZ $GOODBYE );

$FOO = 50;
@FOO = (60, 70);
sub foo { return 'this is the new foo' };
$BAZ = 999;
@BAZ = (987, 654);
$GOODBYE = 'see ya';

1;
