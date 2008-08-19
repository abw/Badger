#========================================================================
#
# Badger::Pod::Node::Body
#
# DESCRIPTION
#   Base class object for Pod nodes that have body content, e.g. 
#   pod blocks, text and command paragraphs, etc.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Node::Body;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Pod::Node',
    accessors   => 'name',
    constants   => 'LAST CODE',
    constant    => {
        type => 'body',
    };

sub init {
    my ($self, $config) = @_;
    $self->SUPER::init($config);
    $self->{ body } = $config->{ body } || $self->node('list');
    $self->{ name } = $config->{ name };
    return $self;
}

sub add {
    my $self = shift;
    my $type = shift;
    my $node = $self->node($type, @_);
    $self->debug("adding $type to ", $self->type, "\n") if $DEBUG;
    $self->{ body }->push($node);
    return $node;
}

sub last {
    $_[0]->{ body }->[LAST];
}

sub push {
    shift->{ body }->push(@_);
}

sub each {
    shift->body->each(@_);
}

1;

__END__

sub body_type {
    my ($self, $type) = @_;
    my @items = 
        grep { $_->type eq $type } 
        @{ $self->{ body } };
        
    return wantarray 
        ?  @items
        : \@items;
}

sub body_each {
    my ($self, $method, @args) = @_;
    my @items = 
        map { $_->$method(@args) } 
        @{ $self->{ body } };
    
    return wantarray 
        ?  @items
        : \@items;
}

sub body_type_each {
    my ($self, $type, $method, @args) = @_;
    my $code  = $method if ref $method eq CODE;
    my @items = 
        map { $code ? $code->($_, @args) : $_->$method(@args) } 
        grep { $_->type eq $type } 
        @{ $self->{ body } };
        
    return wantarray 
        ?  @items
        : \@items;
}

1;
