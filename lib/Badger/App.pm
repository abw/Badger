package Badger::App;

use Badger::Config::Schema;
use Badger::Reporter::App;
use Badger::Debug ':dump debugf';
use Badger::Apps;
use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Prototype',
    import      => 'class CLASS',
    utils       => 'wrap',
    accessors   => 'name author date version',
    constants   => 'DELIMITER ARRAY',
    constant    => {
        SCHEMA   => 'Badger::Config::Schema',
        APPS     => 'Badger::Apps',
        REPORTER => 'Badger::Reporter::App',
    },
    alias       => {
        init    => \&init_app,
    },
    config      => [
        'base|class:CLASS',
        'name|class:NAME|method:CLASS',
        'author|class:AUTHOR',
        'version|class:VERSION',
        'date|class:DATE',
        'about|class:ABOUT',
        'usage|class:USAGE',
        'actions|class:ACTIONS',
#        'apps|class:APPS',
#        'app_path|class:APP_PATH|method:CLASS',
    ],
    messages => {
        missing_arg => "No value specified for %s",
    };


sub init_app {
    my ($self, $config) = @_;

    $self->debugf(
        "init_app(%s)", 
        $self->dump_data($config),
    ) if DEBUG;

    $self->configure($config)
         ->init_options($config);

    # shared context
    $self->{ app    } = $config->{ app    } || { };
    $self->{ parent } = $config->{ parent };
    $self->{ config } = $config;

#    $self->{ app }->{ $self } = 'Hello World';
#    $self->debug("app: ", $self->dump_data($self->{ app }));
#    my $apps = $self->{ app }->{ apps } ||= [ ];
#    push(@$apps, $self);
    
    return $self;
}


sub init_options {
    my ($self, $config) = @_;
    my $options = $self->class->list_vars( OPTIONS => $config->{ options } );
    $self->{ schema } = $self->SCHEMA->new( schema => $options );
    $self->debug("created schema: ", $self->{ schema }) if DEBUG;
    return $self;
}


sub args {
    my $self    = shift->prototype;
    my $args    = @_ == 1 && ref $_[0] eq ARRAY ? shift : [ @_ ];
    my $options = $self->{ app }->{ options } ||= { };
    my ($arg, $option, $app);
    
    $self->debug("args(", $self->dump_data_inline($args), ")") if DEBUG;

    my $schema = $self->{ schema };
    $self->debug("using schema: $schema") if DEBUG;
    
    while (@$args) {
        $arg = $args->[0];
        $self->debug("option: $arg") if DEBUG;
        
        if ($option = $schema->item($arg)) {
            $self->debug("got schema option: $option") if DEBUG;
        }
        elsif ($arg =~ /^--(.*)/) {
            $self->debug("looking for option: $1") if DEBUG;
            # TODO: look up app stack
            $option = $schema->item($1)
                || return $self->error_msg( invalid => argument => $arg );
        }
        elsif ($arg =~ /^[\w\.]+$/ && ($app = $self->app($arg))) {
            shift @$args;
            return $app->new( 
                parent => $self,
                app    => $self->{ app } 
            )->args($args);
        }
        else {
            $self->debug("not found: $arg") if DEBUG;
            return $self->error_msg( invalid => argument => $arg );
        }

        shift @$args;
        $option->args($args, $self->{ app }, $self);
    }

    return $self;
#    $self->debug("options schema for this app is: ", $schema);
#    $self->not_implemented('in base class');
}


sub validate {
    my $self   = shift->prototype;
    my $app    = $self->{ app };
    my $schema = $self->{ schema };
    my ($item, $name);
    
    foreach $item ($schema->items) {
        next unless $item->{ required };
        $name = $item->{ name };
        return $self->error_msg( missing_arg => $name )
            unless defined $app->{ $name };
    }

    return $app;
}


sub app {
    shift->apps->app(@_);
}


sub apps {
    my $self = shift;

    return $self->{ apps } ||= do {
        my $class = $self->class;
        my $apps  = $class->hash_vars( 
            APPS => $self->{ config }->{ apps } 
        );
        my $path  = $class->list_vars( 
            APP_PATH => $self->{ config }->{ app_path }
        );
        push(@$path, $self->class->name) unless @$path;
        $self->debug(
            "creating app factory with path: ", $self->dump_data_inline($path),
            "and apps: ", $self->dump_data_inline($apps)
        ) if DEBUG;
        $self->APPS->new(
            path => $path,
            apps => $apps,
        );
    };
}


sub run {
    my $self = shift;
    $self->validate;
    $self->not_implemented('in base class');
}


#-----------------------------------------------------------------------
# output generation
#-----------------------------------------------------------------------

sub reporter {
    my $self   = shift->prototype;
    my $config = @_ ? params(@_) : $self->{ app };
    return $self->{ reporter }
       ||= class($self->REPORTER)->load->instance($config);
}


sub help {
    my $self = shift->prototype;
    $self->credits;
    $self->about;
    $self->usage;
    $self->options;
    exit;
}


sub credits {
    my $self = shift;
    $self->reporter->credits(
        $self->name, 
        $self->version, 
        $self->author, 
        $self->date,
    );
}


sub options {
    my $self     = shift->prototype;
    my $reporter = $self->reporter;
    $reporter->section('Options');

    foreach my $item ($self->{ schema }->items) {
        $item->summary($reporter);
    }
    return;

    my $options  = join(
        "\n  ", 
        grep { defined && length }
        map  { $_->summary } 
        $self->{ schema }->items
    ) || return '';
    
    $reporter->about($options);
}


sub blurb {
    my ($self, $type, $title) = @_;
    my $reporter = $self->reporter;
    my $blurb    = $self->{ $type }
        || $self->{ config }->{ $type } 
        || $self->class->any_var( uc $type )
        || return '';
    $blurb = wrap($blurb, 76, 2);
    $title ||= ucfirst $type;
  
    $reporter->section($title);
    $reporter->about($blurb);
}


sub about {
    shift->blurb('about');
}


sub usage {
    shift->blurb('usage');
}


1;



=head1 NAME

Badger::App - base class application module

=head1 DESCRIPTION

This module implements a base class for simple, self-contained applications.

=head1 METHODS

The following methods are defined in addition to those inherited from the 
L<Badger::Prototype> and L<Badger::Base> base classes.

=head2 about()

This method should be re-defined in subclasses to return information about
the application.

=head2 usage()

This method should be re-defined in subclasses to return a summary of usage
options for the application.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008-2012 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Factory>,
L<Badger::Base>.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

