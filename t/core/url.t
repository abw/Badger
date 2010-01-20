#============================================================= -*-perl-*-
#
# t/url.t
#
# Test the Badger::URL module.
#
# Run with -h option for help.
#
# Written by Andy Wardley <abw@wardley.org>.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;

use lib qw( t/core/lib ./lib ../lib ../../lib );
use Badger::Test 
    debug => 'Badger::URL',
    args  => \@ARGV,
    tests => 46;

use Badger::URL 'URL';

my $SCHEME    = 'http';
my $USER      = 'badger';
my $HOST      = 'badgerpower.com';
my $PORT      = 8080;
my $AUTHORITY = "$USER\@$HOST:$PORT";
my $PATH      = '/over/there';
my $QUERY     = 'animal=badger';
my $FRAGMENT  = 'nose';
my $SERVER    = "$SCHEME://$AUTHORITY";
my $SERVICE   = "$SERVER$PATH";
my $REQUEST   = "$SERVICE?$QUERY";
my $URL       = "$REQUEST#$FRAGMENT";

my $url = URL->new($URL);
ok( $url, 'created a URL object' );
is( $url, $URL, 'returns source URL on stringification' );

$url = URL($URL);
ok( $url, 'created a URL object from constructor function' );
is( $url, $URL, 'also returns source URL on stringification' );


#------------------------------------------------------------------------
# test accessors to read various parts of the URL
#------------------------------------------------------------------------

is( $url->scheme, $SCHEME, "scheme is $SCHEME" );
is( $url->authority, $AUTHORITY,"authority is $AUTHORITY" );
is( $url->user, $USER, "user is $USER" );
is( $url->host, $HOST, "host is $HOST" );
is( $url->port, $PORT, "port is $PORT" );
is( $url->path, $PATH, "path is $PATH" );
is( $url->query, $QUERY, "query is $QUERY" );
is( $url->fragment, $FRAGMENT, "fragment is $FRAGMENT" );
is( $url->server, $SERVER, "server is $SERVER" );
is( $url->service, $SERVICE, "service is $SERVICE" );
is( $url->request, $REQUEST, "request is $REQUEST" );

my $params = $url->params;
ok( $params, 'got params' );
is( $params->{ animal }, 'badger', 'animal is a badger' );

my $copy = $url->copy;
ok( $copy, 'got a copy' );

$copy->params( friend => 'ferret', food => 'berries' );
is($copy, "$SERVICE?animal=badger&food=berries&friend=ferret#nose", 'new url with params' );


#------------------------------------------------------------------------
# now use same methods as mutators to change parts of the URL
#------------------------------------------------------------------------

$copy = $url->copy;
ok( $copy, 'got another copy' );

is( $copy->scheme('ftp'), 'ftp', 'set scheme to ftp' );
is( $copy, "ftp://$AUTHORITY$PATH?$QUERY#$FRAGMENT", 
    'changed scheme' );

is( $copy->user('ferret'), 'ferret', 'set user to ferret' );
is( $copy, "ftp://ferret\@$HOST:$PORT$PATH?$QUERY#$FRAGMENT", 
    'changed user' );

is( $copy->host('example.com'), 'example.com', 'set host to example.com' );
is( $copy, "ftp://ferret\@example.com:$PORT$PATH?$QUERY#$FRAGMENT", 
    'changed host' );

is( $copy->port(1234), 1234, 'set port to 1234' );
is( $copy, "ftp://ferret\@example.com:1234$PATH?$QUERY#$FRAGMENT", 
    'changed port' );

is( $copy->path('/right/here'), '/right/here', 'set path to /right/here' );
is( $copy, "ftp://ferret\@example.com:1234/right/here?$QUERY#$FRAGMENT", 
    'changed path' );

is( $copy->query('animal=ferret'), 'animal=ferret', 'set query to animal=ferret' );
is( $copy, "ftp://ferret\@example.com:1234/right/here?animal=ferret#$FRAGMENT", 
    'changed query' );

is( $copy->fragment('feet'), 'feet', 'set fragment to feet' );
is( $copy, "ftp://ferret\@example.com:1234/right/here?animal=ferret#feet", 
    'changed fragment' );


#-----------------------------------------------------------------------
# test relative URLs
#-----------------------------------------------------------------------

is( $url->relative('foo'),
    "$SERVER/over/there/foo?$QUERY#$FRAGMENT", 
    'set relative path: foo' 
);

is( $url->relative('/foo'),
    "$SERVER/foo?$QUERY#$FRAGMENT", 
    'set relative path: /foo' 
);

is( $url->absolute('bar'),
    "$SERVER/bar?$QUERY#$FRAGMENT", 
    'set absolute path: bar' 
);

is( $url->absolute('/bar'),
    "$SERVER/bar?$QUERY#$FRAGMENT", 
    'set absolute path: /bar' 
);

# original URL should not be changed
is( $url->url, $URL, 'url is unchanged' );


#-----------------------------------------------------------------------
# test constructor with separate elements
#-----------------------------------------------------------------------

$url = URL->new(
    scheme      => 'http',
    user        =>  'Mr.T',
    host        => 'badgerpower.com',
    port        => '8081',
    path        => '/somewhere/else',
    query       => 'animal=badger',
    fragment    => 'stripe',
);
ok( $url, 'created url from params' );

is( $url->authority, 'Mr.T@badgerpower.com:8081', 'got params authority' );
is( $url->server,    'http://Mr.T@badgerpower.com:8081', 'got params server' );
is( $url->service,   'http://Mr.T@badgerpower.com:8081/somewhere/else', 'got params service' );
is( $url->request,   'http://Mr.T@badgerpower.com:8081/somewhere/else?animal=badger', 'got params request' );


$url = URL->new('http://badgerpower.com/');
$url->port('8080');
$url->path('/under/ground');
$url->query('animal=badger');
is($url, 'http://badgerpower.com:8080/under/ground?animal=badger', 'new url' );

$url->params( friend => 'ferret', food => 'berries' );
is($url, 'http://badgerpower.com:8080/under/ground?animal=badger&food=berries&friend=ferret', 'new url with params' );

__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

