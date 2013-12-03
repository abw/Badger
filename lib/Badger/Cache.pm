package Badger::Cache;

use Badger::Codecs;
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    import    => 'class',
    utils     => 'resolve_uri Duration numlike',
    constants => 'SLASH',
    constant  => {
        CODEC        => 'storable',
        CODECS       => 'Badger::Codecs',
        CACHE_MODULE => 'Badger::Cache::Memory',
    };


sub init {
    my ($self, $config) = @_;
    my $class   =  $self->class;
    my $uri     =  delete $config->{ uri       } 
               ||  delete $config->{ namespace };
    my $codec   =  delete $config->{ codec     }
               ||  $class->any_var('CODEC')
               ||  $self->CODEC;
    my $module   = delete $config->{ module       }
               ||  delete $config->{ cache_module }
               ||  $class->any_var('CACHE_MODULE')
               ||  $self->CACHE_MODULE;
    my $expires  = $config->{ default_expires }
               ||= delete $config->{ expires };

    $self->debug("uri: $uri\ncodec: $codec\nmodule: $module") if DEBUG;

    class($module)->load;

    # we're lazy when it comes to long option names
    $config->{ default_expires } ||= $config->{ expires }
        if $config->{ expires };

    if ($expires) {
        $self->{ expires } = Duration($expires)->seconds;
    }

    $self->{ uri   } = $uri;
    $self->{ codec } = $self->CODECS->codec($codec);
    $self->{ cache } = $module->new($config);

    $self->debug("created new $module cache backend: $self->{ cache }") if DEBUG;

    return $self;
}


sub get {
    my ($self, $urn) = @_;
    my $uri  = $self->uri($urn);
    my $text = $self->{ cache }->get($uri) || return;
    return $self->{ codec }->decode($text);
}


sub set {
    my ($self, $urn, $data, $expires) = @_;
    my $uri  = $self->uri($urn);
    my $text = $self->{ codec }->encode($data);
    if ($expires) {
        $expires = Duration($expires)->seconds
            unless numlike $expires;
        $self->debug("expires in $expires seconds") if DEBUG;
    }
    else {
        $expires = $self->{ expires };
    }
    return $self->{ cache }->set($uri, $text, $expires);
}


sub uri {
    my $self = shift;
    my $path = resolve_uri(SLASH, @_);
    my $base = $self->{ uri } || return $path;
    return sprintf("%s:/%s", $base, $path);
}


1;

__END__

=head1 NAME

Badger::Cache - wrapper around Cache::* modules with data encoding

=head1 SYNOPSIS

    use Badger::Cache;
    
    my $cache = Badger::Cache->new(
        # options for Badger::Cache
        uri    => 'my:namespace',
        codec  => 'json',
        module => 'Cache::Memcached',

        # any other options for back-end cache module
        servers => [ ... ],
    );

    $cache->set(
        complex_data => {
            foo => 'bar',
            baz => [10, 20, 30],
        }
    );

    my $complex = $cache->get('complex_data');

=head1 DESCRIPTION

This module provides a simple wrapper around a C<Cache::*> compatible 
cache module.  

It uses L<Badger::Codecs> to automatically encode and decode data using a 
codec of your choice.  This allows data to be encoded using an open format
(e.g. JSON) that can be shared across servers using different programming
languages or versions of Perl.  The L<Storable> module which is hard-coded
into the L<Cache::Entry> module's C<freeze()> and C<thaw()> methods is not
suitable for either of these purposes.

It also reinstates the equivalent of the 'namespace' concept (originally in 
L<Cache::Cache> but removed in the more recent L<Cache> interface) via the 
L<uri> option.  This allows you to have multiple C<Badger::Cache> objects
caching different sets of data via the same back-end cache (e.g. a 
L<Cache::Memcached> instance).

NOTE: this module is a work in progress and is currently lacking adequate
documentation and testing.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2001-2013 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
