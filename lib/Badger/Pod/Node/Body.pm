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
    accessors   => 'name body',
    words       => 'ACCEPT EXPECT',
    constants   => 'LAST CODE TRUE',
    constant    => {
        type   => 'body',
    },
    messages    => {
        expected     => 'Missing %s to terminate %s',
        unacceptable => '%s cannot accept %s element',
    };

#use overload
#    '""'     => \&text,
#    bool     => \&TRUE,
#    fallback => 1;

sub init {
    my ($self, $config) = @_;
    $self->SUPER::init($config);
    my $body = $config->{ body } || [ ];
    $self->{ body } = $self->node( list => @$body );
    $self->{ name } = $config->{ name };
    return $self;
}

sub accept {
    my $self = shift;
    return @_ 
        ? $self->class->hash_value( ACCEPT => shift )
        : $self->class->hash_vars( ACCEPT );
}

sub expect {
    my $self = shift;
    my $expect = $self->class->any_var( EXPECT ) || return;
    return @_ 
        ? $expect eq $_[0]
        : $expect;
}

sub add {
    my ($self, $parser, $type, @args) = @_;
    
    if ($self->accept($type)) {
        my $node = $self->node($type, @args);
        $node->prepare($parser);
        $self->debug($self->type, " accepting $type\n") if $DEBUG;
        $self->{ body }->push($node);
        return $node;
    }
    
    if (my $expect = $self->expect) {
        if ($type eq $expect) {
            $self->debug($self->type, " got expected $type\n") if $DEBUG;
            # we got the terminating element we expected, e.g. =over ... =back
            return $parser->REDUCE;
        }
        else {
            # we didn't get the terminating element we expected
            $self->debug($self->type, " expected $expect but got $type\n") if $DEBUG;
            return $parser->missing($expect, $self->type, $args[0]->{ line });
        }
    }

    # decline - we don't want it, and we can terminate gracefully
    return 0;
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

sub warning {
    my $self = shift;
    my $line = pop;     # $line is last argument
    my $text = $self->message(@_);
    $self->warn_msg( at_line => $text, $line );
}

sub text {
    my $self = shift;
    join("", $self->body->each('text') );
}

sub TEST_text {
    my $self = shift;
    '[' . $self->type . "]\n" . 
    $self->head_text . $self->body_text . 
    "\n[/" . $self->type . "]\n";
}

sub head_text {
    '';
#    shift->{ text };
}

sub body_text {
    my $self = shift;
    join("", $self->body->each('text') );
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
