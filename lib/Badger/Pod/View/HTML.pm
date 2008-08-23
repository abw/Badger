package Badger::Pod::View::HTML;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Pod::View',
    import    => 'class';


sub visit_model {
    my ($self, $model) = @_;
    my $body = $model->body;
    $self->debug("visit model body: $body\n");
    my $text = join('', $body->visit($self));
    $self->debug("visit model text: $text\n");
    return $text;
}

sub view_model {
    my ($self, $text) = @_;
    $self->debug("MODEL content: $text\n");
    return qq{<div class="pod">$text</div>};
}

sub view_code {
    my ($self, $text) = @_;
    return '';      # TODO: unless $self->{ show_code }
}

sub view_data {
    my ($self, $text) = @_;
    return '';      # TODO: unless $self->{ show_data } or type is :?html
}

sub visit_verbatim {
    my ($self, $text) = @_;
    $self->debug("visit verbatim: $text\n");
    return "<pre>$text</pre>";
}

sub view_verbatim {
    my ($self, $text) = @_;
    return "<pre>$text</pre>";
}

sub view_paragraph {
    my ($self, $text) = @_;
    $self->debug("PARA content: $text\n");
    return "<p>$text</p>";
}

sub view_head1 {
    my ($self, $title, $body) = @_;
    return "<h1>$title/h1>\n$body";
}

sub view_head2 {
    my ($self, $title, $body) = @_;
    return "<h2>$title/h2>\n$body";
}

sub view_head3 {
    my ($self, $title, $body) = @_;
    return "<h3>$title/h3>\n$body";
}

sub view_head4 {
    my ($self, $title, $body) = @_;
    return "<h4>$title/h4>\n$body";
}

sub view_bold {
    my ($self, $body) = @_;
    return "<b>$body</b>";
}

sub view_italic {
    my ($self, $body) = @_;
    return "<i>$body</i>";
}

1;