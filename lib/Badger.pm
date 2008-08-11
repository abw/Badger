package Badger;

use 5.8.0;
use Badger::Hub;
use Badger::Class
    debug   => 0,
    base    => 'Badger::Base',
    utils   => 'UTILS',
    import  => 'class',
    words   => 'HUB';

our $VERSION = 0.01;
our $HUB     = 'Badger::Hub';
our $AUTOLOAD;

sub init {
    my ($self, $config) = @_;
    my $hub = $config->{ hub } || $self->class->any_var(HUB);
    unless (ref $hub) {
        UTILS->load_module($hub);
        $hub = $hub->new($config);
    }
    $self->{ hub } = $hub;
    return $self;
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

Badger - application programming toolkit

=head1 SYNOPSIS

    use Badger;
	
    # forage for nuts and berries in the forest

=head1 WARNING

This is an alpha release. Everything is subject to change. The code as it
stands is almost certainly packed full of FAIL and should be handled as if
it's likely to explode at any second. Read the warning below. Please wipe your
feet before stepping inside (and check the message on the mat while you're at
it).
    
=head1 INTRODUCTION

This is a sneak preview release of the Badger toolkit - a collection of
Perl modules designed to make programming fun.  Well, OK, designed to make
programming I<slightly less> tedious than it currently is.

Most of the code is functional and correct to the best of my knowledge,
although I'm not sure how far that knowledge extends into the "real world". In
fact, I am quite certain that these modules contain a significant number of
careless bugs, incorrect design decision, bad implementation choices, and
various other shades of FAIL that need to be corrected. Furthermore, the
documentation is known to be incomplete and quite possible incorrect in places
(although most of those places are hopefully marked as such).

In light of this, you would be as mad as a brain-bamboozled badger, hell-bent
on self-destruction and careering wildly down the rocky path to the collapse
of civilisation as we know it, if you were to even I<consider> using this in
production code right now.  Oh, OK.  Go on then, you can if you want.  I'm 
sure you religiously test all of your code anyway, so you'll spot any bugs
quickly and help me fix them, right?  But don't say I didn't warn you....

So, with that warning nailed firmly to the door and a "welcome" mat reading
"HEED THE SIGN ON THE DOOR!" lest anyone should miss it, pray come hither 
and let the dance of the happy badgers begin!

[passes crack pipe]

=head1 DESCRIPTION

The Badger toolkit is a collection of Perl modules designed to simplify the
process of building object-oriented Perl applications. It provides a set of
I<foundation> classes upon which you can quickly build robust and reliable
systems that are simple, sexy and scalable. All modulo the warnings above.

The Badger grew out of the Template Toolkit. Version 3 in particular.
It's all the generic bits that form the basis of TT3, not to mention a few
dozen other Perl-based applications (mainly of the web variety) that I've
written over the past few years.  The code has evolved and stabilised over
the years and is finally approaching a fit state suitable for human 
consumption.

The Badger is a toolkit, not a framework. You can use all, some or none of the
Badger modules in a project and they'll play together nicely (convivial play
is a central theme of Badger, as is foraging in the forest for nuts and
berries). However, there's no rigid framework that you have to adjust your
mindset to, and very litte "buy-in" required to start playing Badger games.
Use the bits you want and ignore the rest. Modularity is good. Monolithicity
probably isn't even a real word, but it would be a bad one if it was.

The Badger is dependency free (mind alterating substances notwithstanding).
The basic Badger toolkit requires nothing more than the core modules
distributed with modern versions of Perl (5.8+, maybe 5.6 at a pinch). This is
important (for me at least) because the Badger will be the basis for TT3 and
other forthcoming modules that require minimal dependencies (e.g. for ease of
installation on an ISP or other restricted server). That's not because we
don't love CPAN. Far from it - we luurrrveee CPAN.  We've borrowed liberally 
from CPAN and tried to make as many things inter-play-nicely-able with 
existing CPAN modules as possible.  But ultimately, one of the goals of
Badger is to provide a self-contained and self-consistent set of modules 
that all work the same way, talk the same way, and don't require you to 
first descend fifteen levels deep into CPAN dependency hell before you can
write a line of code.

[passes bong]

=head1 MODULES

=head2 Badger

The C<Badger> module is little more than a front-end module.  It doesn't
do much at the moment, other than act as a convenient front door to which
we can nail messages of dire warning.

=head2 Badger::Base

This is a handy base class from which you can create your own object classes.
It's the successor to L<Class::Base> and provides the usual array of methods
for construction, error reporting, debugging and other common functionality.

Here's a teaser:

    package My::Badger::Module;
    use base 'Badger::Base';
    
    sub hello {
        my $self = shift;
        my $name = $self->{ config }->{ name } || 'World';
        return "Hello $name!\n";
    }
    
    package main;
    
    my $obj = My::Badger::Module->new;
    print $obj->hello;             # Hello World!

    my $obj = My::Badger::Module->new( name => 'Badger' );
    print $obj->hello;             # Hello Badger!

=head2 Badger::Prototype

Another handy base class (itself derived from L<Badger::Base>) which allows
you to create prototype objects. To cut a long story short, it means you can
call class methods and have them get automatigcally applied to a default
object (the prototype). It's a little like a singleton, but slightly more
flexible.

=head2 Badger::Mixin

Yet another handy base class, this time for creating mixin objects that can 
be mixed into other objects, rather like a generous handful of nuts and 
berries being mixed into an ice cream sundae.  Yummy!  Is it tea-time yet?

=head2 Badger::Class

This is a class metaprogramming module. Yeah, I know, it sounds like rocket
science doesn't it? Actually it's pretty simple stuff. You know all those
things you have to do when you start writing a new module? Like setting a
version number, specifying a base class, defining some constants (or perhaps
loading them from a shared constants module), declaring any exportable items,
and so on? Well L<Badger::Class> makes all that easy. It provides an object
that has methods for manipulating classes, simple as that.  Never mind all
that nasty mucking about with package variables.  Let the Badger do the 
digging so you can pop off and enjoy a nice game of tennis.  Fifteen Love!

    package My::Badger::Module;
    
    use Badger::Class 'class';
    
    class->version(3.14);
    class->base('Badger::Base');
    class->exports( any => 'foo bar baz' );

These methods can be chained together like this:

    class->version(3.14)
         ->base('Badger::Base')
         ->exports( any => 'foo bar baz' );

You can also specify class metaprogramming options as import hooks.  Like 
this:

    package My::Badger::Module;
    
    use Badger::Class
        version => 3.14,
        base    => 'Badger::Base',
        exports => {
            any => 'foo bar baz',
        };

We like this. We think it makes code easier to read when you set a whole bunch
of class-related items in one place instead of using a dozen different
modules, methods and magic variables to achieve the same thing (we do that for
you behind the scenes). We like Schwern too. He understands the virtue of
I<skimmable> code. He was probably a badger in a former life.

=head2 Badger::Exporter

This exports things. Just like the L<Exporter> module, but better
(approximately 2.718 times better in badger reckoning) because it understands
objects and knows what inheritance means. It provides some nice methods to
declare your exportable items so you don't have to go mucking about with
package variables (we do that for you behind the scenes, but you're welcome to
do it yourself if getting your hands dirty is your thing).

Oh go on then, I'll give you a quick peek.

    package My::Badger::Module;
    use base 'Badger::Exporter';
    
    __PACKAGE__->export_all('foo bar $BAZ');
    __PACKAGE__->export_any('$WIZ $BANG');
    __PACKAGE__->export_tags({
        set1 => 'wam bam',
        set2 => 'ding dong'
    });

As well as mandatory (export_all) and optional (export_any) exportable items,
and the ability to define tag sets of items, the L<Badger::Exporter> module
also makes it easy to define your own export hooks.

    __PACKAGE__->export_hooks({
        one => sub { ... },
        two => sub { ... },
    });

The Badger uses export hooks a lot.  They make life easy.  For example, you
can use the C<exports> hook with L<Badger::Class> and then you don't have
to worry about L<Badger::Exporter> at all.

    package My::Badger::Module;
    
    use Badger::Class
        exports  => {
            all  => 'foo bar $BAZ',
            any  => '$WIZ $BANG',
            tags => {
                set1 => 'wam bam',
                set2 => 'ding dong'
            },
            hooks => {
                one => sub { ... },
                two => sub { ... },
            },
        };

=head2 Badger::Constants

This defines some constants commonly used with the Badger modules.  It also
provides a base class from which you can derive your own constants modules.

    use Badger::Constants 'TRUE FALSE ARRAY';
    
    sub is_this_an_array_ref {
        my $thingy = shift;
        return ref $thingy eq ARRAY ? TRUE : FALSE;
    }

=head2 Badger::Debug

This provides some debugging methods that you can mix into your own modules
as and when required.  And hey, we can do colour!  woot!

=head2 Badger::Exception

An exception object used by the Badger's inbuilt error handling system.

=head2 Badger::Filesystem

This is a whole badger sub-system dedicated to manipulating files and 
directories in real and virtual filesystems.  But I'm only going to show
you a two-line example in case you get too excited.

    use Badger::Filesystem 'File';
    print File('hello.txt')->text;

Sorry, you'll have to read the L<Badger::Filesystem> documentation for 
further information.

=head2 Badger::Codec

Codecs are for encoding and decoding data between all sorts of different 
formats: Unicode, Base 64, JSON, YAML, Storable, and so on.  Codecs are 
simple wrappers around existing modules that make it trivially easy to 
transcode data, and even allow you compose multiple codecs into a single
codec container.

    use Badger::Codecs
        codec => 'storable+base64';
    
    my $encoded = encode('Hello World');
    # now encoded with Storable and Base64
    print decode($encoded);                 # Hello World

=head2 Badger::Rainbow

Somewhere over the rainbow, way up high, there's a Badger debugging module
that relies on some colour definitions. They live here. One day we'll have a
yellow brick road with birds, flowers and little munchkins running around
singing and dancing. But for now, we'll have to make do with a rainbow with
a pot of strong coffee brewing at the end.

=head2 Badger::Test

It's a test module.  Just like all the other test modules, except that this
one plays nicely with other Badger modules.  And it does colour thanks to 
the Rainbow someone left lying around in our back garden! 

=head2 Badger::Utils

Rather like the kitchen drawer where you put all the things that don't have a
place of their own, the L<Badger::Utils> module provides a resting place for
all the miscellaneous bits and pieces. It defines some basic utility functions
and can act as a base class if and when you need to define your own custom
utility collection modules. You are *so* lucky. 

=head1 METHODS

Some, but not documented yet.  Use the source, Luke.

=head1 AUTHOR

Andy Wardley  E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
