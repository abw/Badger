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
use Badger::Constants 'HASH ARRAY PKG DELIMITER BLANK';
use Badger::Debug 
    import  => ':dump',
    default => 0;
use overload;
use constant {
    UTILS  => 'Badger::Utils',
    CLASS  => 0,
    FILE   => 1,
    LOADED => 2,
};

our $VERSION  = 0.02;
our $ERROR    = '';
our $WARN     = sub { warn @_ };  # for testing - see t/core/utils.t
our $MESSAGES = { };
our $HELPERS  = {       # keep this compact in case we don't need to use it
    'Digest::MD5'        => 'md5 md5_hex md5_base64',
    'Scalar::Util'       => 'blessed dualvar isweak readonly refaddr reftype 
                             tainted weaken isvstring looks_like_number 
                             set_prototype',
    'List::Util'         => 'first max maxstr min minstr reduce shuffle sum',
    'List::MoreUtils'    => 'any all none notall true false firstidx 
                             first_index lastidx last_index insert_after 
                             insert_after_string apply after after_incl before 
                             before_incl indexes firstval first_value lastval 
                             last_value each_array each_arrayref pairwise 
                             natatime mesh zip uniq minmax',
    'Hash::Util'         => 'lock_keys unlock_keys lock_value unlock_value
                             lock_hash unlock_hash hash_seed',
    'Badger::Timestamp'  => 'TIMESTAMP TS Timestamp Now',
    'Badger::Logic'      => 'LOGIC Logic',
    'Badger::Duration'   => 'DURATION Duration',
    'Badger::URL'        => 'URL',
    'Badger::Filesystem' => 'FS File Dir Bin',
    'Badger::Filesystem::Virtual' 
                         => 'VFS',
};
our $DELEGATES;         # fill this from $HELPERS on demand
our $RANDOM_NAME_LENGTH = 32;
our $TEXT_WRAP_WIDTH    = 78;


__PACKAGE__->export_any(qw(
    UTILS blessed is_object numlike textlike params self_params plural 
    odd_params xprintf dotid random_name camel_case CamelCase wrap
    permute_fragments plurality inflect split_to_list extend
    list_each hash_each join_uri resolve_uri
));

__PACKAGE__->export_fail(\&_export_fail);

# looks_like_number() is such a mouthful.  I prefer numlike() to go with textlike()
*numlike = \&Scalar::Util::looks_like_number;

# it would be too confusing not to have this alias
*CamelCase = \&camel_case;


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
    my $helpers = shift;
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

sub textlike($) {
    !  ref $_[0]                        # check if $[0] is a non-reference
    || blessed $_[0]                    # or an object with an overloaded
    && overload::Method($_[0], '""');   # '""' stringification operator
}

sub params {
    # enable $DEBUG to track down calls to params() that pass an odd number 
    # of arguments, typically when the rhs argument returns an empty list, 
    # e.g. $obj->foo( x => this_returns_empty_list() )
    my @args = @_;
    local $SIG{__WARN__} = sub {
        odd_params(@args);
    } if DEBUG;

    @_ && ref $_[0] eq HASH ? shift : { @_ };
}

sub self_params {
    my @args = @_;
    local $SIG{__WARN__} = sub {
        odd_params(@args);
    } if DEBUG;
    
    (shift, @_ && ref $_[0] eq HASH ? shift : { @_ });
}

sub odd_params {
    my $method = (caller(2))[3];
    $WARN->(
        "$method() called with an odd number of arguments: ", 
        join(', ', map { defined $_ ? $_ : '<undef>' } @_),
        "\n"
    );
    my $i = 3;
    while (1) {
        my @info = caller($i);
        last unless @info;
        my ($pkg, $file, $line, $sub) = @info;
        $WARN->(
            sprintf(
                "%4s: Called from %s in %s at line %s\n",
                '#' . ($i++ - 2), $sub, $file, $line
            )
        );
    }
}
    

sub module_file {
    my $file = shift;
    $file  =~ s[::][/]g;
    $file .= '.pm';
}

sub xprintf {
    my $format = shift;
    my @args   = @_;
    $format =~ 
        s{ < (\d+) 
             (?: :( [#\-\+ ]? [\w\.]+ ) )?
             (?: \| (.*?) )?
           > 
         }
         {   defined $3
                ? _xprintf_ifdef(\@args, $1, $2, $3)
                : '%' . $1 . '$' . ($2 || 's') 
        }egx;
    sprintf($format, @_);
}

sub _xprintf_ifdef {
    my ($args, $n, $format, $text) = @_;
    if (defined $args->[$n-1]) {
        $format = 's' unless defined $format;
        $format = '%' . $n . '$' . $format;
        $text =~ s/\?/$format/g;
        return $text;
    }
    else {
        return '';
    }
}

sub dotid {
    my $text = shift;       # munge $text to canonical lower case and dotted form
    $text =~ s/\W+/./g;     # e.g. Foo::Bar ==> Foo.Bar
    return lc $text;        # e.g. Foo.Bar  ==> foo.bar
}

sub camel_case {
    join(
        BLANK, 
        map {
            map { ucfirst $_ } 
            split '_'
        } 
        @_
    );
}

sub random_name {
    my $length = shift || $RANDOM_NAME_LENGTH;
    my $name   = '';
    require Digest::MD5;
    
    while (length $name < $length) {
        $name .= Digest::MD5::md5_hex(
            time(), rand(), $$, { }, @_
        );
    }
    return substr($name, 0, $length);
}

sub alternates {
    my $text = shift;
    return  [ 
        $text =~ /\|/
            ? split(qr<\|>, $text, -1)  # alternates: (foo|bar) as ['foo', 'bar']
            : ('', $text)               # optional (foo) as (|foo) as ['', 'foo']
    ];
}

sub wrap {
    my $text   = shift;
    my $width  = shift || $TEXT_WRAP_WIDTH;
    my $indent = shift || 0;
    my @words = split(/\s+/, $text);
    my (@lines, @line, $length);
    my $total = 0;
    
    while (@words) {
        $length = length $words[0] || (shift(@words), next);
        if ($total + $length > 74 || $words[0] eq '\n') {
            shift @words if $words[0] eq '\n';
            push(@lines, join(" ", @line));
            @line = ();
            $total = 0;
        }
        else {
            $total += $length + 1;      # account for spaces joining words
            push(@line, shift @words);
        }
    }
    push(@lines, join(" ", @line)) if @line;
    return join(
        "\n" . (' ' x $indent), 
        @lines
    );
}


sub permute_fragments {
    my $input = shift;
    my (@frags, @outputs);

    # Lookup all the (a) optional fragments and (a|b|c) alternate fragments
    # replace them with %s.  This gives us an sprintf format that we can later
    # user to re-fill the fragment slots.  Meanwhile create a list of @frags
    # with each item corresponding to a (...) fragment which is represented 
    # by a list reference containing the alternates.  e.g. the input
    # string 'Fo(o|p) Ba(r|z)' generates @frags as ( ['o','p'], ['r','z'] ),
    # leaving $input set to 'Fo%s Ba%s'.  We treat (foo) as sugar for (|foo), 
    # so that 'Template(X)' is permuted as ('Template', 'TemplateX'), for 
    # example.
    
    $input =~ 
        s/ 
            \( ( .*? ) \) 
        /
            push(@frags, alternates($1));
            '%s';
        /gex;

    # If any of the fragments have multiple values then $format will still contain
    # one or more '%s' tokens and @frags will have the same number of list refs
    # in it, one for each fragment.  To iterate across all permutations of the 
    # fragment values, we calculate the product P of the sizes of all the lists in 
    # @frags and loop from 0 to P-1.  Then we use a div and a mod to get the right 
    # value for each fragment, for each iteration.  We divide $n by the product of
    # all fragment lists to the right of the current fragment and mod it by the size
    # of the current fragment list.  It's effectively counting with a different base
    # for each column. e.g. consider 3 fragments with 7, 3, and 5 values respectively
    #   [7]            [3]           [5]         P = 7 * 3 * 5 = 105
    #   [n / 15 % 7]   [n / 5 % 3]   [n % 5]     for 0 < n < P 

    if (@frags) {
        my $product = 1; $product *= @$_ for @frags;
        for (my $n = 0; $n < $product; $n++) {
            my $divisor = 1;
            my @args = reverse map {
                my $item = $_->[ $n / $divisor % @$_ ];
                $divisor *= @$_;
                $item;
            } reverse @frags;   # working backwards from right to left
            push(@outputs, sprintf($input, @args));
        }
    }
    else {
        push(@outputs, $input);
    }
    return wantarray
        ?  @outputs
        : \@outputs;
}

#-----------------------------------------------------------------------------
# pluralisation and inflection
#-----------------------------------------------------------------------------

sub plural {
    my $name = shift;

    if ($name =~ /(ss|sh|ch|x)$/) {
        $name .= 'es';
    }
    elsif ($name =~ s/([^aeiou])y$//) {
        $name .= $1.'ies';
    }
    elsif ($name =~ /([^s\d\W])$/) {
        $name .= 's';
    }
    return $name;
}

sub plurality {
    my $n     = shift || 0;
    my @items = map { permute_fragments($_) } 
                (@_ == 1 && ref $_[0] eq ARRAY)
                ? @{ $_[0] }
                : @_;

    # if the user specifies a single word then we pluralise it for them,
    # assuming that 0 items are plural, 1 is singular, and > 1 is plural
    if (@items == 1) {
        my $plural = plural($items[0]);
        unshift(@items, $plural);       # 0 whatevers
        push(@items, $plural);          # n whatevers (where n > 1)
    }

    die "$n is not a number\n" unless numlike($n);
    my $i = $n > $#items ? $#items : $n;
    $i    = 0 if $i < 0;

    return $items[$i];
}

sub inflect {
    my $n = shift || 0;
    my $i = shift;
    my $f = shift || '%s %s';
    my $z = @_ ? shift : 'no';
    return xprintf(
        $f, ($n or $z), plurality($n, $i)
    );
}


sub _debug {
    print STDERR @_;
}

#-----------------------------------------------------------------------------
# List utilities
#-----------------------------------------------------------------------------

sub list_each {
    my ($list, $fn) = @_;
    my $n = 0;

    for (@$list) {
        $fn->($list, $n++, $_);
    }

    return $list;
}

sub split_to_list {
    my $list = shift;
    $list = [ split(DELIMITER, $list) ]
        unless ref $list eq ARRAY;
    return $list;
}

#-----------------------------------------------------------------------------
# Hash utilities
#-----------------------------------------------------------------------------

sub hash_each {
    my ($hash, $fn) = @_;

    while (my ($key, $value) = each %$hash) {
        $fn->($hash, $key, $value);
    }

    return $hash;
}


sub extend {
    my $hash = shift;
    my $more;

    while (@_) {
        if (! $_[0]) {
            # ignore undefined/false values
            shift;
            next;
        }
        elsif (ref $_[0] eq HASH) {
            $more = shift;
        }
        else {
            $more = params(@_);
            @_    = ();
        }
        @$hash{ keys %$more } = values %$more;
    }
    
    return $hash;
}


#-----------------------------------------------------------------------------
# Simple URI manipulation
#-----------------------------------------------------------------------------

sub join_uri {
    my $uri = join('/', @_);
    $uri =~ s{/+}{/}g;
    return $uri;
}

sub resolve_uri {
    my $base = shift;
    my $rel  = join_uri(@_);
    return ($rel =~ m{^/})
        ? $rel
        : join_uri($base, $rel);
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

=head1 EXPORTABLE CONSTANTS

=head2 UTILS

Exports a C<UTILS> constant which contains the name of the C<Badger::Utils>
class.  

=head1 EXPORTABLE FUNCTIONS

C<Badger::Utils> can automatically load and export functions defined in the
L<Scalar::Util>, L<List::Util>, L<List::MoreUtils>, L<Hash::Util> and
L<Digest::MD5> Perl modules.

    use Badger::Utils 'blessed max md5_hex'

    # a rather contrived example
    if (blessed $some_ref) {
        print md5_hex(max @some_list);
    }

C<Badger::Utils> can also automatically load and export functions and 
constants defined in various other Badger modules.  For example, you can use 
C<Badger::Utils> to load the L<Now()|Badger::Timestamp/Now()> function 
from L<Badger::Timestamp>.

    use Badger::Utils 'Now';
    print Now->year;            # prints the current year

=head2 L<Badger::Duration> 

=head3 L<DURATION|Badger::Duration/DURATION>

An alias for L<Badger::Duration>.

=head3 L<Duration()|Badger::Duration/Duration()>

A function to create a L<Badger::Duration> object.

    use Badger::Utils 'Duration';

    my $duration = Duration('2 hours 20 minutes');
    print $duration->seconds;

=head2 L<Badger::Filesystem>

=head3 L<FS|Badger::Filesystem/FS>, 

An alias for C<Badger::Filesystem>.

=head3 L<VFS|Badger::Filesystem::Virtual/VFS>, 

An alias for C<Badger::Filesystem::Virtual>.

=head3 File()

A function for creating a L<Badger::Filesystem::File> object.

    my $f = File('filename');
    print $filename->modified;

=head3 Dir()

A function for creating a L<Badger::Filesystem::Directory> object.

=head3 Bin()

Returns a L<Badger::Filesystem::Directory> object for the directory in 
which the current script is located.  See L<Bin()|Badger::Filesystem/Bin>
in L<Badger::Filesystem>.

=head2 L<Badger::Logic>

=head3 L<LOGIC|Badger::Logic/LOGIC>

An alias for C<Badger::Logic>.

=head3 L<Logic()|Badger::Logic/Logic()>.

Function for returning a L<Badger::Logic> object for representing simple
logical assertions.

    my $logic  = Logic('trusted and not banned');
    my $person = {
        trusted => 1,
        banned  => 0,
    };

    if ($logic->evaluate($person)) {
        ...
    }

=head2 L<Badger::Timestamp>

=head3 L<TIMESTAMP|Badger::Timestamp/TIMESTAMP>

An alias for C<Badger::Timestamp>.

=head3 L<TS|Badger::Timestamp/TS>

A shorter alias for C<Badger::Timestamp>.

=head3 L<Now()|Badger::Timestamp/Now()>.

Function for returning a L<Badger::Timestamp> object representing the 
current date and time.

    print Now->date;

=head3 L<Timestamp()|Badger::Timestamp/Timestamp()>

Function for creating a L<Badger::Timestamp> object.

    my $stamp = Timestamp('2013-03-19 16:20:00');
    print $stamp->time;
    print $stamp->year;

=head2 L<Badger::URL>

=head3 L<URL()|Badger::URL/URL()>

Function for creating a L<Badger::URL> object for representing and
manipulating a URL.

    my $url = URL('http://badgerpower.org/example?animal=badger');
    print $url->path;
    print $url->query;
    print $url->server;

=head2 Text Utility Functions

=head3 alternates($text)

This function is used internally by the L<permute_fragments()> function. It
returns a reference to a list containing the alternates split from C<$text>.

    alternates('foo|bar');          # returns ['foo','bar']
    alternates('foo');              # returns ['','bar']

If the C<$text> doesn't contain the C<|> character then it is assumed to be
an optional item.  A list reference is returned containing the empty string
as the first element and the original C<$text> string as the second.

=head3 camel_case($string) / CamelCase($string)

Converts a lower case string where words are separated by underscores (e.g.
C<like_this_example>) into CamelCase where each word is capitalised and words
are joined together (e.g. C<LikeThisExample>).

According to Perl convention (and personal preference), we use the lower case
form wherever possible. However, Perl's convention also dictates that module
names should be in CamelCase.  This function performs that conversion.

=head3 dotid($text)

The function returns a lower case representation of the text passed as
an argument with all non-word character sequences replaced with dots.

    print dotid('Foo::Bar');            # foo.bar

=head3 inflect($n, $noun, $format, $none_word)

This uses the C<plurality()> function to construct an 
appropriate string listing the number C<$n> of C<$noun> items.

    inflect(0, 'package');      # no packages
    inflect(1, 'package');      # 1 package
    inflect(2, 'package');      # 2 packages

Or:

    inflect($n, 'wo(men|man|men');

The third optional argument can be used to specify a format string for 
L<xprintf> to generate the string.  The default value is C<%s %s>, expecting
the number (or word 'no') as the first parameter, followed by the relevant
noun as the second.

    inflect($n, 'item', 'There are <b>%s</b> %s in your basket');

The fourth optional argument can be used to provide a word other than 'no'
to be used when C<$n> is zero.

    inflect(
        $n, 'item', 
        'You have %s %s in your basket', 
        'none, none more'
    );

Please note that this function is intentionally limited.  It's sufficient to 
generate simple headings, summary lines, etc., but isn't intended to be
comprehensive or work in languages other than English.

=head3 numlike($item)

This is an alias to the C<looks_like_number()> function defined in 
L<Scalar::Util>.  

=head3 permute_fragments($text)

This function permutes any optional or alternate fragments embedded in 
parentheses. For example, C<Badger(X)> is permuted as (C<Badger>, C<BadgerX>)
and C<Badger(X|Y)> is permuted as (C<BadgerX>, C<BadgerY>).

    permute_fragments('Badger(X)');     # Badger, BadgerX
    permute_fragments('Badger(X|Y)');   # BadgerX, BadgerY

Multiple fragments may be embedded. They are expanded in order from left to
right, with the rightmost fragments changing most often.

    permute_fragments('A(1|2):B(3|4)')  # A1:B3, A1:B4, A2:B3, A2:B4

=head3 plural($noun)

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

=head3 plurality($n, $noun)

This function can be used to construct the correct singular or plural form
for a given number, C<$n>, of a noun, C<$noun> in the English language.
For nouns that pluralise regularly (i.e. via the quick-and-dirty L<plural()> 
function), the following is sufficient:

    plurality(0, 'package');      # packages
    plurality(1, 'package');      # package
    plurality(2, 'package');      # packages

For nouns that don't pluralise regularly, or where more complicated phrases
should be constructed, the alternates for 0, 1 and 2 or more items can be
specified in the format expected by L<permute_fragments()>.

    plurality($n, 'women|woman|women');     # 0 women, 1 woman, 2 women
    plurality($n, 'wo(men|man|men');        # optimised form

=head3 random_name($length,@data)

Generates a random name of maximum length C<$length> using any additional 
seeding data passed as C<@args>.  If C<$length> is undefined then the default
value in C<$RANDOM_NAME_LENGTH> (32) is used.

    my $name = random_name();
    my $name = random_name(64);

=head3 textlike($item)

Returns true if C<$item> is a non-reference scalar or an object that
has an overloaded stringification operator.

    use Badger::Filesystem 'File';
    use Badger::Utils 'textlike';
    
    # Badger::Filesystem::File objects have overloaded string operator
    my $file = File('example.txt'); 
    print $file;                                # example.txt
    print textlike $file ? 'ok' : 'not ok';     # ok

=head3 wrap($text, $width, $indent)

Simple subroutine to wrap C<$text> to a fixed C<$width>, applying an optional
indent of C<$indent> spaces.  It uses a trivial algorithm which splits the 
text into words, then rejoins them as lines.  It has an additional hack to 
recognise the literal sequence '\n' as a magical word indicating a forced 
newline break.  It must be specified as a separate whitespace delimited word.

    print wrap('Foo \n Bar');

If anyone knows how to make L<Text::Wrap> handle this, or knows of a better
solution then please let me know.

=head3 xprintf($format,@args)

A wrapper around C<sprintf()> which provides some syntactic sugar for 
embedding positional parameters.

    xprintf('The <2> sat on the <1>', 'mat', 'cat');
    xprintf('The <1> costs <2:%.2f>', 'widget', 11.99);

=head2 Hash Utility Functions

=head3 extend($hash, $another_hash, $yet_another_hash, ...)

This function merges the contents of several hash arrays into one.
The first hash array will end up containing the keys and values of 
all the others.

    my $one = { a => 10 };
    my $two = { b => 20 };
    extend($one, $two);     # $one now contains a and b

If you want to create a new hash, simply pass an empty hash in as the 
first argument.

    my $mixed = extend(
        { },
        $one.
        $two
    );

You can also extend a hash array with named parameters.

    extend(
        $mixed,
        c => 30,
        d => 40,        
    );

You can mix and match the two calling conventions as long as any hash 
references come first.

    extend(
        { },
        $mixed,
        $a,
        $b,
        c => 30,
        d => 40,
    );

=head3 hash_each($hash,$function)

Iterates over each key/value pair in the hash array referenced by the first 
argument, C<$hash>, calling the function passed as the second argument, 
C<$function>.

The function is called with 3 arguments: a reference to the hash array, 
the key of the current item and the value.

    hash_each(
        { a => 10, b => 20 }, 
        sub {
            my ($hash, $key, $value) = @_;
            print "hash item $key is $value\n";
        }
    );

=head2 List Utility Functions

=head3 list_each($list,$function)

Iterates over each item in the array referenced by the first argument, 
C<$list>, calling the function passed as the second argument, C<$function>.

The function is called with 3 arguments: a reference to the list, the 
index of the current index (from 0 to size-1) and the item in the list
at that index.

    list_each(
        [10,20,30], 
        sub {
            my ($list, $index, $item) = @_;
            print "list item #$index is $item\n";
        }
    );

=head3 split_to_list($list)

This splits a string of words separated by whitespace (and/or commas) 
into a list reference.  The following are all valid and equivalent:

    my $list = split_to_list("foo bar baz");    # => ['foo', 'bar', 'baz']
    my $list = split_to_list("foo,bar,baz");
    my $list = split_to_list("foo, bar, baz");

If the argument is already a list then it is returned unmodified.

=head2 Object Utility Functions

=head3 is_object($class,$object)

Returns true if the C<$object> is a blessed reference which isa C<$class>.

    use Badger::Filesystem 'FS';
    use Badger::Utils 'is_object';
    
    if (is_object( FS => $object )) {       # FS == Badger::Filesystem
        print $object, ' isa ', FS, "\n";
    }

=head2 Parameter Handling Functions

=head3 params(@args)

Method to coerce a list of named parameters to a hash array reference.  If the
first argument is a reference to a hash array then it is returned.  Otherwise
the arguments are folded into a hash reference.

    use Badger::Utils 'params';
    
    params({ a => 10 });            # { a => 10 }
    params( a => 10 );              # { a => 10 }

Pro Tip: If you're getting warnings about an "Odd number of elements in
anonymous hash" then try enabling debugging in C<Badger::Utils>. To do this,
add the following to the start of your program before you've loaded
C<Badger::Utils>:

    use Badger::Debug
        modules => 'Badger::Utils'

When debugging is enabled in C<Badger::Utils> you'll get a full stack 
backtrace showing you where the subroutine was called from.  e.g.

    Badger::Utils::self_params() called with an odd number of arguments: <undef>
    #1: Called from Foo::bar in /path/to/Foo/Bar.pm at line 210
    #2: Called from Wam::bam in /path/to/Wam/Bam.pm at line 420
    #3: Called from main in /path/to/your/script.pl at line 217

=head3 self_params(@args)

Similar to L<params()> but also expects a C<$self> reference at the start of
the argument list.

    use Badger::Utils 'self_params';
    
    sub example {
        my ($self, $params) = self_params(@_);
        # do something...
    }

If you enable debugging in C<Badger::Utils> then you'll get a stack backtrace
in the event of an odd number of parameters being passed to this function.
See L<params()> for further details.

=head3 odd_params(@_)

This is an internal function used by L<params()> and L<self_params()> to 
report any attempt to pass an odd number of arguments to either of them.
It can be enabled by setting C<$Badger::Utils::DEBUG> to a true value.

    use Badger::Utils 'params';
    $Badger::Utils::DEBUG = 1;
    
    my $hash = params( foo => 10, 20 );    # oops!

The above code will raise a warning showing the arguments passed and a 
stack backtrace, allowing you to easily track down and fix the offending
code.  Apart from obvious typos like the above, this is most likely to 
happen if you call a function or methods that returns an empty list.  e.g.

    params(
        foo => 10,
        bar => get_the_bar_value(),
    );

If C<get_the_bar_value()> returns an empty list then you'll end up with an
odd number of elements being passed to C<params()>.  You can correct this
by providing C<undef> as an alternative value.  e.g.

    params(
        foo => 10,
        bar => get_the_bar_value() || undef,
    );

=head2 URI Utility Functions

The following functions are provided for very simple manipulation of 
URI paths.  You should consider using the L<URI> module for anything 
non-trivial.

=head3 join_uri(frag1, frag2, etc)

Joins the elements of a URI passed as arguments into a single URI.

    use Contentity::Utils 'join_uri';
    print join_uri('/foo', 'bar');     # /foo/bar

=head3 resolve_uri(base, frag1, frag2, etc)

The first argument is a base URI.  The remaining argument(s) are joined 
(via L<join_uri()>) to construct a relative URI.  If the relative URI begins
with C</> then it is considered absolute and is returned unchanged.  Otherwise
it is appended to the base URI.

    use Contentity::Utils 'resolve_uri';
    print resolve_uri('/foo', 'bar/baz');     # /foo/bar/baz
    print resolve_uri('/foo', '/bar/baz');    # /bar/baz

=head2 Miscellanesou Utility Functions

=head3 module_file($name)

Returns the module name passed as an argument as a relative filesystem path
suitable for feeding into C<require()>

    print module_file('My::Module');     # My/Module.pm

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2013 Andy Wardley.  All Rights Reserved.

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
