package My::Defaults;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Base',
    import   => 'class',
    defaults => {
        FOO => 10,
        BAR => 20,
        BAZ => 30,
        wig => 'wam',
        wam => 'bam',
    };

sub foo { ref $_[0] ? $_[0]->{ FOO } : $FOO }
sub bar { ref $_[0] ? $_[0]->{ BAR } : $BAR }
sub baz { ref $_[0] ? $_[0]->{ BAZ } : $BAZ }
sub wig { ref $_[0] ? $_[0]->{ wig } : $WIG }
sub wam { ref $_[0] ? $_[0]->{ wam } : $WAM }

sub defaults {
    join(', ', map { "$_ => $DEFAULTS->{$_}" } sort keys %$DEFAULTS);
}

sub init {
    my ($self, $config) = @_;
    $self->init_defaults($config);
}


1;
