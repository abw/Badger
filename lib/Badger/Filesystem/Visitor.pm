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
    constants => 'ARRAY CODE REGEX',
    utils     => 'params',
    messages  => {
        no_node    => 'No node specified to %s',
        bad_filter => 'Invalid reference to %s %s: %s',
    };

sub init {
    my ($self, $config) = @_;

    # allow 'directories' as alias for 'dirs'
    $self->{ dirs } = $self->{ directories }
        if exists $self->{ directories };
    $self->{ no_dirs } = $self->{ no_directories }
        if exists $self->{ no_directories };
    $self->{ not_in_dirs } = $self->{ not_in_directories }
        if exists $self->{ not_in_directories };
    
    for (qw( all recurse no_files no_dirs not_in_dirs )) {
        $self->{ $_ } = $config->{ $_ } || 0;
    }

    # tread carefully because a value in $config is likely to be false
    for (qw( files dirs in_dirs )) {
        $self->{ $_ } = defined $config->{ $_} 
            ? $config->{ $_ }
            : 1;
    }

    $self->{ collect  } = [ ];
    $self->{ identify } = { };
        
    # TODO: accept, ignore, handlers

    return $self;
}

sub visit {
    my $self = shift;
    my $node = shift || return $self->error_msg( no_node => 'visit' );
    $node->accept($self);
}

sub visit_path {
    my ($self, $path) = @_;
    $self->debug("visiting path: $path\n") if $DEBUG;
}

sub visit_file {
    my ($self, $file) = @_;
    $self->debug("visiting file: $file\n") if $DEBUG;

    $self->collect($file) 
        if $self->accept_file($file);
}

sub visit_directory {
    my ($self, $dir) = @_;
    $self->debug("visiting directory: $dir\n") if $DEBUG;

    $self->collect($dir) 
        if $self->accept_directory($dir);

    $self->visit_directory_children($dir)
        if $self->enter_directory($dir);
}

sub visit_directory_children {
    my ($self, $dir) = @_;
    $self->debug("visiting directory children: $dir\n") if $DEBUG;
    map { $_->accept($self) }
    $dir->children($self->{ all });
}

sub filter {
    my ($self, $type, $name, $method, $item) = @_;
    my $tests = $self->{ $name } || return 0;

    $self->debug("filter($type, $name, $method, $item)  tests: $tests\n") if $DEBUG;
    
    if ($tests eq '1') {
        return 1;
    }
    else {
        $tests = [$tests]
            unless ref $tests eq ARRAY;
    }
    foreach my $test (@$tests) {
        $self->debug("  - test: $test\n") if $DEBUG;
        if (ref $test eq CODE) {
            return 1 if $test->($item, $self);
        }
        elsif (ref $test eq REGEX) {
            return 1 if $item->$method =~ $test;
        }
        elsif (ref $test) {
            return $self->error_msg( bad_filter => $type => $name => $test );
        }
        else {
            # TODO: handle wildcards, e.g. *.html, foo.* either here or
            # by pre-constructing regexen.  For now we just match
            return 1 if $item->$method eq $test;
        }
    }
    return 0;
}

sub accept_file {
    my $self = shift;
    return $self->filter( accept => files    => name => @_ )
      && ! $self->filter( reject => no_files => name => @_ );
}

sub accept_directory {
    my $self = shift;
    return $self->filter( accept => dirs    => name => @_ )
      && ! $self->filter( reject => no_dirs => name => @_ );
}

sub enter_directory {
    my $self = shift;
    return $self->filter( accept => in_dirs     => name => @_ )
      && ! $self->filter( reject => not_in_dirs => name => @_ );
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
