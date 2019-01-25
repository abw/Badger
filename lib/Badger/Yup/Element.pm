package Badger::Yup::Element;

use Badger::Debug ':dump';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    utils     => 'xprintf',
    constants => 'CODE',
    constant  => {
        FACTORY_SLOT => 0,
        NAME_SLOT    => 1,
        ARGS_SLOT    => 2,
        PARENT_SLOT  => 3,
    },
    messages => {
        no_factory      => 'No factory defined for constructing further expressions',
        class_autoload  => "Cannot AUTOLOAD class method %s called at %s line %s",
        invalid         => "%s",
        missing_arg     => "%s requires an argument for '%s'",
    };


sub new {
    my $class = shift;
    my $self  = bless [ @_ ], $class;
    return $self->init;
}

sub init {
    $_[0];
}

sub factory {
    my $self = shift;
    return $self->[FACTORY_SLOT]
        || $self->error_msg('no_factory');
}

sub parent {
    $_[0]->[PARENT_SLOT];
}

sub args {
    $_[0]->[ARGS_SLOT];
}
sub arguments {
    my $args = shift->args || return ();
    return @$args;
}

sub arg_required {
    my $self = shift;
    # args: $mod, $arg, $value
    if (@_ < 3) {
        $self->error_msg( missing_arg => @_ );
    }
}

sub validate {
    my $self   = shift;
    my $value  = shift;
    my $parent = $self->parent;
    if ($parent) {
        $value = $parent->validate($value);
    }
    return $self->validator($value, $self->arguments);
}

sub validator {
    shift->not_implemented('in base class');
}

sub invalid {
    my ($self, $message, @args) = @_;
    if ($message) {
        if (ref $message eq CODE) {
            $self->error($message->(@args));
        }
        else {
            $self->error(xprintf($message, @args));
        }
    }
    else {
        $self->error_msg( invalid => @args );
    }
}


sub catch {
    my $self = shift;
    return $self->factory->element( catch => \@_, $self );
}

sub build {
    my ($self, $validators) = @_;
    if ($validators && @$validators) {
        my $validator = shift @$validators;
        my ($name, @args) = @$validator;
        return $self->$name(@args)->build($validators);
    }
    else {
        return $self;
    }
}


sub DUMP {
    my $self   = shift;
    my $parent = $self->[PARENT_SLOT];
    my $name   = $self->[NAME_SLOT];
    my $args   = $self->dump_data_inline($self->[ARGS_SLOT]);
    my $text   = $parent
        ? ($parent->DUMP . "\n  -> ")
        : '';
    return $text . "$name($args)";
}

1;
