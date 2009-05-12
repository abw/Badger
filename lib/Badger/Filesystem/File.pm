#========================================================================
#
# Badger::Filesystem::File
#
# DESCRIPTION
#   OO representation of a file in a filesystem.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Filesystem::File;

use Badger::Class
    version     => 0.01,
    base        => 'Badger::Filesystem::Path',
    debug       => 0,
    dumps       => 'path volume directory name stats',
    import      => 'class',
    constants   => 'ARRAY BLANK',
    constant    => {
        type    => 'File',
        is_file => 1,
    };

use Badger::Filesystem::Path ':fields';

*base = \&directory;
*copy = \&copy_to;
*move = \&move_to;

sub init {
    my ($self, $config) = @_;
    my ($path, $vol, $dir, $name);
    my $fs = $self->filesystem;

    if ($config->{ path }) {
        $path = $self->{ path } = $fs->join_dir($config->{ path });
        @$self{@VDN_FIELDS} = $fs->split_path($path);
    }
    elsif ($self->{ name } = $config->{ name }) {
        @$self{@VD_FIELDS} = ($vol, $dir) = map { defined($_) ? $_ : '' } @$config{@VD_FIELDS};
        $self->{ path } = $fs->join_path($vol, $dir, $self->{ name });
    }
    else {
        $self->error_msg( missing => 'path or name' );
    }
    
    my $opts = $self->{ options } = { };
    $self->encoding( $config->{ encoding } )
        if $config->{ encoding };
        
    return $self;
}

sub directory {
    my $self = shift;
    return @_
        ? $self->filesystem->directory( $self->relative(@_) )
        : $self->parent;
}

sub file {
    my $self = shift;
    return @_
        ? $self->filesystem->file( $self->relative(@_) )
        : $self;
}

sub exists {
    my $self = shift;
    # cache the stats returned in case we want them later
    return ($self->{ stats } = $self->filesystem->file_exists($self->{ path }));
}

sub create {
    my $self = shift;
    $self->filesystem->create_file($self->{ path }, @_);
}

sub touch {
    my $self = shift;
    $self->filesystem->touch_file($self->{ path });
}

sub open {
    my $self = shift;
    $self->filesystem->open_file($self->{ path }, @_, $self->{ options });
}

sub read {
    my $self = shift;
    $self->filesystem->read_file($self->{ path }, @_, $self->{ options });
}

sub write {
    my $self = shift;
    $self->filesystem->write_file($self->{ path }, @_, $self->{ options });
}

sub copy_to {
    my $self = shift;
    $self->filesystem->copy_file($self->{ path }, @_);
}

sub copy_from {
    my $self = shift;
    $self->filesystem->copy_file(shift, $self->{ path }, @_);
}

sub move_to {
    my $self = shift;
    $self->filesystem->move_file($self->{ path }, @_);
}

sub move_from {
    my $self = shift;
    $self->filesystem->move_file(shift, $self->{ path }, @_);
}

sub chmod {
    my $self = shift;
    $self->filesystem->chmod_path($self->{ path }, @_);
    return $self;
}

sub print {
    my $self = shift;
    $self->write( join(BLANK, @_) );
}

sub append {
    my $self = shift;
    $self->filesystem->append_file($self->{ path }, @_, $self->{ options });
}

sub delete {
    my $self = shift;
    $self->filesystem->delete_file($self->{ path }, @_);
}

sub text {
    my $self = shift;
    my $text = $self->read(@_, $self->{ options });
    # TODO: bless?
    return $text;
}

sub accept {
    $_[1]->visit_file($_[0]);
}

sub encoding {
    my $self = shift;
    if (@_) {
        my $layer = shift;
        # be generous in what you accept...
        $layer = ":$layer" unless $layer =~ /^:/;
        $self->{ options }->{ encoding } = $layer;
    }
    return $self->{ options }->{ encoding };
}

class->methods(
    map {
        my $item = $_;              # lexical copy for closure
        $item => sub {
            my $self = shift;
            # ...and strict in what you provide
            $self->encoding(':' . $item); 
            return $self;
        }
    }
    qw( raw utf8 crlf bytes )
);


1;

__END__

=head1 NAME

Badger::Filesystem::File - file object

=head1 SYNOPSIS

    # using Badger::Filesytem constructor subroutine
    use Badger::Filesystem 'File';
    
    # use native OS-specific paths:
    $file = File('/path/to/file');
    
    # or generic OS-independent paths
    $file = File('path', 'to', 'file');

    # manual object construction
    use Badger::Filesystem::File;
    
    # positional arguments
    $file = Badger::Filesystem::File->new('/path/to/file');
    $file = Badger::Filesystem::File->new(['path', 'to', 'file']);
    
    # named parameters
    $file = Badger::Filesystem::File->new(
        path => '/path/to/file'             # native
    );
    $file = Badger::Filesystem::File->new(
        path => ['path', 'to', 'file']      # portable
    );
    
    # path inspection methods
    $file->path;                    # full path
    $file->name;                    # file name
    $file->directory;               # parent directory
    $file->dir;                     # alias to directory()
    $file->base;                    # same thing as directory()
    $file->volume;                  # path volume (e.g. C:)
    $file->is_absolute;             # path is absolute
    $file->is_relative;             # path is relative
    $file->exists;                  # returns true/false
    $file->must_exist;              # throws error if not
    @stats = $file->stat;           # returns list
    $stats = $file->stat;           # returns list ref

    # path translation methods
    $file->relative;                # relative to cwd
    $file->relative($base);         # relative to $base
    $file->absolute;                # relative to filesystem root
    $file->definitive;              # physical file location
    $file->collapse;                # resolve '.' and '..' in $file path
    
    # path comparison methods
    $file->above($another_path);    # $file is ancestor of $another_path
    $file->below($another_path);    # $file is descendant of $another_path
    
    # file manipulation methods
    $file->create;                  # create file
    $file->touch;                   # create file or update timestamp
    $file->delete;                  # delete file
    $fh = $file->open($mode);       # open file (for read by default)
    $fh = $file->write;             # open for write
    $fh = $file->append;            # open for append;
    
    # all-in-one read/write methods
    @data = $file->read;            # return list of lines
    $data = $file->read;            # slurp whole content
    $text = $file->text;            # same as read();
    $file->write(@content);         # write @content to file
    $file->append(@content);        # append @content to file

=head1 DESCRIPTION

The C<Badger::Filesystem::File> module is a subclass of
L<Badger::Filesystem::Path> for representing files in a file system.

You can create a file object C<File> constructor function in
L<Badger::Filesystem>.

    use Badger::Filesystem 'File';

File paths can be specified as a single string using your native filesystem
format or as a list or reference to a list of items in the path for
platform-independent paths.

    my $file = File('/path/to/file');

If you're concerned about portability to other operating systems and/or file
systems, then you can specify the file path as a list or reference to a list
of component names.

    my $file = File('path', 'to', 'file');
    my $file = File(['path', 'to', 'file']);

You can specify a reference to a hash array of additional configuration items
as the final argument.  At present, there is only one configuration option,
C<encoding>, which you can use to specify the encoding of the file.

    my $file = File('path' , 'to', 'file', { encoding => 'utf8' });

=head1 METHODS

In addition to the methods inherited from L<Badger::Filesystem::Path>, the
following methods are defined or re-defined.

=head2 init(\%config)

Customised initialisation method specific to files.  

=head2 volume() / vol()

Returns any volume defined as part of the path.  This is most commonly used
on MS Windows platforms to indicate drive letters, e.g. C<C:>.

=head2 directory() / dir() / base()

Returns the directory portion of the file path.  This can also be used with
an argument to locate another directory relative to this file.

    my $file = File('/path/to/file');
    print $file->dir;                   # /path/to
    print $file->dir('subdir');         # /path/to/subdir

=head2 name()

Returns the file name portion of the path.

=head2 file()

When called without arguments, this method simply returns the file object
itself.  It can also be called with an argument to locate another file 
relative to the directory in which the current file is located.

    my $file = File('/path/to/file1');
    print $file->file;                   # /path/to/file1
    print $file->file('file2');          # /path/to/file2

=head2 exists

Returns true if the file exists in the filesystem.  Returns false if the 
file does not exists or if it is not a file (e.g. a directory).

=head2 is_file()

This method returns true for all C<Badger::Filesystem::File> instances.

=head2 create()

This method can be used to create the file if it doesn't already exist.

=head2 touch()

This method can be used to create the file if it doesn't already exist
or update the timestamp if it does.

=head2 open($mode,$perms)

This method opens the file and returns an L<IO::File> handle to it. The
default is to open the file for read-only access. The optional arguments
can be used to specify a different mode and default permissions for the 
file (these arguments are forwarded to L<IO::File>).

    my $fh = $file->open;       # read
    my $fh = $file->open('w');  # write

=head2 read()

This method read the content of the file.  It is returned as a single
string in scalar context and a list of each line in list context.

    my $text  = $file->read;
    my @lines = $file->read;

=head2 write(@content)

When called without arguments this method opens the file for writing and
returns an L<IO::File> handle.

    my $fh = $file->write;
    $fh->print("Hello World!\n");
    $fh->close;

When called with arguments, the method opens the file, writes the argument to
it, and then closes the file again.

    $file->write("Hello World!\n");

=head2 copy($to, %params) / copy_to($to, %params)

This method copies the file to the new location specified by the first
argument. It delegates to the L<copy_file()|Badger::Filesystem/copy_file()>
method in L<Badger::Filesystem>.

    $file->copy('/some/where/else');

The destination can be specified as a file name, file object or file handle.
An optional list of reference to a hash array of named parameters can follow.

    $file->copy(
        '/some/where/else' => {
            mkdir     => 1,         # create intermediate directories
            dir_mode  => 0775,      # permissions for created directories
            file_mode => 0664,      # permissions for created file
        }
    );

=head2 copy_from($from, %params)

Like L<copy_to()> but working in reverse. 

    $target_file->copy_from( $source_file );

=head2 move($to, %params) / move_to($to, %params)

This method moves the file to the new location specified by the first
argument.  It delegates to the L<copy_file()|Badger::Filesystem/move_file()>
method in L<Badger::Filesystem>.

    $file->move('/some/where/else');

Arguments are as per L<copy()>.

=head2 move_from($from, %params)

Like L<move_to()> but working in reverse. 

    $target_file->move_from( $source_file );

=head2 chmod($perms)

This method changes the file permissions on a file.

    $file->chmod(0775);

=head2 print(@content)

This method concatentates all arguments into a single string which it then
forwards to the L<write()> method.  This effectively forces the L<write()>
method to always write something to the file, even if it's an empty string.

    $file->print("hello");      
    $file->print(@stuff);       # works OK if @stuff is empty 

=head2 append(@content)

This method is similar to L<write()>, but opens the file for appending (when 
called with no arguments), or appends any arguments to the end of the file.

    # manual open, append, close
    my $fh = $file->append;
    $fh->print("Hello World!\n");
    $fh->close;
    
    # all-in-one
    $file->append("Hello World\n");

=head2 delete()

This method deletes the file permanently.  Use it wisely.

=head2 text()

This method is a wrapper around the L<read()> method which forces scalar
context.  The content of the file is always returned as a single string.
NOTE: future versions will probably return this as a text object.

=head2 accept($visitor)

This method is called to dispatch a visitor to the correct method for a
filesystem object.  In the L<Badger::Filesystem::File> class, it calls the 
visitor L<visit_file()|Badger::Filesystem::Visitor/visit_file()> method,
passing the C<$self> object reference as an argument.

=head2 encoding($enc)

This method can be used to get or set the encoding for the file.

    $file->encoding(':utf8');

The encoding will affect all operations that read data from, or write data
to the file.

=head2 utf()

A method of convenience to set the file's encoding to UTF-8.  

    $file->utf8;

It has the same affect as calling the L<encoding()> method with an argument
of C<:utf8>.  See C<perldoc -f binmode> for further information.

    # same
    $file->encoding(':utf8');


The method returns the file object itself, so can be used in a chain.

    $file->utf8->must_exist.

=head2 bytes()

Like C<utf8()>, this is a method of convenience to set the file encoding 
to C<:bytes>.

=head2 crlf()

Like C<utf8()>, this is a method of convenience to set the file encoding 
to C<:crlf>.

=head2 raw()

Like C<utf8()>, this is a method of convenience to set the file encoding 
to C<:raw>.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2005-2009 Andy Wardley. All rights reserved.

=head1 ACKNOWLEDGEMENTS

The C<Badger::Filesystem> modules are built around a number of existing
Perl modules, including L<File::Spec>, L<File::Path>, L<Cwd>, L<IO::File>,
L<IO::Dir> and draw heavily on ideas in L<Path::Class>.

Please see the L<ACKNOWLEDGEMENTS|Badger::Filesystem/ACKNOWLEDGEMENTS>
in L<Badger::Filesystem> for further information.

=head1 SEE ALSO

L<Badger::Filesystem>, 
L<Badger::Filesystem::Path>,
L<Badger::Filesystem::Directory>,
L<Badger::Filesystem::Visitor>.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
# TextMate: doesn't need this cruft
