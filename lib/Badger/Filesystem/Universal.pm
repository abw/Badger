#========================================================================
#
# Badger::Filesystem::Universal
#
# DESCRIPTION
#   Subclass of Badger::Filesystem which implements a universal 
#   filesystem for representing URIs.  It always uses forward slashes 
#   as path separators regardless of the local filesystem convention.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Filesystem::Universal;

use Badger::Debug ':dump';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Filesystem',
    constants => 'HASH',
    constant  => {
        UFS          => __PACKAGE__,
        ROOTDIR      => '/',
        CURDIR       => '.',
        UPDIR        => '..',
        FILESPEC     => 'Badger::Filesystem::FileSpec::Universal',
        spec         => 'Badger::Filesystem::FileSpec::Universal',
    },
    exports   => {
        any   => 'UFS',
    };


#-----------------------------------------------------------------------
# Replacement for File::Spec implementing that various methods that the
# filesystem needs to construct paths.
#-----------------------------------------------------------------------

package Badger::Filesystem::FileSpec::Universal;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    constant  => {
        SLASH   => '/',
        SLASHRX => qr{/},
        COLON   => ':',
        rootdir => '/',
        curdir  => '.',
        updir   => '..',
    };


sub catdir {
    my $self = shift;
    join(SLASH, @_);
}

sub catpath {
    my ($self, $volume, $dir, $file) = @_;
    my $path = '';

    # yuk
    $volume = undef unless defined $volume and length $volume;
    $dir    = undef unless defined $dir    and length $dir;
    $file   = undef unless defined $file   and length $file;
    
    $path .= $volume.COLON if defined $volume;
    $path .= SLASH         if defined $volume and defined $dir;
    $path .= $dir.SLASH    if defined $dir;
    $path .= $file         if defined $file;
    $self->debug("catpath() [$volume] [$dir] [$file] => [$path]") if $DEBUG;
    return $path;
}

sub splitpath {
    my ($self, $path) = @_;
    my ($volume, $dir, $file);
    $dir    = $path;
    $volume = $1 if $dir =~ s/^(\w+)://;
    $file   = $1 if $dir =~ s/([^\/]+)$//;
    $dir    =~ s{(?<=.)/$}{};
    $dir    =~ s{//}{/}g;
    $self->debug("splitpath() [$path] => [$volume] [$dir] [$file]") if $DEBUG;
    return ($volume, $dir, $file);
}

sub splitdir {
    my ($self, $dir) = @_;
    $self->debug("splitdir($dir) => [", join('] [', split(SLASHRX, $dir)), ']') if $DEBUG;
    return split(SLASHRX, $dir);
}

sub file_name_is_absolute {
    my ($self, $path) = @_;
    $self->debug("testing $path");
    return $path =~ m{^/};
}

sub canonpath {
    my $self = shift;
    my ($volume, $dir, $name) = $self->splitpath(@_);
    my @dirs = $self->splitdir($dir); 
    my ($node, @path);
    while (@dirs) {
        $node = shift @dirs;
        if ($node eq curdir) {
            # do nothing
        }
        elsif ($node eq updir) {
            pop @path if @path;
        }
        else {
            push(@path, $node);
        }
    }
    return $self->catpath(
        $volume,
        $self->catdir(@path),
        $name
    );
}

sub abs2rel {
    shift->todo;
}

sub no_upwards {
    shift->todo;
}

1;

