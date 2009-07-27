package Badger::Codec::TT;

use Badger::Class
    version  => 0.01,
    debug    => 0,
    base     => 'Badger::Codec Badger::Prototype',
    import   => 'class CLASS',
    utils    => 'blessed textlike',
    constants => 'ARRAY HASH',
    messages => {
        badref  => 'Cannot encode %s reference',
    };

our $MATCH_ESCAPED  = qr/ \\([\\']) /x; 
our $MATCH_WORD     = qr/ (\w+) /x;
our $MATCH_QUOTE    = qr/ '( (?:\\[\\'] | . | \n)*? )' /sx;
our $MATCH_QUOTED   = qr/ \G \s* $MATCH_QUOTE /sx;
our $MATCH_KEY      = qr/ \G \s* (?: $MATCH_WORD | $MATCH_QUOTE )/sx;
our $MATCH_NUMBER   = qr/ \G \s* ( -? \d+ (?: \.\d+ )? ) /x;
our $MATCH_COMMA    = qr/ \G \s* (,\s*)? /x;
our $MATCH_ASSIGN   = qr/ \G \s* (:|=>?) \s* /x;
our $MATCH_HASH     = qr/ \G \s* \{ /x;
our $MATCH_END_HASH = qr/ \G \s* \} /x;
our $MATCH_LIST     = qr/ \G \s* \[ /x;
our $MATCH_END_LIST = qr/ \G \s* (\] | $) /x;    # special case
our $MATCH_UNDEF    = qr/ \G \s* undef /x;

our $ASSIGN = '=';
our $COMMA  = ' ';

sub init {
    my ($self, $config) = @_;
    $self->{ assign } = $config->{ assign } || $ASSIGN;
    $self->{ comma  } = $config->{ comma  } || $COMMA;
    return $self;
}

sub encode {
    shift->prototype->_encode(@_);
}

sub decode {
    shift->prototype->_decode(@_);
}

sub _encode {
    my $self = shift;
    my $data = shift;
    
    $self->debug("encoding: $data\n") if DEBUG;

   # object may have stringification method
    if (blessed $data && textlike $data) {
        $data = '' . $data;     # drop-through to string handler below
    }

    if (! defined $data) {
        $self->debug("encoding undef") if DEBUG;
        return 'undef';
    }
    elsif (! ref $data) {
        if ($data =~ /^ $MATCH_NUMBER $/ox) {
            $self->debug("encoding number: $data") if DEBUG;
            return $data;
        }
        else {
            # escape any single quotes or backslashes in the value before quoting it
            $self->debug("encoding text: $data") if DEBUG;
            $data =~ s/(['\\])/\\$1/g;
            return "'" . $data . "'";
        }
    }
    elsif (ref $data eq ARRAY) {
        $self->debug("encoding list") if DEBUG;
        return '[' . join($self->{ comma }, map { _encode($self, $_) } @$data) . ']';
    }
    elsif (ref $data eq HASH) {
        $self->debug("encoding hash") if DEBUG;
        my $a = $self->{ assign };
        my ($k, $v);
        return 
            '{'
          . join($self->{ comma }, 
                map { 
                    $k = $_;
                    $v = _encode($self,  $data->{$k});
                    if ($k =~ /\W/) {
                        $k =~ s/(['\\])/\\$1/g;
                        $k = "'" . $k . "'";
                    }
                    $k . $a . $v;           # key = value
                } 
                sort keys %$data
            )
          . '}';
    }
    else {
        return $self->error_msg( bad_ref => ref $data );
    }
}

sub _decode {
    my $self = shift;
    my $text = ref $_[0] ? $_[0] : \$_[0];
    my ($key, $value);

    if (DEBUG) {
        my $pos = pos $$text;
        if ($pos) {
            $$text =~ /\G(.*)/;
            $self->debug("decoding: $1\n");
            pos $$text = $pos;
        }
        else {
            $self->debug("decoding: $$text\n");
        }
    }

    if ($$text =~ /$MATCH_HASH/cog) {
        $self->debug("matched hash\n") if DEBUG;
        $value = { };
        while ($$text =~ /$MATCH_KEY/cog) {
            if (defined $1) {
                $key = $1;
            }
            else {
                $key = $2;
                $key =~ s/$MATCH_ESCAPED/$1/og; 
            }
            $$text =~ /$MATCH_ASSIGN/cog
                || return $self->error("Missing value after $key");
            $value->{ $key } = _decode($self, $text);
            $$text =~ /$MATCH_COMMA/cog;
        }
        $$text =~ /$MATCH_END_HASH/cog
            || return $self->error("missing } at end of hash definition");
    }
    elsif ($$text =~ /$MATCH_LIST/cog) {
        $self->debug("matched list\n") if DEBUG;
        $value = [ ];
        while (1) {
            if ($$text =~ /$MATCH_END_LIST/cog) {
                last if $1 eq ']';
                return $self->error("missing ] at end of list definition ($1)");
            }
            push(@$value, _decode($self, $text));
            $$text =~ /$MATCH_COMMA/cog;
        }
    }
    elsif ($$text =~ /$MATCH_QUOTED/cog) {
        $self->debug("matched quoted\n") if DEBUG;
        $value = $1;
        $value =~ s/$MATCH_ESCAPED/$1/og; 
        $self->debug("found quoted string: $value\n") if DEBUG;
    }
    elsif ($$text =~ /$MATCH_NUMBER/cog) {
        $self->debug("matched number") if DEBUG;
        $value = $1;
        $self->debug("found number: $value\n") if DEBUG;
    }
    elsif ($$text =~ /$MATCH_UNDEF/cog) {
        $self->debug("matched undef") if DEBUG;
        $value = undef;
    }
    else {
        $self->debug("matched other") if DEBUG;
        $$text =~ /\G(.*)/;
        return $self->error("bad value: $1")
    }
    return $value;
}

1;

=head1 NAME

Badger::Codec::TT - encode/decode data using TT data syntax

=head1 SYNOPSIS

    use Badger::Codec::TT;
    my $codec   = Badger::Codec::TT->new();
    my $encoded = $codec->encode({ msg => "Hello World" });
    my $decoded = $codec->decode($encoded);

=head1 DESCRIPTION

This module implements a subclass of L<Badger::Codec> which encodes and
decodes data to and from an extended form of the data definition syntax used
in the Template Toolkit.

The syntax is similar to Perl in that it uses single quotes for literal
strings, square brackets for list definitions and curly braces for hash
definitions along with the C<=E<gt>> "fat comma" operator to separate hash
keys and values. Data structures can be nested indefinitely. The unquoted
C<undef> token can be used to explicitly represent the undefined value.

    {
        message => 'Hello World, this is some text',
        things  => ['a list', 'of some things'],
        stuff   => {
            pi  => 3.14,
            foo => [ { nested => 'hash' }, ['nested', 'list' ] ],
            nul => undef,
        },
    }

TT syntax is more liberal than Perl.  It allows you to use C<=> instead
of C<=E<gt>> to separate keys and values in hash arrays, and commas between
items are optional.

    {
        message = 'Hello World, this is some text'
        things  = ['a list' 'of some things']
        stuff   = {
            pi  = 3.14
            foo = [ { nested = 'hash' } ['nested' 'list' ] ]
            nul = undef
        }
    }

It will also accept C<:> as a delimiter between hash keys and values,
thus providing an overlap with a useful subset of JSON syntax:

    {
        message: 'Hello World, this is some text',
        things: ['a list' 'of some things'],
        stuff: {
            pi:  3.14,
            foo: [ { nested: 'hash' }, ['nested', 'list' ] ],
            nul: undef
        }
    }

The decoder is very liberal in what it will accept for delimiters. You can mix
and match any of the above styles in the same document if you really want to.
However, you would be utterly batshit insane to do such a thing, let alone
want for it. Just because we'll accept any of the commonly used formats
doesn't mean that you should be using them all at once.

    {
        perl => 'Perl looks like this',
        tt   =  'TT looks like this'
        json: 'JSON looks like this
    }

Note that while the syntax may be more liberal than either Perl or JSON,
the semantics are decidedly stricter.  It is not possible to embed arbitrary
Perl code, instantiate Javascript objects, or do anything else outside of
defining vanilla data structures.

The encoder generates TT syntax by default (C<=> for assignment, with a single
space to delimiter items).  You can change these options using the C<assign>
and C<comma> configuration options.

    my $codec = Badger::Codec::TT->new( assign => '=>', comma => ',' );
    print $codec->encode($some_data);

=head1 METHODS

=head2 encode($data)

Encodes the Perl data in C<$data> to a TT string.

    $encoded = Badger::Codec::TT->encode($data);   

=head2 decode($tt)

Decodes the encoded TT string in C<$tt> back into a Perl data structure.

    $decoded = Badger::Codec::TT->decode($encoded);

=head2 encoder()

This method returns a reference to an encoding subroutine.

    my $sub = Badger::Codec::TT->encoder;
    $encoded = $sub->($data);

=head2 decoder()


This method returns a reference to a decoding subroutine.

    my $sub = Badger::Codec::TT->decoder;
    $decoded = $sub->($encoded);

=head1 INTERNAL SUBROUTINES

=head2 _encode($data)

This internal subroutine performs the recursive encoding of the data.

=head2 _decode($tt)

This internal subroutine performs the recursive decoding of the data.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2005-2009 Andy Wardley. All rights reserved.

=head1 SEE ALSO

L<Badger::Codecs>, L<Badger::Codec>, L<Template>

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

