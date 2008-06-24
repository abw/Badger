# test the ability to map a hash of import names to target subroutines,
# used for exporting virtual methods into Template::Text, for example.
package My::Exporter6;
use base 'Badger::Exporter';

our $THING = 10;
our $METHODS = {
    foo => \&do_foo,
    bar => \&do_bar,
};

sub do_foo {
    return "Did foo";
}

sub do_bar {
    return "Did bar";
}

__PACKAGE__->export_tags( methods => $METHODS );
__PACKAGE__->export_any(qw( $THING ));

1;
