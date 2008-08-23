#========================================================================
#
# Badger::Docs::Pod2HTML
#
# DESCRIPTION
#   Converts POD markup into HTML.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Docs::Pod2HTML;

use Badger::Class
    version => 0.01,
    debug   => 0,
    base    => 'Badger::Base',
    constant => {
        PARSER => 'Pod::POM',
        VIEW   => 'Badger::Docs::Pod2HTML::View',
    },
    messages => {
        no_file => 'no file specified to convert',
        no_text => 'no text specified to convert',
        parse   => 'error reading %s: %s',
        view    => 'error converting %s: %s',
    };
    
use Pod::POM;

our $CPAN_MODS = {
    map { ($_, 1) }
    qw( CGI DBI POSIX Template::DBI Template::GD Template::XML )
};
our $ITEM = 1;

sub convert_pod_pom {
    my ($self, $pom, $name) = @_;
    my $view   = VIEW->new;
    my $output = $view->print($pom)
        || return $self->error( view => $name || 'POD', $view->error() );
    $self->{ meta } = $view->{ meta } || { };
    return $output;
}

sub convert_pod_file {
    my $self   = shift;
    my $file   = shift || return $self->error_msg('no_file');
    my $view   = VIEW->new();
    my $parser = PARSER->new();
    my $podpom = $parser->parse_file($file)
        || return $self->error_msg( parse => $file, $parser->error() );
    return $self->convert_pod_pom($podpom, $file);
}

sub convert_pod_text {
    my $self   = shift;
    my $text   = shift || return $self->error_msg('no_text');
    my $name   = shift || 'POD';
    my $view   = VIEW->new();
    my $parser = PARSER->new();
    my $podpom = $parser->parse_text($text)
        || return $self->error_msg( parse => $name, $parser->error() );
    return $self->convert_pod_pom($podpom, $name);
}


sub metadata {
    my $self = shift;
    return $self->{ meta };
}

package Badger::Docs::Pod2HTML::View;
use base 'Pod::POM::View::HTML';

use Text::Wrap;
$Text::Wrap::huge = 'overflow';

sub view_pod {
    my ($self, $pod) = @_;
    my $meta = $self->{ meta } ||= { };
    $meta->{ sections } = [ ];
    my $content = $pod->content->present($self) || '';
    $meta->{ module  } ||= '';
    $meta->{ summary } ||= '';

    return <<EOF;
[% TAGS [** **] %]

<div class="pod">
$content
</div>
EOF
}

sub view_head1 {
    my ($self, $head1) = @_;
    my $title   = $head1->title->present($self);
    my $content = $head1->content->present($self);
    my $meta    = $self->{ meta } ||= { };

#    print STDERR "HEAD1: $title\n";

    if ($title eq 'NAME') {
        my $text = $head1->content();
        @$meta{ qw( module summary ) } = map { 
            s/^\s+//m; # remove leading whitespace
            s/\s$//m;  # return trailing whitespace
            $_ || '';  # pass modified value through
        } split(/\s-\s/, $text);
        return '';
    }
    elsif ($title eq 'DESCRIPTION') {
#        $meta->{ description } = $content;
    }

    # remove any leading/trailing whitespace from content
    for ($content) {
        s/^\s+//;
        s/\s$//;
        s/^/    /mg;
    }
    my $id = $title;
    $id =~ s/\W+/_/g;
    $id = "section_$id";
    
    $title =~ s/'/\\'/g;
    return <<EOF;
[** WRAPPER page/section title='$title' id='$id' -**]
$content
[** END -**]
EOF

}

sub view_head2 {
    my ($self, $head2) = @_;
    my $title = $head2->title->present($self);
    my ($class, $id) = ('') x 2;

    if ($title =~ /\s*(.*)?\(.*?\)/) {
        # looks like a method name
        my $name = $1;
        $name =~ s/\W+/_/g;
        $class = 'method';
        $id = "method_${name}";
#        $title = qq{<h2 class="method" id="method_${name}">$title</h2>};
    }
    else {
        my $name = $title;
        $name =~ s/\W+/_/g;
        $id = "section_$name";
#        $title = qq{<h2 id="$name">$title</h2>};
    }
    
    my $content = $head2->content->present($self);
    $title =~ s/'/\\'/g;
    return <<EOF;
[** WRAPPER page/subsection title='$title' id='$id' class='$class' -**]
$content
[** END -**]
EOF
}

sub view_head3 {
    my ($self, $head3) = @_;
    my $title = $head3->title->present($self);
    my ($class, $id) = ('') x 2;

    if ($title =~ /\s*(.*)?\(.*?\)/) {
        # looks like a method name
        my $name = $1;
        $name =~ s/\W+/_/g;
        $class = 'method';
        $id = "method_${name}";
    }
    else {
        my $name = $title;
        $name =~ s/\W+/_/g;
        $id = "section_$name";
#        $title = qq{<h2 id="$name">$title</h2>};
    }
    
    my $content = $head3->content->present($self);
    $title =~ s/"/&quot;/g;
    
    $class = $class ? " class=\"$class\"" : '';
    $id    = $id    ? " id=\"$id\""       : '';
    return <<EOF;
<h3 class="method"$id$class>$title</h3>
$content
EOF
}

sub view_item {
    my ($self, $item) = @_;

    my $over    = $self->{ OVER };
    my $title   = $item->title();
    my $strip   = $over->[-1];
    my $content = $item->content->present($self);
    my ($anchor, $length);

    if (defined $title) {
        $title = $title->present($self) if ref $title;
        $title =~ s/$strip// if $strip;
        if ($length = length $title) {
            $anchor = $title;
            if ($length < 20) {
                $anchor =~ s/^\s*|\s*$//g; # strip leading and closing spaces
                $anchor =~ s/<.*?>//g;     # strip HTML tags
                $anchor =~ s/\W+/_/g;      # collapse non-word char sequences to _
            }
            else {
                $anchor = $ITEM++;
            }
            $title  = qq{<b>$title</b>} if $content;
        }
    }
    
    my $tag = $anchor ? qq{<li id="item_${anchor}">}
                      : qq{<li>};

    return "$tag$title\n$content</li>\n";
}


sub view_verbatim {
    my ($self, $text) = @_;
    for ($text) {
        s/&/&amp;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
        s/^( {4}|\t)//gm;
        s/^/  /gm;
        s{(\[%.*?%\])}{<span class="tt">$1</span>}gs;
    }
    return "<pre>\n$text\n</pre>\n";
}

sub view_textblock {
    my ($self, $text) = @_;
    for ($text) {
        s/^\s*//;
        s/\s*$//;
        s/\s+/ /mg;
    }
    $text = wrap('  ', '  ', $text);
    return "<p>\n$text\n</p>\n";
}

sub view_seq_link_transform_path {
    my($self, $page) = @_;

#    print "seq_link_tx_path [$page]\n";

    if ($CPAN_MODS->{ $page }) {
        return "[** cpanmod('$page') **]";
    }
    if ($page =~ /^(?:Template(::|#|$)|TT)/ ) {
#        print STDERR "YES $page => #section_$page\n";
        my $fragment = ($page =~ s/#(.*)//) ? $1 : '';
        if ($fragment =~ s|\s*(.*?)\(.*?\)|/|g) {
            $fragment = "#method_$1";
        }
        elsif ($fragment) {
            $fragment = "#section_$fragment";
        }
        return "[** ttmodlink('$page') **]$fragment";
    }
    elsif ($page =~ /::/ ) {
#        print STDERR "CPAN MOD: $page\n";
        return "[** cpanmod('$page') **]";
    }

    elsif ($page =~ s|\s*(.*?)\(.*?\)|/|g ) {
        return "#method_$1";
    }
    else {
#        print STDERR "??? $page => #section_$page\n";
        return "#section_$page";
        #$page =~ s/\W+/_/g;
        #return "#$page";
        return undef;
    }
}

sub view_seq_link {
    my ($self, $link) = @_;

#    print "seq_link [$link]\n";

    # view_seq_text has already taken care of L<http://example.com/>
    if ($link =~ /^<a href=/ ) {
        return $link;
    }
    
#   print "LINK: $link\n";

    $link =~ s/\n/ /g;   # undo line-wrapped tags

    my $orig_link = $link;
    my $linktext;
    # strip the sub-title and the following '|' char
    if ( $link =~ s/ \| (.*) //x ) {
        $linktext = $1;
#        print "[$link] linktext: $linktext\n";
    }

    # full-blown URL's are emitted as-is
    if ($link =~ m{^\w+://}s ) {
        $linktext ||= $link;
        return make_href($link, $linktext);
    }


    # make sure sections start with a /
    $link =~ s|^"|/"|;

    my $page;
    my $section;
    if ($link =~ m|^ (.*?) / "? (.*?) "? $|x) { # [name]/"section"
        ($page, $section) = ($1, $2);
    }
    elsif ($link =~ /\s/) {  # this must be a section with missing quotes
        ($page, $section) = ('', $link);
        $section =~ s/\W+/_/g;
        $section = "section_$section";
    }
    else {
        ($page, $section) = ($link, '');
    }

    # warning; show some text.
    $linktext = $orig_link unless defined $linktext;

    my $url = '';
    if (defined $page && length $page) {
        $url = $self->view_seq_link_transform_path($page);
    }

    # append the #section if exists
    $url .= "#$section" if defined $url and
        defined $section and length $section;

    return make_href($url, $linktext);
}

sub make_href {
    my($url, $title, $section) = @_;

    if (!defined $url) {
        ($url = $title) =~ s/\W+/_/g;
        $url = "#section_$url";
#        print STDERR "*** $title => $url\n";
#        return defined $title ? "<i>$title</i>"  : '';
    }

    $title = $url unless defined $title;
    #print "$url, $title\n";
    return qq{<a href="$url">$title</a>};
}

sub view_seq_text {
     my ($self, $text) = @_;

     unless ($Pod::POM::View::HTML::HTML_PROTECT) {
         for ($text) {
            s/&/&amp;/g;
            s/</&lt;/g;
            s/>/&gt;/g;
        }
     }

     return $text;
}

sub view_seq_file {
    my ($self, $text) = @_;
    return qq{<code class="file">$text</code>};
}



1;
__END__

=head1 NAME

Badger::Docs::Pod2HTML - convert POD to HTML

=head1 SYNOPSIS

    use Badger::Docs::Pod2HTML;
    
    my $html = Badger::Docs::Pod::HTML->convert_pod_file($filename);

=head1 DESCRIPTION

This module is a wrapper around the Pod::POM module.  It converts
Pod markup into HTML.

=head1 METHODS

=head2 convert_pod_file($filename)

Reads the POD markup from the file denoted by the C<$filename>
argument and converts it to HTML.  The HTML output is returned.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2005-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
