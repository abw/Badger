package My::Defaults;

use Badger::Class
    version => 0.01,
    debug   => 0,
    base    => 'Badger::Base',
    defaults => {
        FOO => 10,
        BAR => 20,
        BAZ => 30,
    };

sub foo { $FOO }
sub bar { $BAR }
sub baz { $BAZ }

sub defaults {
    join(', ', map { "$_ => $DEFAULTS->{$_}" } sort keys %$DEFAULTS);
}

1;
