#========================================================================
#
# Badger::Utils
#
# DESCRIPTION
#   Module implementing various useful utility functions.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Utils;

use strict;
use warnings;
use base 'Badger::Exporter';
use File::Path;
use Scalar::Util qw( blessed reftype );
use Badger::Constants 'HASH';
use constant {
    UTILS  => 'Badger::Utils',
};

our $VERSION  = 0.01;
our $DEBUG    = 0 unless defined $DEBUG;
our $ERROR    = '';
our $MESSAGES = { };

__PACKAGE__->export_any(qw(
    UTILS blessed reftype is_object params self_params plural xprintf
));

__PACKAGE__->export_hooks(
    md5_hex => sub {
        my ($class, $target, $symbol, $more_symbols) = @_;
        require Digest::MD5;
        $class->export_symbol($target, $symbol, \&Digest::MD5::md5_hex);
        return 1;
    }
);

sub is_object($$) {
    blessed $_[1] && $_[1]->isa($_[0]);
}

sub params {
    @_ && ref $_[0] eq HASH ? shift : { @_ };
}

sub self_params {
    (shift, @_ && ref $_[0] eq HASH ? shift : { @_ });
}

sub plural {
    my $name = shift;

    if ($name =~ /(ss|sh|ch|x)$/) {
        $name .= 'es';
    }
    elsif ($name =~ s/y$//) {
        $name .= 'ies';
    }
    elsif ($name =~ /([^s\d\W])$/) {
        $name .= 's';
    }
    return $name;
}

sub module_file {
    my $file = shift;
    $file  =~ s[::][/]g;
    $file .= '.pm';
}

sub xprintf {
    my $format = shift;
#    _debug(" input format: $format\n") if $DEBUG;
    $format =~ s/<(\d+)(?::([#\-\+ ]?[\w\.]+))?>/'%' . $1 . '$' . ($2 || 's')/eg;
#    _debug("output format: $format\n") if $DEBUG;
    sprintf($format, @_);
}

sub _debug {
    print STDERR @_;
}

1;

__END__

=head1 NAME

Badger::Utils - various utility functions

=head1 SYNOPSIS

    use Badger::Utils 'blessed params';
    
    sub example {
        my $self   = shift;
        my $params = params(@_);
        
        if (blessed $self) {
            print "self is blessed\n";
        }
    }
    

=head1 DESCRIPTION

This module implements various utility functions.  

TODO: At present it is very basic, implementing only the core utilities that I
need right now. I plan to extend it to autoload and delegate to the other
*::Util modules.

=head1 EXPORTABLE FUNCTIONS

=head2 UTILS

Exports a C<UTILS> constant which contains the name of the C<Badger::Utils>
class.  

=head2 blessed($ref)

Exports a reference to the L<Scalar::Util> L<blessed()|Scalar::Util/blessed()>
function.

=head2 reftype($ref)

Exports a reference to the L<Scalar::Util> L<reftype()|Scalar::Util/reftype()>
function.

=head2 md5_hex

Exports a reference to the L<Digest::MD5> L<md5_hex()|Digest::MD5/md5_hex()>
function.

=head2 is_object($class,$object)

Returns true if the C<$object> is a blessed reference which isa C<$class>.

    use Badger::Filesystem 'FS';
    use Badger::Utils 'is_object';
    
    if (is_object( FS => $object )) {       # FS == Badger::Filesystem
        print $object, ' isa ', FS, "\n";
    }

=head2 params(@args)

Method to coerce a list of named paramters to a hash array reference.  If the
first argument is a reference to a hash array then it is returned.  Otherwise
the arguments are folded into a hash reference.

    use Badger::Utils 'params';
    
    params({ a => 10 });            # { a => 10 }
    params( a => 10 );              # { a => 10 }

=head2 self_params(@args)

Similar to L<params()> but also expects a C<$self> reference at the start of
the argument list.

    use Badger::Utils 'self_params';
    
    sub example {
        my ($self, $params) = self_params(@_);
        # do something...
    }

=head2 plural($noun)

The function makes a very naive attempt at pluralising the singular noun word
passed as an argument. 

If the C<$noun> word ends in C<ss>, C<sh>, C<ch> or C<x> then C<es> will be
added to the end of it.

    print plural('class');      # classes
    print plural('hash');       # hashes
    print plural('patch');      # patches 
    print plural('box');        # boxes 

If it ends in C<y> then it will be replaced with C<ies>.

    print plural('party');      # parties

In all other cases, C<s> will be added to the end of the word.

    print plural('device');     # devices

It will fail miserably on many common words.

    print plural('woman');      # womans     FAIL!
    print plural('child');      # childs     FAIL!
    print plural('foot');       # foots      FAIL!

This function should I<only> be used in cases where the singular noun is known
in advance and has a regular form that can be pluralised correctly by the
algorithm described above. For example, the L<Badger::Factory> module allows
you to specify C<$ITEM> and C<$ITEMS> package variable to provide the singular
and plural names of the items that the factory manages.

    our $ITEM  = 'person';
    our $ITEMS = 'people';

If the singular noun is sufficiently regular then the C<$ITEMS> can be 
omitted and the C<plural> function will be used.

    our $ITEM  = 'codec';       # $ITEMS defaults to 'codecs'

In this case we know that C<codec> will pluralise correctly to C<codecs> and
can safely leave C<$ITEMS> undefined.

For more robust pluralisation of English words, you should use the
L<Lingua::EN::Inflect> module by Damian Conway. For further information on the
difficulties of correctly pluralising English, and details of the
implementation of L<Lingua::EN::Inflect>, see Damian's paper "An Algorithmic
Approach to English Pluralization" at
L<http://www.csse.monash.edu.au/~damian/papers/HTML/Plurals.html>

=head2 module_file($name)

Returns the module name passed as an argument as a relative filesystem path
suitable for feeding into C<require()>

    print module_file('My::Module');     # My/Module.pm

=head2 xprintf($format,@args)

A wrapper around C<sprintf()> which provides some syntactic sugar for 
embedding positional parameters.

    xprintf('The <2> sat on the <1>', 'mat', 'cat');
    xprintf('The <1> costs <2:%.2f>', 'widget', 11.99);

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

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
