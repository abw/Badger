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
use Scalar::Util qw( blessed );
use Badger::Constants 'HASH PKG DELIMITER';
use Badger::Debug ':dump';
use constant {
    UTILS  => 'Badger::Utils',
    CLASS  => 0,
    FILE   => 1,
    LOADED => 2,
};

our $VERSION  = 0.01;
our $DEBUG    = 0 unless defined $DEBUG;
our $ERROR    = '';
our $MESSAGES = { };
our $HELPERS  = {       # keep this compact in case we don't need to use it
    'Digest::MD5'     => 'md5 md5_hex md5_base64',
    'Scalar::Util'    => 'blessed dualvar isweak readonly refaddr reftype 
                          tainted weaken isvstring looks_like_number 
                          set_prototype',
    'List::Util'      => 'first max maxstr min minstr reduce shuffle sum',
    'List::MoreUtils' => 'any all none notall true false firstidx 
                          first_index lastidx last_index insert_after 
                          insert_after_string apply after after_incl before 
                          before_incl indexes firstval first_value lastval 
                          last_value each_array each_arrayref pairwise 
                          natatime mesh zip uniq minmax',
    'Hash::Util'      => 'lock_keys unlock_keys lock_value unlock_value
                          lock_hash unlock_hash hash_seed',

};
our $DELEGATES;         # fill this from $HELPERS on demand


__PACKAGE__->export_any(qw(
    UTILS blessed is_object params self_params plural xprintf
));

__PACKAGE__->export_fail(\&_export_fail);

sub _export_fail {    
    my ($class, $target, $symbol, $more_symbols) = @_;
    $DELEGATES ||= _expand_helpers($HELPERS);
    my $helper = $DELEGATES->{ $symbol } || return 0;
    require $helper->[FILE] unless $helper->[LOADED];
    $class->export_symbol($target, $symbol, \&{ $helper->[CLASS].PKG.$symbol });
    return 1;
}

sub _expand_helpers {
    # invert { x => 'a b c' } into { a => 'x', b => 'x', c => 'x' }
    my $helpers   = shift;
    return {
        map {
            my $name = $_;                      # e.g. Scalar::Util
            my $file = module_file($name);      # e.g. Scalar/Util.pm
            map { $_ => [$name, $file, 0] }     # third item is loaded flag
            split(DELIMITER, $helpers->{ $name })
        }
        keys %$helpers
    }
}
        

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

This module implements a number of utility functions.  It also provides 
access to all of the utility functions in L<Scalar::Util>, L<List::Util>,
L<List::MoreUtils>, L<Hash::Util> and L<Digest::MD5> as a convenience.

    use Badger::Utils 'blessed reftype first max any all lock_hash md5_hex';

The single line of code shown here will import C<blessed> and C<reftype> from
L<Scalar::Util>, C<first> and C<max> from L<List::Util>, C<any> and C<all>
from L<List::Util>, C<lock_hash> from L<Hash::Util>, and C<md5_hex> from 
L<Digest::MD5>.

These modules are loaded on demand so there's no overhead incurred if you
don't use them (other than a lookup table so we know where to find them).

=head1 EXPORTABLE FUNCTIONS

The following exportable function are defined in addition to those that
C<Badger::Utils> can load from L<Scalar::Util>, L<List::Util>,
L<List::MoreUtils>, L<Hash::Util> and L<Digest::MD5>.

=head2 UTILS

Exports a C<UTILS> constant which contains the name of the C<Badger::Utils>
class.  

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
