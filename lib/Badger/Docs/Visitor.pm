#========================================================================
#
# Badger::Docs::Visitor
#
# DESCRIPTION
#   Subclass of Badger::Filesystem::Visitor for trawling a filesystem 
#   for documentation.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Docs::Visitor;

use Badger::Class
    version     => 0.01,
    debug       => 1,
    base        => 'Badger::Filesystem::Visitor',
    constants   => 'ARRAY DELIMITER PKG',
    get_methods => 'index pages modules sections content',
    filesystem  => 'VFS',
    constant    => {
        DOT     => '.',
        SLASH   => '/',
        HTML    => 'html',
    };

use Badger::Debug ':dump';

# these are picked up by visitor base class via the class->any_var() method
our $FILES       = ['*.pm', '*.pod'];
our $NO_DIRS     = ['.svn', '.DS_Store'];
#our $NOT_IN_DIRS = $NO_DIRS;

# these are new defaults for this class.
our $URI_ROOT    = SLASH;
our $URI_BASE    = SLASH;
our $URI_EXT     = HTML;

sub init {
    my ($self, $config) = @_;
    my $class = $self->class;
    
    $self->SUPER::init($config);
    
    foreach (qw( uri_root uri_base uri_ext )) {
        $self->{ $_ } = $config->{ $_ } || $class->any_var(uc $_);
    }

    $self->{ uri_vfs  } = VFS->new( root => $self->{ uri_root } );
    $self->{ uri_dir  } = $self->{ uri_vfs }->dir( $self->{ uri_base } );
    $self->{ verbose  } = $config->{ verbose } || 0;
    $self->{ depth    } = 0;
    $self->{ index    } = { };
    $self->{ pages    } = { };
    $self->{ modules  } = { };
    $self->{ sections } = { };
    $self->{ content  } = [ ];
    $self->{ section  } = {
        content => $self->{ content },
#        uri     => $self->{ uri_base },
#        dir     => $self->{ uri_dir  },
    };

#    $self->{ sections } = { };


    return $self;
}

sub trace {
    my $self = shift;
    print STDERR '  ' x $self->{ depth }, @_, "\n";
}

sub visit_file {
    my ($self, $file) = @_;
    return unless $self->accept_file($file);
    my ($page, $path, $pkg, $uri, @bits);

    $self->trace("- $file") if $self->{ verbose };

    # remove the .pm or .pod extension, split into sections and remove
    # empty root dir(s) from front
    $path =  $file->path;
    $path =~ s/\.\w+$//;
    @bits =  $file->filesystem->split_dir($path);
    shift @bits while @bits && ! length $bits[0];

    # re-join with '::' to get module name, e.g. Badger::Example, wo we can
    # add a reference from module name to the page so we can later match up 
    # L<Badger::Example> links in the POD to the right page.
    $pkg  =  join(PKG,  @bits);
    
    # build the page URI by joining with '/' and adding any extension, then
    # resolve it relative to the URI base dir in the URI virtual filesysystem.
    $uri  =  join(DOT, join(SLASH, @bits), $self->{ uri_ext });
    $uri  =  $self->{ uri_dir }->file($uri);
    
    $page = {
        uri    => $uri,
        file   => $file,
        module => $pkg,
    };
    
    $self->{ index   }->{ $uri } = $page;
    $self->{ pages   }->{ $uri } = $page;
    $self->{ modules }->{ $pkg } = $page;
    
#   push(@{ $self->{ section }->{ content } }, $page);
    push(@{ $self->{ section }->{ content } }, $uri->path);
    
    # TODO: add page to section menu
    
#    $file->metadata( html_file => $html );
#    $self->{ pages }->{ $html->absolute } = $file;
}

sub visit_directory {
    my ($self, $dir) = @_;
    return unless $self->accept_directory($dir);
    my ($path, $pkg, $uri, $section, @bits, $slashed);

    $self->trace("+ $dir") if $self->{ verbose };

    # as per visit_directory, but with no file name or extension and no
    # module name to re-construct
    @bits =  $dir->filesystem->split_dir($dir->path);
    shift @bits while @bits && ! length $bits[0];
    $uri  =  join(SLASH, @bits);
    $uri  =  $self->{ uri_dir }->dir($uri);

    $section = {
        uri     => $uri,
        dir     => $dir,
        content => [ ],
    };
    
    $slashed = $uri . SLASH;
    
    $self->{ index    }->{ $slashed } = $section;
    $self->{ sections }->{ $slashed } = $section;

#   push(@{ $self->{ section }->{ content } }, $section);
    push(@{ $self->{ section }->{ content } }, $slashed);
        
    # We ignore the in_dirs and not_in_dirs and instead do whatever the 
    # dirs/no_dirs tell us.  We can't enter a directory and process files
    # within it if we haven't first accepted the directory to create the
    # section for it.  So there's no sense doing one without the other.
    local $self->{ depth   } = $self->{ depth } + 1;
    local $self->{ section } = $section;
    
    $self->visit_directory_children($dir);
#        if $self->enter_directory($dir);
}

1;

