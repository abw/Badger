package Badger::Comparable;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    import    => 'CLASS',
    base      => 'Badger::Base',
    utils     => 'numlike is_object',
    methods   => {
        eq    => \&equal,
        ne    => \&not_equal,
        lt    => \&before,
        gt    => \&after,
        le    => \&not_after,
        ge    => \&not_before,
    },
    overload  => {
        '=='  => \&equal,
        '!='  => \&not_equal,
        '<'   => \&before,
        '>'   => \&after,
        '<='  => \&not_after,
        '>='  => \&not_before,
        fallback => 1,
    };


sub compare {
    my $self = shift;
    shift->not_implemented;
}


sub equal {
    shift->compare(@_) == 0;
}


sub not_equal {
    shift->compare(@_) != 0;
}


sub before {
    shift->compare(@_) == -1;
}


sub after {
    shift->compare(@_) == 1;
}


sub not_before {
    shift->compare(@_) >= 0;
}


sub not_after {
    shift->compare(@_) <= 0;
}


1;
