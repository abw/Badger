=head1 NAME

Badger::FAQ - Frequently asked questions about Badger

=head1 SYNOPSIS

    $you->ask;
    $we->answer

=head1 GENERAL QUESTIONS

=head2 How is Badger similar to / different from Moose?

Badgers are smaller and can easily be recognised by their black fur and
distinctive white stripe running down their snout. Moose are larger and have
an impressive set of antlers. Both enjoy foraging in the forest for nuts and
berries.

Joking aside, I'll try and list some of the similarities and differences that
I'm aware of. Please bear in mind that I know Badger much better than I do
Moose so my knowledge may be incomplete or incorrect in places.

Some of the similarities:

=over 

=item *

Both provide a more robust object layer on top of Perl 5

=item *

Both use metaprogramming to achieve those goals (although to
different degrees)

=item *

Both are named after cool animals

=back

Some of the differences:

=over

=item *

Moose sets out to implement the post-modern Perl 6 object model (or something
very close to it). It uses a lot of clever magic to make that happen.

In contrast Badger implements a more "regular" Perl 5 object model, albeit a a
thoroughly modern one. It's got some of the metaprogramming goodness that Perl
6 amd Moose have, but not all of it. The emphasis is on providing enough
metaprogramming to get the Badger job done, rather than providing a completely
extensible metaprogramming environment.

To borrow the ice-cream analogy, if Perl 5's object system is vanilla, then
Badger's is strawberry and Moose's is neapolitan with sprinkles and a
sparkler.

=item * 

Moose is more framework, Badger is more toolkit.  

One of the important principles with Badger is that you can use just one
module (say, L<Badger::Base>, L<Badger::Prototype> or L<Badger::Factory>) as a
regular Perl 5 OO module, without having to use any of the other modules.
L<Badger::Class> provides the metaprogramming side of things to make life easy
if you want it, but you can manage just fine without it.

On the other hand, Moose is all about metaprogramming. If you don't use the
metaprogramming wide of things then you're not really using Moose.

=item * 

Moose is "just" an OO programming framework. It's a very impressive OO
framework that contains some really great ideas (some of which I've borrowed).
The fact that it just concerns itself with the OO framework side of things
should be considered a featured, not a weakness. It does one thing (well,
several things, all under the guess of one meta-thing) and does it extremely
well.

Badger provides a smaller and simpler set of generic OO programming tools as
part of a collection of generally useful modules for application authors (me
in particular). It contains the things that I need for TT, and the kind of
things that I find myself writing over and over again in pretty much every
Perl project I work on. So the Moose-like (and Spiffy-like) parts of Badger
are a means to an end, rather than the raison d'etre in themselves.

=item * 

Badger attempts to bring some of the "Batteries Included" mentality of Python
to the Perl world. Perl already has some highly functional batteries included
with it (the File::* modules, for example) but they're all different shapes
and sizes. Part of the Badger philosophy is to provide a consistent interface
to some of these various different modules. Hence the L<Badger::Filesystem>
modules that try to paper over the cracks that can result from having "More
Than One Way To Do It".

=item *

Badger has no external dependencies. In the general case that's probably not
something to be proud of (reuse is good, right?) But in the case of TT (and
some other projects in the pipeline), having as few dependencies as possible
is really important. If you can't install it then you can't use it, and there
are quite a few TT users for whom installing something from CPAN is not an
option, either because their ISP won't allow it or they're incapable of using
a command line. (Mr T pities those fools, but we try to help them, not berate
them).

=back

So to sum up, Badger and Moose do some similar things but in different ways.
They both like to forage in the forest for nuts and berries.  The Moose picks
them off the trees and the Badger gets them off the ground.  

=head2 Is Badger Re-Inventing Wheels?

Yes and no. Some of the wheels that I've "re-invented" were my own wheels to
start with (e.g. L<Class::Base>, L<Class::Singleton> and L<Class::Facade>
which have been, or will soon be superceded by their Badger counterparts).
Bundling them all into one place makes them easier for me to maintain and
easier for the end user to find, download, install and use. It also means that
they can share other core Badger modules (like L<Badger::Exception> for error
handling, for example) without having to distribute all of those separately on
CPAN. Furthermore, the nature of CPAN is such that they would all end up in
various different namespaces giving no real clue to the end user that they all
make up part of a common toolkit.

So part of the Badger effort is about bundling up a bunch of modules that
I've written (some on CPAN, some not) into a common namespace where they
can play happily together.  Apart from anything else, it means I only have
just I<one> CPAN distribution, test suite, set of documentation, web site, 
bug tracker, subversion repository, etc., etc., to deal with instead of 
I<many>.  In that sense we're taking existing wheels, cleaning them up,
fixing any broken spokes and putting new tyres on.  It's as much about 
packaging and presentation as it is about functionality.

Having said that, there is some duplication between Badger modules and
existing CPAN modules that can do the same things just as well or even better.
In some cases that is an unavoidable consequence of the length of time that
Badger was in gestation. I've been developing the code base for TT3/Badger on
and off since 2001. Many of the fine CPAN modules that people take for granted
these days weren't around back then so I started by rolling my own. This code
then made its way into other projects and evolved over time to where it is
now. Having invested a lot of time in the code, test suite and documentation,
I know exactly where I am with it and I can be very productive using it.
So while it's not broken, I don't plan to fix it.

In other cases, the choice to re-invent a wheel was deliberate because the
existing wheels weren't a good fit for what I wanted or needed. For example,
the L<Path::Class> modules do a fantastic job of providing an OO interface to a
filesystem. I worship the ground that Ken Williams walks on for saving me the
torment of having to deal with all the different File::* modules directly.

Unfortunately the L<Path::Class> modules don't provide the level of
abstraction that is required for them to work with virtual filesystems (such
as I require for TT). Adapting them turned out to be a futile effort because
they're essentially just very simple and elegant wrappers around the various
File::* modules. I needed a similarly simple wrapper, but of a slightly
different kind. So I rolled my own, borrowing Ken's (and other people's) ideas
and/or bits of code wherever I could. That's the I<second> best kind of code
re-use - don't re-invent a wheel, just copy someone else's (just as long as
you've also got something new to add).

Another example is the L<Badger::Exporter> module.  It does pretty much
exactly what the L<Exporter> module does, except that it works with class
inheritance and has some methods of convenience to make it more friendly
to use.  I could have written it as a wrapper around Exporter (and that's
what I started doing) but in the end, it was easier to cut and paste the 
dozen or so critical lines from Exporter and build the module how I wanted
from scratch instead of trying to cobble OO on top a procedural module and
confuse everyone (myself included) in the process.

So in summary, yeah, but no, but.

Badger doesn't really re-invent any wheels but adapts a few to fit into this
particular niche.

=head1 AUTHOR

Andy Wardley  E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<http://badgerpower.com/>

=cut