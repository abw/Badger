package My::Mixin::Bar;

use Badger::Class
    version => 0.01,
    debug   => 0,
    base    => 'Badger::Mixin',
#    mixin   => 'Badger::Mixin::Messages';
    utils     => 'xprintf',
    import    => 'class',
    constants => 'BLANK SPACE',
    mixins    => '$MESSAGES message warn_msg error_msg decline_msg 
                  not_implemented todo';

our $MESSAGES = { 
    hello     => 'Hello %s!',
};

sub message {
    my $self   = shift;
    my $name   = shift 
        || $self->fatal("message() called without format name");
    my $format = $self->class->hash_value( MESSAGES => $name )
        || $self->fatal("message() called with invalid message type: $name");
    xprintf($format, @_);
}

sub warn_msg {
    my $self = shift;
    $self->warn( $self->message(@_) );
}

sub error_msg {
    my $self = shift;
    $self->error( $self->message(@_) );
}

sub decline_msg {
    my $self = shift;
    $self->decline( $self->message(@_) );
}

1;

#-----------------------------------------------------------------------
# generate not_implemented() and todo() methods
#-----------------------------------------------------------------------

class->methods(
    map {
        my $name = $_;
        $name => sub {
            my $self = shift;
            my $ref  = ref $self || $self;
            my ($pkg, $file, $line, $sub) = caller(0);
            $sub = (caller(1))[3];   # subroutine the caller was called from
            $sub =~ s/(.*):://;
            my $msg  = @_ ? join(BLANK, SPACE, @_) : BLANK;
            return $self->error_msg( $name => "$sub()$msg", "for $ref in $file at line $line" );
        };
    }
    qw( not_implemented todo )
);

1;

