package Badger::URL;

use Badger::Class
    version     => 0.02,
    debug       => 0,
    base        => 'Badger::Base',
    import      => 'CLASS class',
    utils       => 'textlike is_object',
    codec       => 'uri',           # we use URI encoding for parameters
    as_text     => \&text,
    is_true     => 1,               # not sure about this
    constants   => 'HASH BLANK',
    constant    => {
        SLASH     => '/',
        TEXT      => 0,
        SCHEME    => 1,
        AUTHORITY => 2,
        USER      => 3,
        HOST      => 4,
        PORT      => 5,
        PATH      => 6,
        QUERY     => 7,
        FRAGMENT  => 8,
        PARAMS    => 9,
    },
    alias       => {
        url     => \&text,
    },
    exports     => {
        any     => 'URL',
    };


#------------------------------------------------------------------------
# Example URL:
#
#     scheme  authority            path        query       fragment
#      __     ___________________  _________   _________   __
#     /  \   /                   \/         \ /         \ /  \
#     http://user@example.com:8042/over/there?name=ferret#nose
#            \__/ \_________/ \__/
#            user    host     port
#
#------------------------------------------------------------------------

our @ELEMENTS = qw(
    scheme authority user host port path query fragment params
);
our $N_ELEMS  = 1;      # slot 0 holds source text, so slot 1 is first field
our $ELEMENT  = {
    map { $_ => $N_ELEMS++ }
    @ELEMENTS
};

# regexen to match basic tokens
our $MATCH_SCHEME    = qr{ ( [a-zA-Z][a-zA-Z0-9.+\-]* ) : }x;
our $MATCH_USER      = qr{ ([^@]*) @ }x;
our $MATCH_HOST      = qr{ ( [^:\/]* ) }x;
our $MATCH_PORT      = qr{ : (\d*) }x;
our $MATCH_PATH      = qr{ ( [^ \? \#]* ) }x;
our $MATCH_QUERY     = qr{ \? ( [^ \#]* ) }x;
our $MATCH_FRAGMENT  = qr{ \# ( .* ) }x;

# compound regexen to match authority
our $MATCH_AUTHORITY = qr{
    // (                            # $1 - authority
        (?: $MATCH_USER )?          # $2 - user
            $MATCH_HOST             # $3 - host
        (?: $MATCH_PORT )?          # $4 - port
       )
}x;

# compound regexen to match complete URL
our $MATCH_URL = qr{
    ^  (?: $MATCH_SCHEME )?         # $1 - scheme
       (?: $MATCH_AUTHORITY )?      # $2,$3,$4,$5 - authority,user,host,port
           $MATCH_PATH              # $6 - path
       (?: $MATCH_QUERY )?          # $7 - query
       (?: $MATCH_FRAGMENT )?       # $8 - fragment
    }x;



#------------------------------------------------------------------------
# Constructor function and methods.
#------------------------------------------------------------------------

sub URL {
    return CLASS unless @_;
    return @_ == 1 && is_object(CLASS, $_[0])
        ? $_[0]->copy                           # copy existing URL object
        : CLASS->new(@_);                       # or construct a new one
}


sub new {
    my $class = shift;
    my $args  = @_ == 1 ? shift : { @_ };
    my $self;

    $class = ref $class || $class;

    if (textlike $args) {
        $self = bless [$args, $args =~ $MATCH_URL], $class;
    }
    elsif (ref $args eq HASH) {
        $self = bless [ ], $class;
        $self->set($args);

    }
    else {
        return $class->error("Invalid URL specification: $_[0]");
    }

    return $self;
}


sub copy {
    my $self = shift;
    my $copy = bless [ @$self ], ref $self;
    return @_
        ? $copy->set(@_)
        : $copy;
}


sub set {
    my $self = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my ($k, $v, $n);

    while (($k, $v) = each %$args) {
        $n = $ELEMENT->{ $k } || next;
        $self->[$n] = $v;
    }

    # The authority is comprised of the user, host and port fields.
    # We need to split any authority specified, or merge together the user,
    # host and port if any of them have been changed
    $self->split_authority
        if exists $args->{ authority };

    $self->join_authority
        if exists $args->{ user }
        or exists $args->{ host }
        or exists $args->{ port };

    # similar thing for query/params
    $self->split_query
        if exists $args->{ query };

    $self->join_query
        if exists $args->{ params };

    # finally reconstruct the complete url
    $self->join_url;

    return $self;
}


#-----------------------------------------------------------------------
# split/join methods
#-----------------------------------------------------------------------

sub split_authority {
    my $self = shift;
    $self->[AUTHORITY] = BLANK
        unless defined $self->[AUTHORITY];

    # this regex shouldn't ever fail as everything is optional
    @$self[AUTHORITY,USER,HOST,PORT]
        = $self->[AUTHORITY] =~ $MATCH_AUTHORITY;
}


sub join_authority {
    my $self = shift;
    my ($user, $host, $port) = @$self[USER,HOST,PORT];

    $user = (defined $user && length $user) ? $user . '@' : BLANK;
    $port = (defined $port && length $port) ? ':' . $port : BLANK;
    $host = BLANK unless defined $host;

    return ($self->[AUTHORITY] = $user.$host.$port);
}


sub split_query {
    my $self = shift;
    $self->[QUERY] = ''
        unless defined $self->[QUERY];

    return ($self->[PARAMS] = {
        map {
            map { decode($_) }
            split(/=/, $_, 2)
        }
        split(/[&;]/, $self->[QUERY])
    });
}


sub join_query {
    my $self   = shift;
    my $params = $self->[PARAMS] || { } ;       # should we call split_query()?

    return ($self->[QUERY] = join(
        '&',
        map { $_ . '=' . encode( $params->{ $_ } ) }
        sort keys %$params                      # sorted makes debugging easier
    ));
}


sub join_url {
    my $self   = shift;
    my $scheme = $self->[SCHEME];
    my $auth   = $self->[AUTHORITY];
    my $query  = $self->[QUERY];
    my $frag   = $self->[FRAGMENT];

    $scheme = (defined $scheme && length $scheme) ? $scheme . ':' : BLANK;
    $auth   = (defined $auth   && length $auth)   ? '//' . $auth  : BLANK;
    $query  = (defined $query  && length $query)  ? '?'  . $query : BLANK;
    $frag   = (defined $frag   && length $frag)   ? '#'  . $frag  : BLANK;

    return ($self->[TEXT] = $scheme.$auth.$self->[PATH].$query.$frag);
}



#-----------------------------------------------------------------------
# accessor/mutator methods
#-----------------------------------------------------------------------

sub text {
    $_[0]->[TEXT];
}


sub scheme {
    my $self = shift;
    if (@_) {
        $self->[SCHEME] = shift;
        $self->join_url;
    }
    return $self->[SCHEME];
}


sub authority {
    my $self = shift;
    if (@_) {
        $self->[AUTHORITY] = shift;
        $self->split_authority;
        $self->join_url;
    }
    return $self->[AUTHORITY];
}


sub query {
    my $self = shift;
    if (@_) {
        $self->[QUERY] = shift;
        $self->split_query;
        $self->join_url;
    }
    return $self->[QUERY];
}


sub params {
    my $self   = shift;
    my $params = $self->[PARAMS] || $self->split_query;
    if (@_) {
        my $extra = Badger::Utils::params(@_);
        # NOTE: this doesn't account for multi-valued params
        @$params{ keys %$extra } = values %$extra;
        $self->join_query;
        $self->join_url;
    }
    return $params;
}


sub server {
    my $self   = shift;
    my $scheme = $self->[SCHEME];
    my $auth   = $self->[AUTHORITY];

    $scheme = (defined $scheme && length $scheme) ? $scheme.':' : BLANK;
    $auth   = (defined $auth   && length $auth)   ? '//'.$auth  : BLANK;

    return $scheme.$auth;
}


sub service {
    my $self = shift;
    return $self->server
         . $self->[PATH];
}


sub request {
    my $self    = shift;
    my $service = $self->service;
    my $query   = $self->[QUERY];

    $query = (defined $query && length $query) ? '?'.$query : BLANK;

    return $self->service
         . $query;
}


# This is a quick-hack implementation of relative() that bodges the paths.
# This should be replaced with a more robust implementation.  It also needs
# to be integrated with the work on Badger::Filesystem::Universal.

sub relative {
    my $self = shift;
    my $path = join(SLASH, @_);
    my $base = $self->[PATH];
    $base =~ s{/$}{};
    $path = join(SLASH, $base, $path)
        unless $path =~ m{^/};
    return $self->copy( path => $path );
}


sub absolute {
    my $self = shift;
    my $path = shift;
    $path =~ s{^/*}{/};
    return $self->copy( path => $path );
}


sub dump {
    my $self = shift;
    return '[URL:' . join('|', map { defined($_) ? $_ : '' } @$self) . ']';
}



#-----------------------------------------------------------------------
# generated accessor/mutator methods for those with similar functionality
#-----------------------------------------------------------------------

class->methods(
    map {
        my ($name, $slot) = @$_;
        $name => sub {
            my $self = shift;
            if (@_) {
                # if any of user, host or port are updated then we must
                # reconstruct the authority and complete URL
                $self->[$slot] = shift;
                $self->join_authority;
                $self->join_url;
            }
            return $self->[$slot];
        }
    }
    [user => USER],
    [host => HOST],
    [port => PORT],
);

class->methods(
    map {
        my ($name, $slot) = @$_;
        $name => sub {
            my $self = shift;
            if (@_) {
                # if either of the path or fragment are updated then we
                # must regenerate the complete URL
                $self->[$slot] = shift;
                $self->join_url;
            }
            return $self->[$slot];
        }
    }
    [path     => PATH],
    [fragment => FRAGMENT],
);


1;
__END__

=head1 NAME

Badger::URL - representation of a Uniform Resource Locator (URL)

=head1 SYNOPSIS

    use Badger::URL;

    # all-in-one URL string
    my $url = Badger::URL->new(
        'http://abw@badgerpower.com:8080/under/ground?animal=badger#stripe'
    );

    # named parameters
    my $url = Badger::URL->new(
        scheme      => 'http',
        user        => 'abw',
        host        => 'badgerpower.com',
        port        => '8080',
        path        => '/under/ground',
        query       => 'animal=badger',
        fragment    => 'stripe',
    );

    # methods to access standard W3C parts of URL
    print $url->scheme;     # http
    print $url->authority;  # abw@badgerpower.com:8080
    print $url->user;       # abw
    print $url->host;       # badgerpower.com
    print $url->port;       # 8080
    print $url->path;       # /under/ground
    print $url->query;      # animal=badger
    print $uri->fragment;   # stripe

    # additional composite methods:
    print $url->server;
        # http://abw@badgerpower.com:8080

    print $url->service;
        # http://abw@badgerpower.com:8080/under/ground

    print $url->request;
        # http://abw@badgerpower.com:8080/under/ground?animal=badger

    # method to return the whole URL
    print $url->url();
        # http://abw@badgerpower.com:8080/under/ground?animal=badger#stripe

    # overloaded stringification operator calls url() method
    print $url;
        # http://abw@badgerpower.com:8080/under/ground?animal=badger#stripe

=head1 DESCRIPTION

This module implements an object for representing URLs. It can parse existing
URLs to break them down into their constituent parts, and also to generate
new or modified URLs.

The emphasis is on simplicity and convenience for tasks related to web
programming (e.g. dispatching web applications based on the URL, generating
URLs for redirects or embedding as links in HTML pages).  If you want more
generic URI functionality then you should consider using the L<URI> module.

A URL looks like this:

     http://abw@badgerpower.com:8080/under/ground?animal=badger#stripe
     \__/   \______________________/\___________/ \___________/ \____/
      |                |                  |             |          |
    scheme         authority             path         query     fragment

The C<authority> part can be broken down further:

     abw@badgerpower.com:8080
     \_/ \_____________/ \__/
      |         |         |
     user      host      port

A L<Badger::URL> object will parse a URL and store the component parts
internally. You can then change any of the individual parts and regenerate the
URL.

    my $url = Badger::URL->new(
        'http://badgerpower.com/'
    );
    $url->port('8080');
    $url->path('/under/ground');
    $url->query('animal=badger');
    print $url;   # http://badgerpower.com:8080/under/ground?animal=badger

=head1 METHODS

=head2 new($url)

This constructor method is used to create a new URL object.

    my $url = Badger::URL->new(
        'http://abw@badgerpower.com:8080/under/ground?animal=badger#stripe'
    );

You can also specify the individual parts of the URL using named paramters.

    my $url = Badger::URL->new(
        scheme      => 'http',
        user        => 'abw',
        host        => 'badgerpower.com',
        port        => '8080',
        path        => '/under/ground',
        query       => 'animal=badger',
        fragment    => 'stripe',
    );

=head2 copy()

This method creates and returns a new C<Badger::URL> object as a copy of
the current one.

    my $copy = $url->copy;

=head2 url()

Method to return the complete URL.

    print $url->url;
        # http://abw@badgerpower.com:8080/under/ground?animal=badger#stripe

This method is called automatically whenever the URL object is
stringified.

    print $url;                 # same as above

=head2 text()

An alias for the L<url()> method.

=head2 scheme()

Method to get or set the scheme part of the URL.

    $url = Badger::URL->new('http://badgerpower.com/);
    print $url->scheme();       # http
    $url->scheme('ftp');
    print $url->scheme();       # ftp

=head2 authority()

Method to get or set the authority part of the URL. This is comprised of a
host with optional user and/or port.

    $url->authority('badgerpower.com');
    $url->authority('abw@badgerpower.com');
    $url->authority('badgerpower.com:8080');
    $url->authority('abw@badgerpower.com:8080');

    print $url->authority();    # abw@badgerpower.com:8080

=head2 user()

Method to get or set the optional user in the authority part of the URL.

    $url->user('fred');
    print $url->user();         # fred
    print $url->authority();    # fred@badgerpower.com:8080

=head2 host()

Get or set the host in the authority part of the URL.

    $url->host('example.org');
    print $url->host();         # example.org
    print $url->authority();    # fred@example.org:8080

=head2 port()

Get or set the port in the authority part of the URL.

    $url->port(1234);
    print $url->port();         # 1234
    print $url->authority();    # fred@example.org:1234

=head2 path()

Get or set the path part of the URL.

    $url->path('/right/here');
    print $url->path();         # /right/here

=head2 query()

Get or set the query part of the URL.  The leading 'C<?>' is not
considered part of the query and should be should not be included when
setting a new query.

    $url->query('animal=ferret');
    print $url->query();        # animal=ferret

=head2 params()

Get or set the query parameters.

    # get params
    my $params = $url->params;

    # set params
    $url->params(
        x => 10
    );

=head2 fragment()

Get or set the fragment part of the URL.  The leading '#' is not
considered part of the fragment and should be should not be included
when setting a new fragment.

    $url->fragment('feet');
    print $url->fragment();     # feet

=head2 server()

Returns a composite of the scheme and authority.

    print $url->server();
        # http://fred@example.org:1234

=head2 service()

Returns a composite of the server (scheme and authority) and path
(in other words, everything up to the query or fragment).

    print $url->server();
        # http://fred@example.org:1234/right/here

=head2 request()

Returns a composite of the service (scheme, authority and path) and
query (in other words, everything except the fragment).

    print $url->request();
        # http://fred@example.org:1234/right/here?animal=badger

=head2 relative($path)

Returns a new URL with the relative path specified.

    my $base = Badger::URL->new('http://badgerpower.com/example');
    my $rel  = $base->relative('foo/bar');

    print $rel;     # http://badgerpower.com/example/foo/bar

=head2 absolute($path)

Returns a new URL with the absolute path specified.  The leading C</> on
the path provided as an argument is option.  It will be assumed if not
present.

    my $base = Badger::URL->new('http://badgerpower.com/example');
    my $rel  = $base->absolute('foo/bar');

    print $rel;     # http://badgerpower.com/foo/bar

=head1 INTERNAL METHODS

=head2 set($items)

This method is used to set internal values.

=head2 join_authority()

This method reconstructs the C<authority> from the C<host>, C<port> and
C<user>.

=head2 join_query()

This method reconstructs the C<query> from the query parameters.

=head2 join_url()

This method reconstructs the complete URL from its constituent parts.

=head2 split_authority()

This method splits the C<authority> into C<host>, C<port> and C<user>.

=head2 split_query()

This method splits the C<query> string into query parameters.

=head2 dump()

Return a text representation of the structure of the URL object, for
debugging purposes.

=head1 EXPORTABLE SUBROUTINES

=head2 URL($url)

This constructor function can be used to create a new URL.  If the argument
is already a C<Badger::URL> object then it is copied to create a new object.
Otherwise a new C<Badger::URL> object is created from scratch.

    use Badger::URL 'URL';
    my $url1 = URL('http://example.com/foo');
    my $url2 = URL($url1);

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2010 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<URI>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
