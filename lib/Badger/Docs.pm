#========================================================================
#
# Badger::Docs
#
# DESCRIPTION
#   Module for managing documentation.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Docs;

use Badger::Class
    version    => 0.01,
    debug      => 1,
    base       => 'Badger::Base',
    filesystem => 'VFS',
    constants  => 'ARRAY DELIMITER PKG',
    constant   => {
        VISITOR => 'Badger::Docs::Visitor',
    };

use Badger::Debug ':dump';
use Badger::Docs::Visitor;


sub init {
    my ($self, $config) = @_;

    my $root = delete $config->{ root }
        || return $self->error_msg( missing => 'root' );

    $self->{ vfs    } = VFS->new( root => $root );
    $self->{ config } = $config;
    
    return $self;
}

sub visitor {
    my $self = shift;
    return $self->{ visitor } 
       ||= $self->VISITOR->new( $self->{ config } );
}

sub visit {
    my $self  = shift;
    return $self->{ visit }
       ||= $self->{ vfs }->visit($self->visitor);
}

1;

__END__
    
    my $class = $self->class;
    my $mods  = $config->{ modules }
             || $config->{ module };
    my $dirs  = $config->{ dirs } 
             || $config->{ dir }
             || [ @INC ];

    $mods = [ split(DELIMITER, $mods) ]
        unless ref $mods eq ARRAY;

    $dirs = [ split(DELIMITER, $dirs) ]
        unless ref $dirs eq ARRAY;

    $self->{ modules } = $mods;
    $self->{ dirs    } = $mods;

    return $self;
}

sub tree {
    my $self = shift;
    return $self->{ tree } ||= $self->build_tree;
}

sub build_tree {
    my $self = shift;
}

sub build_module_tree {
    my ($self, $module) = @_;


    
use AppConfig;
use File::Find::Rule;
use File::Path;
use File::Basename;
use Path::Class;
use Template::Docs::Pod::HTML;
use YAML qw( DumpFile Dump );
use Data::Dumper;
use constant {
    RULE     => 'File::Find::Rule',
    POD2HTML => 'Template::Docs::Pod::HTML',
};

#-----------------------------------------------------------------------
# configuration, most of which can be controlled via command line args
#-----------------------------------------------------------------------

our $PROGRAM  = 'podmods';
our $BIN_DIR  = dir($Bin); 
our $BASE_DIR = $BIN_DIR->parent();
our $META_DIR = dir('metadata', 'docs');
our $PAGE_DIR = dir('templates', 'pages');
our @ACCEPT   = qw( *.pm *.pod );   # files to look for
our @IGNORE   = qw( .svn );         # ignore SVN directories
our $INDEX    = 'index.html';       # HTML index page, e.g. Template::Manual => manual/index.html
our $BASE_URL = '/docs/';           # base URL for docs


# where to store the metadata we generate
our $METADATA = {
    pages     => 'pages.yaml',      # YAML filename for page metadata
    modules   => 'modules.yaml',     # ditto for mapping module names to pages
    sections  => 'sections.yaml',    # ditto for sections/dirs
};

our $REL_URL  = {                   # relative URLs for different sections
    design   => 'design/',
};

# contruct full URLs from base URL argument and relative paths in $REL_URL
our $base_url = $config->url();
our $full_url = {
    map { ($_, "${base_url}$REL_URL->{$_}") }
    keys %$REL_URL,
};


#-----------------------------------------------------------------------
# construct a File::Find rule to find all relevant files
#-----------------------------------------------------------------------

my $rule   = RULE->new();
our @files = sort $rule->or( 
    # either find a .svn directory and ignore it
    $rule->new->directory->name(@IGNORE)->prune->discard, 
    # or find a .pm or .pod file
    $rule->new->file->name(@ACCEPT)
)->in($perldir);


#-----------------------------------------------------------------------
# iterate through the files, converting POD to HTML and harvesting
# metadata 
#-----------------------------------------------------------------------

our $pod2html = POD2HTML->new();
our $pages    = { };
our $modules  = { };
our $sections = { };
our $meta;
local *FP;

#$sections->{ $full_url->{ modules } } = {
#    name  => 'Modules',
#    title => 'Template Toolkit Modules',
#    menu  => [ ],
#};

print "Processing ", scalar(@files), " files\n" if $verbose;

 foreach my $file (@files) {
    my $path = $file;
    $path =~ s[^$perldir$PATHSEP_QM][] || die "Cannot extract root directory ($perldir$PATHSEP) from $path";

    # grok the directory, file name, extension, etc.
    my $name   = basename($path);
    my $ext    = ($name =~ s[\.(\w+)$][] ? $1 : '');
    my $module = "$path";
    $module =~ s[\.(\w+)$][];
    $module =~ s/$PATHSEP_QM/::/g;

    my ($page, $html, $meta);
    my ($link, $order);
    
    $page = $full_url->{ design } . $path;
    $page =~ s/\.(pm|pod)$/.html/;
    $html = "" . $pagedir->file($page);
    $page = file($page);
    
    # grok the parent section of the output file
    my $pathup  = $page->dir();
    if ($page =~ m[$INDEX$]) {
        $pathup = $pathup->parent();
    }
    my $securi  = "$pathup";   # force stringification
    $securi .= '/' unless $securi =~ m[/$];

    # fetch the section data (or create it) and then the menu 
    # from the section (again, creating it if necessary) for us
    # to add this page to
    my $section = $sections->{ $securi } ||= { };
    my $menu    = $section->{ menu   } ||= [ ];

    # don't add the index page to the section menu
    unless ($page eq "$base_url$INDEX") {
        # add the item at a specific position in the menu, or at the end if
        # no order is defined
        if (defined $order) {
            $menu->[$order] = "$page";
        }
        else {
            push(@$menu, "$page");
        }
    }

    # now process the file
    if ($debug) {
        print "    <= $file\n";
        print "    => $html\n";
    }
    
    if ($dry_run) {
        $meta = { title => $module };
    }
    else {
        # make destination directory if necessary
        my $hdir = dirname($html);
        mkpath($hdir) unless -d $hdir;
        
        # convert POD to HTML and write to file
        open(FP, ">$html") || die "cannot open $html: $!";
        eval { print FP $pod2html->convert_pod_file($file); };
        close(FP) || die "cannot close $html: $!";
        if ($@) {
            warn("skipping $html: $@\n");
            next;
        }

        # fetch the metadata harvested from the POD
        $meta = $pod2html->metadata();
    }

#    my $data = {
#        pod    => $file,
#        path   => $path,
#        name   => $name,
#        ext    => $ext,
#        module => $module,
#        dir    => dirname($path),
#    };

    # add the new page to the hash of all pages
    $pages->{ $page } = {
        uri    => "$page",   # force stringification
        name   => $name,
        title  => $meta->{ title } || $module,
        about  => $meta->{ summary },
    };
    
    # $link may be set if we should link any references to this
    # module to a page other than the default
    $link ||= $page;
    $modules->{ $module } = "$link";   # force stringification

#    print STDERR "$page => $pathup\n";
}

# walk through each menu and attach back/next links to each page
while (my ($k, $v) = each %$sections) {
    my $menu = $v->{ menu } || next;
    my @todo = @$menu;
    my @done;

    while (@todo) {
        my $this = shift @todo;
        next unless $this;
        my $page = $pages->{ $this };
        $page->{ up } = "${k}index.html"
            unless $page->{ uri } eq "${k}index.html";
        if (@done) {
            $page->{ back } = $done[-1];
            print STDERR "LINK BACK [$this] [$page->{ back }]\n" if $debug;
        }
        if (@todo) {
            $page->{ next } = $todo[0];
            print STDERR "LINK NEXT [$this] [$page->{ next }]\n" if $debug;
        }
        push(@done, $this);
    }
}

#-----------------------------------------------------------------------
# tweak some metadata values
#-----------------------------------------------------------------------

my $docs = $pages->{'/design/index.html'};
$docs->{ name  } = 'Design Documentation';
$docs->{ short } = 'Design';
$docs->{ title } = 'Template Toolkit v3 Design Documentation';
$docs->{ up    } = '/index.html';

delete $sections->{'/'};

# add back/next to docs/index

#-----------------------------------------------------------------------
# write the metadata YAML files
#-----------------------------------------------------------------------

my $metafile = $metadir->file($METADATA->{ pages });
print "Generating pages metadata file: $metafile\n" if $verbose;
DumpFile($metafile, $pages);

$metafile = $metadir->file($METADATA->{ sections });
print "Generating section metadata file: $metafile\n" if $verbose;
DumpFile($metafile, $sections);

$metafile = $metadir->file($METADATA->{ modules });
print "Generating modules metadata file: $metafile\n" if $verbose;
DumpFile($metafile, $modules);


#-----------------------------------------------------------------------
# look for index files
#-----------------------------------------------------------------------

if ($debug) {
   print Dumper(\@files);
   print Dumper($pages);
}


