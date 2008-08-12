#========================================================================
#
# Badger::Mixin
#
# DESCRIPTION
#   Base class for mixins that allow you to "mix in" functionality using
#   composition rather than inheritance.  Similar in concept to roles,
#   although operating at a slightly lower level.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Mixin;

use Badger::Class
    version   => 3.00,
    debug     => 0,
    base      => 'Badger::Exporter',
    import    => 'class',
    constants => 'PKG REFS ONCE ARRAY DELIMITER',
    words     => 'EXPORT_TAGS MIXINS';


sub mixin {
    my $self   = shift;
    my $target = shift || (caller())[0];
    my $class  = $self->class;
    my $mixins = $class->list_vars(MIXINS); 
    $self->debug("mixinto($target): ", $self->dump_data($mixins), "\n") if $DEBUG;
    $self->export($target, $mixins);
}

sub mixins {
    my $self   = shift;
    my $syms   = @_ == 1 ? shift : [ @_ ];
    my $class  = $self->class;
    my $mixins = $class->var_default(MIXINS, [ ]);
    
    $syms = [ split(DELIMITER, $syms) ] 
        unless ref $syms eq ARRAY;

    push(@$mixins, @$syms);
    $self->export_any($syms);
    
    return $mixins;
}


1;

=head1 NAME

Badger::Mixin - base class mixin object

=head1 SYNOPSIS

The C<Badger::Mixin> module is a base class for mixin modules.  
You can use the L<Badger::Class> module to declare mixins:

    package Your::Mixin::Module;
    
    use Badger::Class
        mixins => '$FOO @BAR %BAZ bam';

    # some sample data/methods to mixin
    our $FOO = 'Some random text';
    our @BAR = qw( foo bar baz );
    our %BAZ = ( hello => 'world' );
    sub bam { 'just testing' };

Behind the scenes this adds C<Badger::Mixin> as a base class of 
C<Your::Mixin::Module> and calls the L<mixins> method to declare
what symbols can be mixed into another module.  You can write this
code manually if you prefer:

    package Your::Mixin::Module;
    
    use base 'Badger::Mixin';
    
    __PACKAGE__->mixins('$FOO @BAR %BAZ bam');
    
    # sample data/methods as before

=head1 DESCRIPTION

The L<Badger::Mixin> module is a base class for mixin modules. Mixins are
modules that implement functionality that can be mixed into other modules.
This allows you to create modules using composition instead of misuing
inheritance.

The easiest way to define a mixin module is via the C<Badger::Class> module.

    package Your::Mixin::Module;
    
    use Badger::Class
        mixins => '$FOO @BAR %BAZ bam';

This is syntactic sugar for the following code:

    package Your::Mixin::Module;
    
    use base 'Badger::Mixin';
    __PACKAGE__->mixins('$FOO @BAR %BAZ bam');

The mixin module declares what symbols it makes available for mixing using the
L<mixins()> (plural) method (either indirectly as in the first example,
or directly as in the second).

The L<mixin()> (singular) method can then be used to mix those symbols into
another module. L<Badger::Class> provides the L<mixin|Badger::Class/mixin>
hook which you can use:

    package Your::Other::Module;
    
    use Badger::Class
        mixin => 'Your::Mixin::Module';

Or you can call the L<mixin()> method manually if you prefer.

    package Your::Other::Module;
    
    use Your::Mixin::Module;
    Your::Mixin::Module->mixin(__PACKAGE__);

Mixins are little more than modules with a specialised export mechanism. In
fact, the C<Badger::Mixin> module uses the L<Badger::Exporter> behind the
scenes to export the mixin symbols into the target package. Mixins are
intentionally simple. If you want to do anything more complicated in terms of
exporting symbols then you should use the L<Badger::Exporter> module directly
instead.

=head1 METHODS

=head2 mixins($symbols)

This method is used to declare what symbols are available for mixing in to
other packages. Symbols can be specified as a list of items, a reference to a
list of items or as a single whitespace delimited string.

    package Your::Module;
    use base 'Badger::Mixin';

    # either list of symbols...
    __PACKAGE__->mixins('$FOO', '@BAR', '%BAZ', 'bam');
    
    # ...or reference to a list
    __PACKAGE__->mixins(['$FOO', '@BAR', '%BAZ', 'bam']);
    
    # ...or single string of whitespace delimited symbols
    __PACKAGE__->mixins('$FOO @BAR %BAZ bam');

=head2 mixin($package)

This method is used to mixin the symbols declared via L<mixins()> into 
the package specified by the C<$package> argument.

    Your::Mixin::Module->mixin('My::Module');

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2005-2008 Andy Wardley. All rights reserved.

=head1 SEE ALSO

L<Badger::Class>

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
# TextMate: rocks my world
