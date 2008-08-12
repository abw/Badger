#========================================================================
#
# Badger::Filesystem::Visitor
#
# DESCRIPTION
#   Base class visitor object for traversing a filesystem.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Filesystem::Visitor;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    constants => 'ARRAY',
    utils     => 'params',
    messages  => {
        no_node => 'No node specified to %s'
    };

sub init {
    my ($self, $config) = @_;

    for (qw( all recurse )) {
        $self->{ $_ } = $config->{ $_} || 0;
    }

    # allow 'directories' as alias for 'dirs'
    $self->{ dirs } = $self->{ directories }
        if exists $self->{ directories };
    
    # tread carefully because a value in $config is likely to be false
    for (qw( files dirs )) {
        $self->{ $_ } = defined $config->{ $_} 
            ? $config->{ $_ }
            : 1;
    }
        
    # TODO: accept, ignore, handlers

    return $self;
}

sub visit {
    my $self = shift;
    my $node = shift || return $self->error_msg( no_node => 'visit' );
    $self->prepare(@_);
    $node->accept($self);
    $self->cleanup;
}

sub prepare {
    my ($self, $config) = @_;
    $self->{ config   } = $config;
    $self->{ collect  } = [ ];
    $self->{ identify } = { };
}

sub cleanup {
}

sub visit_path {
    my ($self, $path) = @_;
    $self->debug("visiting path: $path\n") if $DEBUG;
}

sub visit_file {
    my ($self, $file) = @_;
    return unless $self->{ files };
    $self->debug("visiting file: $file\n") if $DEBUG;
    $self->collect($file);
}

sub visit_directory {
    my ($self, $dir) = @_;
    return unless $self->{ dirs };
    $self->debug("visiting directory: $dir\n") if $DEBUG;
    $self->collect($dir);
    $self->visit_directory_children($dir)
        if $self->{ recurse };
}

sub visit_directory_children {
    my ($self, $dir) = @_;
    $self->debug("visiting directory children: $dir\n") if $DEBUG;
    map { $_->accept($self) }
    $dir->children($self->{ all });
}

sub collect {
    my $self    = shift;
    my $collect = $self->{ collect };
    push(@$collect, @_) if @_;
    return wantarray
        ? @$collect
        :  $collect;
}

sub identify {
    my ($self, $params) = self_params(@_);
    my $identify = $self->{ identify };
    @$identify{ keys %$params } = values %$params
        if %$params;
    return wantarray
        ? %$identify
        :  $identify;
}

1;

__END__

=head1 NAME

Badger::Filesystem::Visitor - visitor for traversing filesystems

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

The L<Badger::Filesystem::Visitor> module implements a visitor object which 
can be used to traverse filesystems.

=head1 METHODS

TODO

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2005-2008 Andy Wardley. All rights reserved.

=head1 SEE ALSO

L<Badger::Filesystem>

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
# TextMate: rocks my world
