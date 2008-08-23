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
    version    => 0.01,
    debug      => 0,
    base       => 'Badger::Filesystem::Visitor',
    constants  => 'ARRAY DELIMITER PKG',
    accessors  => 'index pages modules content',
    filesystem => 'VFS',
    constant   => {
        DOT      => '.',
        SLASH    => '/',
        STAR     => '*',
        SLASHED  => qr{/$},
        HTML     => 'html',
        POD2HTML => 'Badger::Docs::Pod2HTML',
    },
    messages => {
        mkdir => "%s does not exist (set the 'mkdir' option to create it automatically)",
    };

use Badger::Debug ':dump';
use Badger::Docs::Pod2HTML;

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
    $self->{ verbose  } = $config->{ verbose } || $DEBUG || 0;
    $self->{ dry_run  } = $config->{ dry_run } || 0;
    $self->{ mkdir    } = $config->{ mkdir   } || 0;
    $self->{ name     } = $config->{ name    } || '';
    $self->{ depth    } = 0;
    $self->{ index    } = { };
    $self->{ pages    } = { };
    $self->{ modules  } = { };
    $self->{ sections } = { };
    $self->{ section } = $self->new_section($self->{ uri_dir }, $self->{ name });

    my $pod2html = $config->{ pod2html } || POD2HTML;
    $self->{ pod2html } = ref $pod2html ? $pod2html : $pod2html->new;

    return $self;
}


sub cleanup_section {
    my $self = shift;
    my $section = $self->{ section };
    $section->{ menu } ||= $self->sort_content( $section->{ content } );
};  

sub sections {
    my $self = shift;
    $self->cleanup_section;
    $self->{ sections };
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

    # add page to various indices
    $self->{ index   }->{ $uri } = $page;
    $self->{ pages   }->{ $uri } = $page;
    $self->{ modules }->{ $pkg } = $uri->absolute;
    
    # add page to content of current section (i.e. parent dir)
    push(@{ $self->{ section }->{ content } }, $uri->path);
    push(@{ $self->{ section }->{ pages   } }, $uri->path);
    
    # shout about it or be quiet? 
    if ($self->{ dry_run }) {
        $self->trace("  ! Dry run: not converting Pod to HTML") if $self->{ verbose };
        return;
    }
    if ($DEBUG) {
        $self->trace(
            "   # Converting Pod to HTML\n",
            "   # From: ", $file->definitive, "\n",
            "   #   To: ", $uri->definitive
        );
    }

    # create the parent directory of outfile file if it doesn't exist
    # and our mkdir option is set
    my $dir = $uri->parent;
    unless ($dir->exists) {
        if ($self->{ mkdir }) {
            $dir->mkdir;
        }
        else {
            $self->error_msg( mkdir => $dir->definitive );
        }
    }
    
    # generate the HTML and write it to the output 
    my $text = $file->text;
    my $html = $self->{ pod2html }->convert_pod_text($text, $file->definitive);
    $uri->write($html);
    
#    $file->metadata( html_file => $html );
#    $self->{ pages }->{ $html->absolute } = $file;
}

sub visit_directory {
    my ($self, $dir) = @_;
    return unless $self->accept_directory($dir);
    my ($path, $pkg, $uri, $section, @bits);

    $self->trace("+ $dir") if $self->{ verbose };

    # as per visit_directory, but with no file name or extension and no
    # module name to re-construct
    @bits =  $dir->filesystem->split_dir($dir->path);
    shift @bits while @bits && ! length $bits[0];
    $uri  =  join(SLASH, @bits);
    $uri  =  $self->{ uri_dir }->dir($uri);
    $pkg  =  join(PKG,  @bits);

    $section = $self->new_section($uri, $pkg);
    $section->{ title } = $pkg.PKG.STAR;
    
    # We ignore the in_dirs and not_in_dirs and instead do whatever the 
    # dirs/no_dirs tell us.  We can't enter a directory and process files
    # within it if we haven't first accepted the directory to create the
    # section for it.  So there's no sense doing one without the other.
    local $self->{ depth   } = $self->{ depth } + 1;
    local $self->{ section } = $section;
    
    $self->visit_directory_children($dir);
    
    $section->{ menu } = $self->sort_content( $section->{ content } );
#        if $self->enter_directory($dir);
}

sub new_section {
    my ($self, $uri, $name) = @_;
    $uri = $uri->absolute if ref $uri;
    $uri .= SLASH unless $uri =~ SLASHED;
    
    my $section = {
        uri      => $uri,
        name     => $name,
        content  => [ ],
        sections => [ ],
        pages    => [ ],
    };
    $self->{ index    }->{ $uri } = $section;
    $self->{ sections }->{ $uri } = $section;

    push(@{ $self->{ section }->{ content  } }, $uri);
    push(@{ $self->{ section }->{ sections } }, $uri);

    return $section;
}    
    
sub trace {
    my $self    = shift;
    my $message = join('', @_);
    chomp($message);
    my $pad = ' ' x ($self->{ depth } * 2);
    $message =~ s/^/$pad/mg;
    print STDERR $message, "\n";
}

sub sort_content {
    my $self    = shift;
    my @content = @_ == 1 && ref $_[0] eq ARRAY ? @{$_[0]} : @_;
    my @sorted  = 
        map  { $_->[0] }
        sort { $a->[1] cmp $b->[1] }
        map  { 
            my $org = $_; 
            s/\.html$/_1/;
            s/\/$/_2/;
            [$org, $_];
        }
        @content;
        
    return wantarray
        ?  @sorted
        : \@sorted;
}

1;

