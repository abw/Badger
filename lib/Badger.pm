package Badger;

use 5.008;
use Carp;
use lib;
use Badger::Hub;
use Badger::Class
    debug      => 0,
    base       => 'Badger::Base',
    import     => 'class',
    words      => 'HUB',
    constants  => 'PKG ARRAY DELIMITER',
    filesystem => 'Bin',
    exports    => {
        hooks  => {
            lib => [ sub { $_[0]->lib($_[3]) }, 1],
        },
        fail   => \&_export_handler,
    };

our $VERSION = 0.13;
our $HUB     = 'Badger::Hub::Badger';
our $AUTOLOAD;


sub _export_handler {
    # TODO: we should be able to refactor this down, now that Badger::Exporter
    # can handle this argument shifting
    my ($class, $target, $key, $symbols) = @_;
    croak "You didn't specify a value for the '$key' load option."
        unless @$symbols;
    my $module = join(PKG, $class, $key);
    my $option = shift @$symbols;
    class($module)->load;
    $module->export($target, $option);
    return 1;
}


sub init {
    my ($self, $config) = @_;
    my $hub = $config->{ hub } || $self->class->any_var(HUB);
    unless (ref $hub) {
        class($hub)->load;
        $hub = $hub->new($config);
    }
    $self->{ hub } = $hub;
    return $self;
}

sub lib {
    my ($self, $lib) = @_;
    $lib = [split(DELIMITER, $lib)]
        unless ref $lib eq ARRAY;
    foreach (@$lib) {
        # resolve directories relative to current working directory so that
        # relative paths Just Work[tm], e.g. ../perl/lib as well as absolute
        # paths. e.g. /full/path/to/perl/lib
        my $dir = Bin->dir($_)->must_exist;
        $self->debug("adding lib: $dir") if DEBUG;
        lib->import($dir->absolute);
    }
}

sub hub {
    my $self = shift;

    if (ref $self) {
        return @_
            ? ($self->{ hub } = shift)
            :  $self->{ hub };
    }
    else {
        return @_
            ? $self->class->var(HUB => shift)
            : $self->class->var(HUB)
    }
}

sub codec {
    shift->hub->codec(@_);
}


sub config {
    my $self = shift;
    return $self->hub->config;
}

# TODO: AUTOLOAD method which polls hub to see what it supports

1;

__END__

=head1 NAME

Badger - Perl Application Programming Toolkit

=head1 SYNOPSIS

    use Badger
        lib        => '../lib',     # like 'use lib' but relative to $Bin
        Filesystem => 'File Dir',   # import from Badger::Filesystem

    use Badger
        Filesystem => 'Dir File',
        Utils      => 'numlike textlike',
        Constants  => 'ARRAY HASH',
        Codecs     => [codec => 'base64'];

This is equivalent to:

    use Badger;
    use Badger::Filesystem 'Dir File';
    use Badger::Utils      'numlike textlike',
    use Badger::Constants  'ARRAY HASH',
    use Badger::Codecs      codec => 'base64';

=head1 DESCRIPTION

The Badger toolkit is a collection of Perl modules designed to simplify the
process of building object-oriented Perl applications. It provides a set of
I<foundation classes> upon which you can quickly build robust and reliable
systems that are simple, sexy and scalable.  See C<Badger::Intro> for
further information.

The C<Badger> module is a front-end to other C<Badger> modules.  You can use
it to import any of the exportable items from any other C<Badger> module.
Simply specify the module name, minus the C<Badger::> prefix as a load option.

For example:

    use Badger
        Filesystem => 'Dir File',
        Utils      => 'numlike textlike',
        Constants  => 'ARRAY HASH',
        Codecs     => [codec => 'base64'];

This is equivalent to:

    use Badger;
    use Badger::Filesystem 'Dir File';
    use Badger::Utils      'numlike textlike',
    use Badger::Constants  'ARRAY HASH',
    use Badger::Codecs      codec => 'base64';

Note that multiple arguments for a module should be defined as a list
reference.

    use Badger
        ...etc...
        Codecs => [codec => 'base64'];

This is equivalent to:

    use Badger::Codecs [codec => 'base64'];

Which is also equivalent to:

    use Badger::Codecs codec => 'base64';

=head1 EXPORT HOOKS

The C<Badger> module can import items from any other C<Badger::*> module,
as shown in the examples above.  The following export hook is also provided.

=head2 lib

This performs the same task as C<use lib> in adding a directory to your
C<@INC> module include path.  However, there are two differences.  First,
you can specify a directory relative to the directory in which the script
exists.

    use Badger lib => '../perl/lib';

For example, consider a directory layout like this:

    my_project/
        bin/
            example_script.pl
        perl/
            lib/
                My/
                    Module.pm
            t/
                my_module.t

The F<my_project/example_script.pl> can be written like so:

    #!/usr/bin/perl

    use Badger lib => '../perl/lib';
    use My::Module;

    # your code here...

This adds F<my_project/perl/lib> to the include path so that the
C<My::Module> module can be correctly located.  It is equivalent to
the following code using the L<FindBin> module.

    #!/usr/bin/perl

    use FindBin '$Bin';
    use lib "$Bin/../perl/lib";
    use My::Module;

=head1 METHODS

=head2 hub()

Returns a L<Badger::Hub> object.

=head2 codec()

Delegates to the L<Badger::Hub> L<codec()|Badger::Hub/codec()> method to
return a L<Badger::Codec> object.

    my $base64  = Badger->codec('base64');
    my $encoded = $base64->encode($uncoded);
    my $decoded = $base64->decode($encoded);

=head2 config()

Delegates to the L<Badger::Hub> L<codec()|Badger::Hub/codec()> method to
return a L<Badger::Config> object.  This is still experimental.

=head1 TODO

Other methods like L<codec()> to access different C<Badger> modules.
These should be generated dynamically on demand.

=head1 BUGS

Please report bugs or (preferably) send pull requests to merge bug fixes
via the github repository: L<https://github.com/abw/Badger>.

=head1 AUTHOR

Andy Wardley  L<http://wardley.org/>.

With contributions from Brad Bowman and Michael Grubb, and code, inspiration
and insight borrowed from many other module authors.

=head1 COPYRIGHT

Copyright (C) 1996-2012 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<http://badgerpower.com/>

L<https://github.com/abw/Badger>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
