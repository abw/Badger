#========================================================================
#
# Badger::Filesystem::Virtual
#
# DESCRIPTION
#   Subclass of Badger::Filesystem which implements a virtual filesystem
#   composed from several source directories, conceptually layered on
#   top of each other.  
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Filesystem::Virtual;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Filesystem',
    constants => 'ARRAY',
    constant  => {
        VFS     => __PACKAGE__,
        virtual => __PACKAGE__,
    },
    exports   => {
        any   => 'VFS',
    };

*definitive = \&definitive_write;


sub init {
    my ($self, $config) = @_;

    # let the base class have a go first, so it can set rootdir et al
    $self->SUPER::init($config);

    # root can be a single item or list ref
    my $root = $config->{ root } || $self->{ rootdir };
    $root = [$root] unless ref $root eq ARRAY;
    $self->{ root } = $root;
    
    # we must set cwd to / so that the relative -> absolute path translation
    # works as expected.  The concept of having a current working directory 
    # in a VFS is just a bit too weird to contemplate anyway.
    $self->{ cwd } = $self->{ rootdir };
    
    $self->debug("Virtual root: ", join(', ', @$root), "\n" ) if $DEBUG;
    
    return $self;
}

sub definitive_write {
    my $self = shift;
    my $path = $self->absolute(@_);
    return $self->join_directory($self->{ root }->[0], $path);
}

sub definitive_read {
    my $self = shift;
    my $path = $self->absolute(@_);
    my ($base, $full);

    foreach $base (@{ $self->{ root } }) {
        $full = $self->join_directory($base, $path);
        $self->debug("looking for $full\n") if $DEBUG;
        return $full if -e $full;
    }
}

sub read_directory {
    my $self = shift;
    my $path = $self->absolute(shift);
    my $all  = shift;
    my $root = $self->{ root };
    my ($base, $full, $dirh, $item, @items, %seen);

    require IO::Dir;

    foreach $base (@{ $self->{ root } }) {
        $full = $self->join_directory($base, $path);
        $self->debug("Opening directory: $full\n") if $DEBUG;
        $dirh = IO::Dir->new($full)
            || $self->error_msg( open_failed => directory => $full => $! );
        while (defined ($item = $dirh->read)) {
            push(@items, $item) unless $seen{ $item }++;
        }
        $dirh->close;
    }
    @items = $self->FILESPEC->no_upwards(@items)
        unless $all || ref $self && $self->{ all_entries };

    return wantarray ? @items : \@items;
}


1;

__END__

=head1 NAME

Badger::Filesystem::Virtual - virtual filesystem

=head1 SYNOPSIS

    use Badger::Filesystem::Virtual;
    
    my $fs = Badger::Filesystem::Virtual->new(
        root => ['/path/to/dir/one', '/path/to/dir/two'],
    );
    my $file = $fs->file('/example/file');
    my $dir  = $fs->dir('/example/directory');
    
    if ($file->exists) {        # under either root directory
        print $file->text;      # loaded from correct location
    }
    else {                      # writes under first directory
        $file->write("hello world!\n");
    }

=head1 INTRODUCTION

This module defines a subclass of L<Badger::Filesystem> for creating virtual
filesystems that are "mounted" onto one or more underlying source directories
in a real file system. If you don't already know what that means then the
chances are that you don't need to read this documentation. Either way you
should read the documentation for L<Badger::Filesystem> first.

=head1 DESCRIPTION

The L<Badger::Filesystem> module gives you access to the files and directories
in a I<real> filesystem. The C<Badger::Filesystem::Virtual> module is a
specialised subclass of that which allows you to create a I<virtual>
filesystem composed from the files and directories in a number of different
I<real> directories.

=head1 METHODS

L<Badger::Filesystem::Virtual> inherits all the methods of
L<Badger::Filesystem>.  The following methods are added or amended.

=head2 init(\%config)

This custom initialisation method allows one or more C<root> (or C<rootdir>)
directories to be specified as the base of the virtual filesystem.

=head2 definitive_write($path)

Maps a virtual file path to a definitive one for write operations.  The 
path will be mapped to the first virtual root directory.

=head2 definitive_read($path)

Maps a virtual file path to a definitive one for read operations.  The 
path will be mapped to the first virtual root directory in which the 
item exists.  If it does not exists in any of the virtual root directories
then an undefined value is returned.

=head2 read_directory($path)

Custom method to read a directory in a virtual filesystem.  This returns
a composite index of all entries in a particular directory across all 
roots of the virtual filesystem.

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
