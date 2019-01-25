package Badger::Yup;

use Badger::Yup::Elements;
use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Base',
    utils    => 'params is_object random_name',
    constant => {
        YUP      => 'Badger::Yup',
        ELEMENTS => 'Badger::Yup::Elements',
    },
    exports  => {
        any  => 'YUP Yup',
    };

sub Yup {
    return ELEMENTS->element( yup => @_ );
}

1;

__END__

=head1 NAME

Badger::Yup - data validation inspired by Yup https://github.com/jquense/yup

=head1 DESCRIPTION

This is a work in progress.

=head1 AUTHOR

Perl version by Andy Wardley L<http://wardley.org>

Based on the Javascript Yup module: L<https://github.com/jquense/yup>

=head1 COPYRIGHT

Copyright (C) 2019 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
