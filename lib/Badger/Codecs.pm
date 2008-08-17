#========================================================================
#
# Badger::Codecs
#
# DESCRIPTION
#   Manager of Badger::Codec modules for encoding and decoding data.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Codecs;

use Carp;
use Badger::Codec::Chain 
    qw( CHAIN CHAINED );
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Factory',
    utils     => 'UTILS',
    import    => 'class',
    words     => 'CODECS CODEC_BASE',
    constants => 'HASH ARRAY DELIMITER PKG',
    constant  => {
        CODEC_METHOD  => 'codec',
        ENCODE_METHOD => 'encode',
        DECODE_METHOD => 'decode',
        ENCODING      => 'Badger::Codec::Encoding',
    };

our $ITEM       = 'codec';
our $CODEC_BASE = ['Badger::Codec', 'BadgerX::Codec'];
our $CODECS     = {
    # any codecs with non-standard capitalisation can go here, but 
    # generally we grok the module name from the $CODEC_BASE, e.g.
    url      => 'Badger::Codec::URL',
    yaml     => 'Badger::Codec::YAML',
    json     => 'Badger::Codec::JSON',
    base64   => 'Badger::Codec::Base64',
    encode   => 'Badger::Codec::Encode',
    unicode  => 'Badger::Codec::Unicode',
    storable => 'Badger::Codec::Storable',
    map {
        my $name = $_; $name =~ s/\W//g;
        $_ => [ENCODING, ENCODING.PKG.$name],
    } qw( utf8 UTF8 UTF16BE UTF16LE UTF32BE UTF32LE )
};

*codecs = __PACKAGE__->can('items');

sub codec {
    my $self = shift->prototype;

    # quick turn-around if we're handling chains
    return $_[0] =~ CHAINED
        ? $self->chain(@_)
        : $self->item(@_);
}

sub chain {
    my $self = shift;
    $self->debug("creating chain for $_[0]\n") if $DEBUG;
    return CHAIN->new(@_);
}
 
sub found {
    my ($self, $name, $codec) = @_;
    # cache codec object and return
    $self->{ codecs }->{ $name } = $codec;
    return $codec;
}

sub found_ref {
    my ($self, $item, $config) = @_;
    if (blessed $item) {
        # codecs are cached for reuse, but we always create a new one if
        # configuation parameters are provided.
        $item = $item->new($config) if %$config;
        return $item;
    }
    else {
        $self->error_msg( bad_ref => codec => $item, ref $item );
    }
}

sub encode {
    shift->codec(shift)->encode(@_);
}

sub decode {
    shift->codec(shift)->decode(@_);
}


#-----------------------------------------------------------------------
# export hooks
#-----------------------------------------------------------------------

class->exports( 
    hooks => {
        map { ($_ => \&_export_hook) }
        qw( codec codecs )
    }
);

sub _export_hook {
    my ($class, $target, $key, $symbols) = @_;
    croak "You didn't specify a value for the '$key' load option."
        unless @$symbols;
    my $method = "export_$key";
    $class->$method($target, shift @$symbols);
}

sub export_codec {
    my ($class, $target, $name, $alias) = @_;
    my $codec   = $class->codec($name);
    my $cmethod = $alias || CODEC_METHOD;
    my $emethod = $alias ? join('_', ENCODE_METHOD, $alias) : ENCODE_METHOD;
    my $dmethod = $alias ? join('_', DECODE_METHOD, $alias) : DECODE_METHOD;
    no strict 'refs';
    
    # prefix target class onto above method names
    $_= "${target}::$_" for ($cmethod, $emethod, $dmethod);
    
    $class->debug("exporting $codec codec to $target\n") if $DEBUG;

    # NOTE: I think it's more correct to attempt the export regardless of 
    # any existing sub and allow a redefine warning to be raised.  This is
    # better than silently failing to export the requested items.
    *{$cmethod} = sub() { $codec }; # unless defined &{$cmethod};
    *{$emethod} = $codec->encoder;  # unless defined &{$emethod};
    *{$dmethod} = $codec->decoder;  # unless defined &{$dmethod};
}

sub export_codecs {
    my ($class, $target, $names) = @_;
    if (ref $names eq HASH) {
        while (my ($key, $value) = each %$names) {
            $class->export_codec($target, $value, $key);
        }
    }
    else {
        $names = [ split(DELIMITER, $names) ] unless ref $names eq ARRAY;
        $class->export_codec($target, $_, $_) for @$names;
    }
}

1;


__END__

=head1 NAME

Badger::Codecs - modules for encoding and decoding data

=head1 SYNOPSIS

    # using class methods
    use Badger::Codecs;
    $encoded = Badger::Codecs->encode( base64 => $original );
    $decoded = Badger::Codecs->decode( base64 => $encoded );

    # creating a single codec object
    $codec   = Badger::Codecs->codec('base64');
    $encoded = $codec->encode($original);
    $decoded = $codec->decode($encoded);

    # creating a codecs collection
    $codecs  = Badger::Codecs->new(
        base   => ['My::Codec', 'Badger::Codec'],
        codecs => {
            # most codec names are grokked automatigally from the 
            # base defined above - this hash is for any exceptions
            wibble  => 'Ferret::Codec::Wibble',
            frusset => 'Stoat::Codec::Frusset',
        }
    );
    
    # encode/decode via codecs collective
    $encoded = $codecs->encode( wibble => $original );
    $decoded = $codecs->decode( wibble => $encoded );
    
    # or via a specific codec
    $codec   = $codecs->codec('wibble');
    $encoded = $codec->encode($original);
    $decoded = $codec->decode($encoded);

    # importing a single codec
    use Badger::Codecs 
        codec => 'url';
    
    # codec() returns a Badger::Codec::URL object
    $encoded = codec->encode($text);
    $decoded = codec->decode($encoded);
    
    # encode() and decode() are imported subroutines
    $encoded = encode($text);
    $decoded = decode($encoded);

    # import multiple codecs
    use Badger::Codecs
        codecs => 'base64 storable';
    
    # codec objects
    base64->encode(...);    base64->decode(...);
    storable->encode(...);  storable->decode(...);
    
    # imported subroutines
    encode_base64(...);     decode_base64(...);
    encode_storable(...);   decode_storable(...);

    # import a codec chain
    use Badger::Codecs
        codec => 'storable+base64';
    
    # as before, now both codecs are applied
    codec->encode(...);
    codec->decode(...); 
    encode(...); 
    decode(...)

    # multiple codecs with various options
    use Badger::Codecs
        codecs => {
            link  => 'url+html',
            str64 => 'storable+base64',
        };
    
    # codec objects
    link->encode(...);      link->decode(...);
    str64->encode(...);     str64->decode(...);
    
    # subroutines
    encode_link(...);       decode_link(...);
    encode_str64(...);      decode_str64(...);

    # accessing codecs via Badger::Class
    use Badger::Class 
        codec => 'base64';

    codec(); encode(...); decode(...);      # as above
    
    use Badger::Class 
        codecs => 'base64 storable';
    
    base64();   encode_base64(...);    decode_base64(...);
    storable(); encode_storable(...);  decode_storable(...);
    
=head1 DESCRIPTION

A I<codec> is an object responsible for encoding and decoding data.
This module implements a codec manager to locate, load and instantiate
codec objects.

=head2 Using Codecs

First you need to load the C<Badger::Codecs> module.

    use Badger::Codecs;
    
It can be used in regular OO style by first creating a C<Badger::Codecs>
object and then calling methods on it.

    my $codecs  = Badger::Codecs->new();
    my $codec   = $codecs->codec('url');
    my $encoded = $codec->encode($original);
    my $decoded = $codec->decode($encoded);

You can also call class methods directly.

    my $codec   = Badger::Codecs->codec('url');
    my $encoded = $codec->encode($original);
    my $decoded = $codec->decode($encoded);

Or like this:

    my $encoded = Badger::Codecs->encode(url => $original);
    my $decoded = Badger::Codecs->decode(url => $encoded);

These examples are the equivalent of:

    use Badger::Codec::URL;
    my $codec   = Badger::Codec::URL->new;
    my $encoded = $codec->encode($original);
    my $decoded = $codec->decode($encoded);

C<Badger::Codecs> will do its best to locate and load the correct codec 
module for you.  It defines a base module (C<Badger::Codec> by default)
to which the name of the requested codec is appended in various forms.

It first tries the name exactly as specified.  If no corresponding codec
module is found then it tries a capitalised version of the name, followed
by an upper case version of the name.  So if you ask for a C<foo> codec,
then you'll get back a C<Badger::Codec::foo>, C<Badger::Codec::Foo>,
C<Badger::Codec::FOO> or an error will be thrown if none of these can be
found.

    my $codec = Badger::Codecs->code('url');
        # tries: Badger::Codec + url = Badger::Codec::url   # Nope
        # tries: Badger::Codec + Url = Badger::Codec::Url   # Nope
        # tries: Badger::Codec + URL = Badger::Codec::URL   # Yay!

=head2 Chained Codecs

Codecs can be chained together in sequence. Specify the names of the
individual codes separated by C<+> characters. Whitespace between the names
and C<+> is optional. The codec chain returned (L<Badger::Codec::Chain>)
behaves exactly like any other codec. The only difference being that it
is apply several codecs in sequence.

    my $codec = Badger::Codecs->codec('storable+base64');
    $encoded = $codec->encode($data);       # encode storable then base64
    $decoded = $codec->decode($encoded);    # decode base64 then storable

Note that the decoding process for a chain happens in reverse order
to ensure that a round trip between L<encode()> and L<decode()> returns
the original unencoded data.

=head2 Import Hooks

The C<codec> and C<codecs> import hooks can be used to load and define
codec subroutines into another module.

    package My::Module;
    
    use Badger::Codecs
        codec => 'base64';

The C<codec> import hook defines a C<codec()> subroutine which returns a 
reference to a codec object.  It also defined C<encode()> and C<decode()>
subroutines which are mapped to the codec.

    # using the codec reference
    $encoded = codec->encode($original);
    $decoded = codec->decode($encoded);

    # using the encode/decode subs
    $encoded = encode($original);
    $decoded = decode($encoded);

The C<codecs> import hook allows you to define several codecs at once. A
subroutine is generated to reference each codec, along with encoding and
decoding subroutines.

    use Badger::Codecs
        codecs => 'base64 storable';

    # codec objects
    $encoded = base64->encode($original);
    $decoded = base64->decode($encoded);
    $encoded = storable->encode($original);
    $decoded = storable->decode($encoded);
    
    # imported subroutines
    $encoded = encode_base64($original);
    $decoded = decode_base64($encoded);
    $encoded = encode_storable($original);
    $decoded = decode_storable($encoded);

You can define alternate names for codecs by providing a reference to a
hash array.

    use Badger::Codecs
        text => 'base64',
        data => 'storable+base64';
    
    # codec objects
    $encoded = text->encode($original);
    $decoded = text->decode($encoded);
    $encoded = data->encode($original);
    $decoded = data->decode($encoded);

    # imported subroutines
    $encoded = encode_text($original);
    $decoded = decode_text($encoded);
    $encoded = encode_data($original);
    $decoded = decode_data($encoded);

=head1 METHODS

=head2 new()

Constructor method to create a new C<Badger::Codecs> object.

    my $codecs  = Badger::Codecs->new();
    my $encoded = $codecs->encode( url => $source );

=head3 Configuration Options

=head4 base

This option can be used to specify the name(s) of one or more modules which
define a search path for codec modules. The default value is C<Badger::Codec>.

    my $codecs = Badger::Codecs->new( 
        base => 'My::Codec' 
    );
    my $codec = $codecs->codec('Foo');      # My::Codec::Foo

Multiple paths can be specified using a reference to a list.

    my $codecs = Badger::Codecs->new( 
        base => ['My::Codec', 'Badger::Codec'],
    );
    my $codec = $codecs->codec('Bar');      # either My::Codec::Bar
                                            # or Badger::Codec::Bar

=head4 codecs

The C<codecs> configuration option can be used to define specific codec
mappings to bypass the automagical name grokking mechanism.

    my $codecs = Badger::Codecs->new( 
        codecs => {
            foo => 'Ferret::Codec::Foo', 
            bar => 'Stoat::Codec::Bar',
        },
    );
    my $codec = $codecs->codec('foo');      # Ferret::Codec::Foo

=head2 base(@modules)

The L<base()> method can be used to set the base module path.  It
can be called as an object or class method.

    # object method
    my $codecs = Badger::Codecs->new;
    $codecs->base('My::Codec');
    $codecs->encode( Foo => $data );            # My::Codec::Foo
    
    # class method
    Badger::Codecs->base('My::Codec');
    Badger::Codecs->encode( Foo => $data );     # My::Codec::Foo

Multiple items can be specified as a list of arguments or by reference 
to a list.

    $codecs->base('Ferret::Codec', 'Stoat::Codec');     
    $codecs->base(['Ferret::Codec', 'Stoat::Codec']);

=head2 codecs(\%new_codecs)

The L<codecs()> method can be used to add specific codec mappings
to the internal C<codecs> lookup table.  It can be called as an object
method or a class method.

    # object method
    $codecs->codecs(
        wam => 'Ferret::Codec::Wam', 
        bam => 'Stoat::Codec::Bam',
    );
    my $codec = $codecs->codec('wam');          # Ferret::Codec::Wam
    
    # class method
    Badger::Codecs->codecs(
        wam => 'Ferret::Codec::Wam', 
        bam => 'Stoat::Codec::Bam',
    );
    my $codec = Badger::Codecs->codec('bam');   # Stoat::Codec::Bam

=head2 codec($type, %config)

Creates and returns a C<Badger::Codec> object for the specified
C<$type>.  Any additional arguments are forwarded to the codec's 
constructor method.

    my $codec   = Badger::Codecs->codec('storable');
    my $encoded = $codec->encode($original);
    my $decoded = $codec->decode($encoded);

If the named codec cannot be found then an error is thrown.

=head2 chain($type, %config)

Creates a new L<Badger::Codec::Chain> object to represent a chain of codecs.

=head2 encode($type, $data)

All-in-one method for encoding data via a particular codec.

    # class method
    Badger::Codecs->encode( url => $source );
    
    # object method
    my $codecs = Badger::Codecs->new();
    $codecs->encode( url => $source );

=head2 decode($type, $data)

All-in-one method for decoding data via a particular codec.

    # class method
    Badger::Codecs->decode( url => $encoded );
    
    # object method
    my $codecs = Badger::Codecs->new();
    $codecs->decode( url => $encoded );

=head2 export_codec($package,$name,$alias)

Loads a single codec identified by C<$name> and exports the C<codec>,
C<encode> and C<decode> functions into the C<$package> namespace.

    package Your::Module;
    use Badger::Codecs;
    Badger::Codecs->export_code('Your::Module', 'base64');
    
    # base64() returns the codec
    base64->encode($data);
    base64->decode($data)
    
    # encode() and decode() are shortcuts
    encode($data)
    decode($data);

An C<$alias> can be provided which will be used instead of C<codec> and 
appended to the names of the C<encode> and C<decode> functions.

    package Your::Module;
    use Badger::Codecs;
    Badger::Codecs->export_codec('Your::Module', 'base64', 'munger');
    
    # munged() returns the codec
    munger->encode($data);
    munger->decode($data)
    
    # encode_munger() and decode_munger() are shortcuts
    encode_munger($data)
    decode_munger($data);

=head2 export_codecs($package,$names)

Loads and exports multiple codecs into C<$package>. The codec C<$names> can be
specified as a a string of whitespace delimited 
codec names, a reference to a list of codec names, or a reference to a hash 
array mapping codec names to aliases (see L<export_codec()>).

    Badger::Codecs->export_codecs('Your::Module', 'base64 storable');
    Badger::Codecs->export_codecs('Your::Module', ['base64', 'storable']);
    Badger::Codecs->export_codecs('Your::Module', {
        base64   => 'alias_for_base64',
        storable => 'alias_for_storage',
    });

=head2 load($name)

Loads a codec module identified by the C<$name> argument.  Returns the 
name of the module implementing the codec.

    print Badger::Codecs->load('base64');       # Badger::Codec::Base64

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2005-2008 Andy Wardley. All rights reserved.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
# TextMate: makes me smile
