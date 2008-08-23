#========================================================================
#
# Badger::Pod::Node::List
#
# DESCRIPTION
#   Base class container for a list of Pod nodes.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Pod::Node::List;

use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Base',
    utils       => 'blessed',
    constants   => 'FIRST LAST CODE TRUE',
    constant    => {
        type => 'body',
    },
    messages => {
        not_blessed => "Cannot call %s method on unblessed item: %s",
        no_method   => "Cannot call %s method on object: %s",
    };

# cache for inspector methods created by inspector() and used by each()
our $INSPECTORS;

use overload
    '""'     => \&text,
    bool     => sub { shift },
    fallback => 1;

# We want to use the CORE push/pop/shift/unshift functions in this module
# without having to explicitly scope them as CORE::shift, etc., which gets
# tedious pretty quickly. So we define our methods as _push(), _pop(),
# etc, allow Perl to compile the module and resolve the CORE methods.
# After the module is compiled, Perl will run this code which maps the
# methods to their  final resting place as push(), pop(), etc.
*push    = \&_push;
*pop     = \&_pop;
*shift   = \&_shift;
*unshift = \&_unshift;


sub new {
    my $class = shift;
    bless [ @_ ], $class;
}

sub _push {
    my $self = shift;
    push(@$self, @_);
    $self;
}

sub _pop {
    my $self = shift;
    pop(@$self);
}

sub _shift {
    my $self = shift;
    shift(@$self);
}

sub _unshift {
    my $self = shift;
    unshift(@$self, @_);
}

sub size {
    scalar(@{ $_[0] });
} 

sub first {
    $_[0]->[FIRST];
}

sub last {
    $_[0]->[LAST];
}

sub each {
    my $self = shift;

    # return list or list ref of items when no args are specified
    return wantarray ? @$self : [@$self]
        unless @_;
    
    # otherwise the first argument is a sub ref or method name
    my $name  = shift;
    my $code  = ref $name eq CODE ? $name : $self->inspector($name);
    my @items = map { $code->($_, @_) } @$self;

    return wantarray ? @items : \@items;
}

sub inspector {
    my ($self, $name) = @_;

    # construct an inspector subroutine whose job it is to call a 
    # particular method on the object passed as the first argument
    
    return $INSPECTORS->{ $name } ||= sub {
        my $item = shift;
        my $method;

        $self->error_msg( not_blessed => $name, $item )
            unless blessed $item;

        $self->error_msg( no_method => $name, ref $item )
            unless ($method = $item->can($name));

        $method->($item, @_);
    };
}

sub visit {
    my ($self, $visitor, @args) = @_;
    map { $_->visit($visitor, @args) } @$self;
}

sub text {
    join('', shift->each('text'));
}

1;

__END__
