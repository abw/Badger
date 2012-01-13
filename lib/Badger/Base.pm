#========================================================================
#
# Badger::Base
#
# DESCRIPTION
#   Base class module implementing common functionality for various 
#   other Badger modules.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Base;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    constants => 'CODE HASH ARRAY BLANK SPACE PKG REFS ONCE WARN NONE',
    import    => 'class classes',
    utils     => 'blessed reftype xprintf',
    words     => 'ID EXCEPTION THROWS ERROR DECLINED before after',
    constant  => { 
        base_id => 'Badger',      # stripped from class name to make id
        TRIAL   => 'Badger::Base::Trial',
    };

use Badger::Exception;              # TODO: autoload
use Badger::Debug 'debug debug_up dump_data_inline dump_data dump_list dump_hash';

our $EXCEPTION = 'Badger::Exception' unless defined $EXCEPTION;
our $ON_WARN   = WARN;
our $MESSAGES  = { 
    not_found       => '%s not found: %s',
    not_found_in    => '%s not found in %s',
    not_implemented => '%s is not implemented %s',
    no_component    => 'No %s component defined',
    bad_method      => "Invalid method '%s' called on %s at %s line %s",
    invalid         => 'Invalid %s specified: %s',
    unexpected      => 'Invalid %s specified: %s (expected a %s)',
    missing_to      => 'No %s specified to %s',
    missing         => 'No %s specified',
    todo            => '%s is TODO %s',
    at_line         => '%s at line %s',
    at_file_line    => '%s in %s at line %s',
};


sub new {
    my $class = shift;

    # install warning handling for odd number of parameters when DEBUG enabled
    local $SIG{__WARN__} = sub {
        Badger::Utils::odd_params(@_);
    } if DEBUG;
    
    my $args  = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $self  = bless { }, ref $class || $class;
       $self  = $self->init($args);

    # be careful to account for object that overload the boolean comparison
    # operator and may return false to a simple truth test.
    return defined $self
        ? $self
        : $self->error("init() method failed\n");
}

sub init {
    my $self = shift;
    # default action is to store reference to entire configuration so 
    # that methods can examine it later if they need to
    $self->{ config } = shift;
    return $self;
}

sub warn {
    my $self  = shift;
    return unless @_;

    my $message  = join(BLANK, @_);
    my $handlers = $self->on_warn;

    $self->debug("dispatching handlers for warn: ", $self->dump_data_inline($handlers), "\n") if DEBUG;
    $self->_dispatch_handlers( warn => $handlers => $message )
        if $handlers && @$handlers;
    
    # Warning is usually raised by the last handler in the chain which
    # defaults to 'warn', so it's OK to just drop out here.
}

sub error {
    my $self  = shift;
    my $class = ref     $self || $self;
    my $type  = reftype $self || BLANK;
    no strict   REFS;
    no warnings ONCE;

    if (@_) {
        # don't stringify objects passed as argument
        my $message = ref $_[0] ? shift : join(BLANK, map { defined($_) ? $_ : BLANK } @_);
        my $handlers = $self->on_error;

        # set package variable
        ${ $class.PKG.ERROR    } = $message;
        ${ $class.PKG.DECLINED } = 0;

        if ($type eq HASH) {
            # set ERROR and DECLINED items in object
            $self->{ ERROR    } = $message;
            $self->{ DECLINED } = 0;
        }

        ($message) = $self->_dispatch_handlers( error => $handlers => $message )
            if $handlers && @$handlers;

        $self->throw($message);
    }
    elsif ($type eq HASH) {
        return $self->{ ERROR };
    }
    else {
        return ${ $class.PKG.ERROR };
    }
    # not reached
}

sub decline {
    my $self   = shift;
    my $class  = ref     $self || $self;
    my $type   = reftype $self || BLANK;
    my $reason = @_ == 1 ? shift : join(BLANK, @_);
    no strict   REFS;
    no warnings ONCE;
    
    ${ $class.PKG.ERROR    } = $reason;
    ${ $class.PKG.DECLINED } = 1;

    if ($type eq HASH) {
        $self->{ ERROR    } = $reason;
        $self->{ DECLINED } = 1;
    }

    return undef;
}

sub declined {
    my $self  = shift;
    my $class = ref     $self || $self;
    my $type  = reftype $self || BLANK;
    no strict REFS;
    return ($type eq HASH)
        ? $self->{ DECLINED }
        : ${ $class.PKG.DECLINED };
}

sub reason {
    my $self  = shift;
    my $class = ref     $self || $self;
    my $type  = reftype $self || BLANK;
    no strict REFS;
    return $type eq HASH
         ? $self->{ ERROR }
         : ${ $class.PKG.ERROR };
}

sub throw {
    my $self = shift;
    my $type = shift;
    my $emod = $self->exception;
    my $e;
    
    # TODO: grok file/line/sub from caller and add to exceptions
    
    if (! @_) {
        # single argument can be an exception object or an error message
        # which is given whatever type is returned by throws()
        #
        #   throw($exception)
        #   throw($info)
        
        if (blessed $type && $type->isa($emod)) {
            $self->debug("returning exception object: ", ref $type, " => [$type]\n") if DEBUG;
            $e = $type;
        }
        else {
            $self->debug("creating new exception object chain: info => $type\n") if DEBUG;
            $e = $emod->new( type => $self->throws, info => $type );
        }
    }
    else {
        # Next argument can also be an exception object (e.g. when chaining
        # exceptions) or a regular info message.  In the first case, we don't
        # re-throw the exception if it's already of the correct $type (but we
        # do if any extra arguments are provided)
        #
        #   throw($type, $exception)
        #   throw($type, $info)
        
        my $info = shift;

        if (! @_ && blessed $info && $info->isa($emod) && $info->type eq $type) {
            # second argument is already an exception of type $type
            $e = $info;
        }
        else {
            my $config = @_ && ref $_[0] eq HASH ? shift : { @_ };
            # construct a new exception from $type and $info fields
            $config->{ type } = $type;
            $config->{ info } = $info;
            $self->debug("creating new exception object: ", $self->dump_hash($config), "\n") if DEBUG;
            $e = $emod->new($config);
        }
    }
    $e->throw;
}

sub try {
    my $self = shift;
    if (@_) {
        my $method = shift;
        if (wantarray) {
            my @result = eval { $self->$method(@_) };
            $self->decline($@) if $@;
            return @result;
        }
        else {
            my $result = eval { $self->$method(@_) };
            $self->decline($@) if $@;
            return $result;
        }
    }
    else {
        return TRIAL->_bind_($self);
    }
}

sub catch {
    # this depends on some code in Badger::Exception which I haven't 
    # written yet...
    shift->todo;
}

sub throws {
    my $self  = shift;
    my $type  = reftype $self || BLANK;
    my $class = class($self);
    my $throws;
    
    if (@_) {
        # hash objects store exception type in $self->{ THROWS }, anything
        # else (classes and non-hash objects) use the $THROWS package var
        $throws = $type eq HASH
            ? ($self->{ THROWS } = shift)
            :  $class->var(THROWS, shift);
    }
    elsif ($type eq HASH) {
        # we also look in $self->{ config } to see if a 'throws' was 
        # specified as a constructor argument.
        $throws = $self->{ THROWS } 
              ||= $self->{ config } 
              &&  $self->{ config }->{ throws };
    }
    
    # fall back on looking for any package variable in class / base classes
    return $throws 
        || $class->any_var(THROWS)
        || $class->id;
}

sub exception {
    my $self  = shift;
    my $type  = reftype $self || BLANK;
    my $emod;

    # TODO: Move this into Template::Class.  It's so rare that you want to 
    # set an exception type this way.  Then we can have throw() pass the $type
    # to exception() and allow subclasses to make a decision about what kind
    # of exception to return based on the $type.
    if (@_) {
        # as per throws() above, we have to be careful to only treat $self
        # like a hash when it is a hash-based object
        $emod = $type eq HASH
            ? ($self->{ EXCEPTION } = shift)
            : class($self)->var(EXCEPTION, shift);
    }
    elsif ($type eq HASH) {
        $emod = $self->{ EXCEPTION }
            ||= $self->{ config }
            &&  $self->{ config }->{ exception };
    }
    return $emod 
        || class($self)->any_var(EXCEPTION);
}

sub fatal {
    my $self  = shift;
    my $class = ref $self || $self;
    my $error = join(BLANK, @_);
    no strict REFS;

    # set package variable
    ${ $class.PKG.ERROR } = $error;

    if (ref $self && reftype $self eq HASH) {
        $self->{ ERROR    } = $error;
        $self->{ DECLINED } = 0;
    }

    require Carp;
    Carp::confess("Fatal badger error: ", @_);
}


#-----------------------------------------------------------------------
# messages
#-----------------------------------------------------------------------

sub message {
    my $self   = shift;
    my $name   = shift 
        || $self->fatal("message() called without format name");
    my $format = class($self)->hash_value( MESSAGES => $name )
        || $self->fatal("message() called with invalid message type: $name");
    xprintf($format, @_);
}

sub warn_msg {
    # explicitly quantify local message() method in case a subclass decides
    # to re-implement the message() method to do something else
    $_[0]->warn( message(@_) );
}

sub error_msg {
    $_[0]->error( message(@_) );
}

sub fatal_msg {
    $_[0]->fatal( message(@_) );
}

sub decline_msg {
    $_[0]->decline( message(@_) );
}

sub debug_msg {
    $_[0]->debug( message(@_) );
}

sub throw_msg {
    my $self = shift;
    $self->throw( shift, message($self, @_) );
}


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


#-----------------------------------------------------------------------
# generate on_warn() and on_error() methods
#-----------------------------------------------------------------------

class->methods( 
    map {
        my $on_event = $_;
        my $ON_EVENT = uc $on_event;
        
        $on_event => sub {
            my $self  = shift;
            my $class = class($self);
            my $list;
    
            if (ref $self && reftype $self eq HASH) {
                # look in $self->{ config }->{ on_xxx } or in $ON_XXX pkg
                # var for one or more event handlers
                $list = $self->{ $ON_EVENT } 
                    ||= $self->{ config }->{ $on_event }
                    ||  $class->list_vars($ON_EVENT);
                # careful!  the config value might be a single handler
                $list = $self->{ $ON_EVENT } = [$list]
                    unless ref $list eq ARRAY;
                $self->debug("got $on_event handlers: ", $self->dump_data_inline($list), "\n") if DEBUG
            }
            else {
                # class method or non-hash objects use pkg vars only
                $list = $class->var_default($ON_EVENT, []);
                $list = $class->var($ON_EVENT, [$list])
                    unless ref $list eq ARRAY;
            }

            # Add to the list any extra handlers passed as args.  First
            # argument can be 'before' or 'after' to add remaining args
            # to start or end of list, otherwise the entire list is replaced.
            if (@_) {
                if ($_[0] eq before) {
                    shift;
                    unshift(@$list, @_);
                }
                elsif ($_[0] eq after) {
                    shift;
                    push(@$list, @_);
                }
                else {
                    @$list = @_;
                }
            }
            # push(@$list, @_);

            return $list;
        }
    }
    qw( on_warn on_error )
);


#-----------------------------------------------------------------------
# internal method to dispatch on_error/on_warning handlers
#-----------------------------------------------------------------------

sub _dispatch_handlers {
    my ($self, $type, $handlers, @args) = @_;

    $self->debug("_dispatch handlers: ", $self->dump_data_inline($handlers), "\n") if DEBUG;

    foreach (@$handlers) {
        my $handler = $_;        # don't alias list items
        $self->debug("dispatch handler: $handler\n") if DEBUG;
        if (! ref $handler) {
            if ($handler eq WARN) {         # 'warn' - we make sure that the 
                my $msg = join('', @args);  # message is newline terminated
                chomp($msg);                # to stop Perl from adding a line
                CORE::warn $msg, "\n";      # number that'll be wrong.
            }
            elsif ($handler eq NONE) {      # NONE/0 - bail out
                last;
            }
            else {
                $handler = $self->can($handler)
                    || return $self->fatal("Invalid on_$type method: $handler");
                @args = $handler->($self, @args);
            }
        }
        elsif (ref $handler eq CODE) {
            @args = $handler->(@args);
        }
        else {
            $self->fatal("Invalid on_$type handler: $handler");
        }
        $self->debug("mid-dispatch args: [", join(', ', @args), "]\n") if DEBUG;
        # bail out if we got an empty list of return values or a single
        # false value
        last if ! @args || @args == 1 && ! $args[0];
    }
    $self->debug("returning ", join(', ', @args), "\n") if DEBUG;
    return @args;
}
    


#-----------------------------------------------------------------------
# Badger::Base::Trial - nomadic object for $object->try operation
#-----------------------------------------------------------------------

package Badger::Base::Trial;
our $AUTOLOAD;

sub _bind_ {
    my ($class, $object) = @_;
    bless \$object, ref $class || $class;
}

sub AUTOLOAD {
    my $self = shift;
    my ($method) = ($AUTOLOAD =~ /([^:]+)$/ );
    return if $method eq 'DESTROY';

    # call method on target object in eval block, and downgrade
    if (wantarray) {
        my @result = eval { $$self->$method(@_) };
        $$self->decline($@) if $@;
        return @result;
    }
    else {
        my $result = eval { $$self->$method(@_) };
        $$self->decline($@) if $@;
        return $result;
    }

    # TODO: catch missing error methods
}


1;
__END__

=head1 NAME

Badger::Base - base class module

=head1 SYNOPSIS

    # define a new object class derived from Badger::Base
    package Your::Badger::Module;
    use base 'Badger::Base';
    
    sub init {
        my ($self, $config) = @_;
        
        # $config is a hash of named parameters
        # - let's assume 'name' is mandatory
        $self->{ name } = $config->{ name } 
            || return $self->error('no name specified');
        
        # save the rest of the config for later
        $self->{ config } = $config;
    
        # return $self to indicate success
        return $self;
    }
    
    # ...any other methods follow....

    # now use it
    use Your::Badger::Module
    my $object = Your::Badger::Module->new( name => 'Brian' );

=head1 DESCRIPTION

This module implements a base class object from which most of the other
C<Badger> modules are derived. It implements a number of methods to aid in
object creation, configuration, error handling and debugging.

You can use it as a base class for your own modules to inherit the methods
that it provides.

    package Your::Badger::Module;
    use base 'Badger::Base';

You can inherit the default L<new()> constructor method and define your
own L<init()> method to initialise objects.

    sub init {
        my ($self, $config) 
        
        # $config is a hash of named parameters
        # - let's assume 'name' is mandatory
        $self->{ name } = $config->{ name } 
            || return $self->error('no name specified');
        
        # save the rest of the config in case any other
        # methods want to use it later
        $self->{ config } = $config;
    
        # return $self to indicate success
        return $self;
    }

You can then use your module and instantiate objects. The L<new()> method
accepts a list or reference to a hash array of named parameters.

    use Your::Badger::Module;
    
    # list of named parameters
    my $object = Your::Badger::Module->new( name => 'Brian' );
    
    # hash ref of name parameters
    my $object = Your::Badger::Module->new({ name => 'Brian' });

C<Badger::Base> provides a number of other methods that are generally
suitable for all (or most) objects to inherit.  These include methods for
error reporting, debugging and raising warnings.

=head1 METHODS

=head2 new(\%config)

This is a general purpose constructor method. It accepts either a reference to
a hash array of named parameters or a list of named parameters which are then
folded into a hash reference.

    # hash reference of named params
    my $object = Your::Badger::Module->new({
        arg1 => 'value1',
        arg2 => 'value2',
        ...etc...
    });

    # list of named params
    my $object = Your::Badger::Module->new(
        arg1 => 'value1',
        arg2 => 'value2',
        ...etc...
    );

The constructor creates a new object by blessing a hash reference and then
calling the C<init()> method. A reference to the hash array of named
parameters is passed as a single argument. In most cases you should be able to
re-use the existing L<new()> method and define your own L<init()> method to
initialise the object.

The C<new()> method returns whatever the L<init()> method returns. This will
normally be the C<$self> object reference, but your own L<init()> methods are
free to return whatever they like. However, it must be a true value of some
kind or the L<new()> method will throw an error indicating that the L<init()>
method failed.

=head2 init(\%config)

This initialisation method is called by the C<new()> constructor method. 
This is the method that you'll normally want to redefine when you create
a subclass of C<Badger::Base>.

The C<init()> method is passed a reference to a hash array of named
configuration parameters. The method may perform any configuration or
initialisation processes and should generally return the C<$self> reference to
indicate success.

    sub init {
        my ($self, $config) = @_;
    
        # set the 'answer' parameter or default to 42
        $self->{ answer } = $config->{ answer } || 42;
        
        return $self;
    }

The C<init()> method can return any true value which will then be sent back as
the return value from L<new()>. In most cases you'll want to return the
C<$self> object reference, but the possibility exists of returning other
values instead (e.g. to implement singletons, prototypes, or some other clever
object trickery).

If something goes wrong in the C<init()> method then you should call the
L<error()> method (or L<error_msg()>) to throw an error.

    sub init {
        my ($self, $config) = @_;
    
        # set the 'answer' parameter or report error
        $self->{ answer } = $config->{ answer }
            || return $self->error('no answer supplied');
        
        return $self;
    }

The only function of the default L<init()> method in C<Badger::Base> is to
save a reference to the C<$config> hash array in C<$self-E<gt>{ config }>. If
you use the default L<init()> method, or add an equivalent line to your own
L<init()> method, then you can defer inspection of the configuration
parameters until later. For example, you might have a method which does
something like this:

    our $DATE_FORMAT = '%Y-%d-%b';
    
    sub date_format {
        my $self = shift;
        return @_
            ? ($self->{ date_format } = shift)      # set from argument
            :  $self->{ date_format }               # get from self...
           ||= $self->{ config }->{ date_format }   #  ...or config...
           ||  $DATE_FORMAT;                        #  ...or pkg var
    }

This allows you to use C<$self-E<gt>{date_format}> as a working copy of the
value while keeping the original configuration value (if any) intact in
C<$self-E<gt>{config}-E<gt>{date_format}>. The above method will set the value
if you pass an argument and return the current value if you don't. If no
current value is defined then it defaults to the value in the config hash or
the C<$DATE_FORMAT> package variable. Now any other methods that require
access to a date format need only call to the C<date_format()> method to have
it Do The Right Thing.

The benefit here is that you don't have to waste time (and memory) in the
L<init()> method copying the C<date_format> parameter from C<$config> into
C<$self>. That doesn't mean that it's always the right thing to do, but it can
be useful for configuration options that are infrequently used.

The L<on_error()> and L<on_warn()> methods follow this protocol. They look for
an C<ON_ERROR> or C<ON_WARN> item in C<$self> or an C<on_error> or C<on_warn>
parameter in C<$self-E<gt>{config}>. If you want to define C<on_error> and/or
C<on_warn> handlers as configuration parameters then you'll need to either
copy the C<$config> reference into C<$self-E<gt>{config}> or copy the
individual items into C<$self-E<gt>{ON_ERROR}> and/or C<$self-E<gt>{ON_WARN}>, 
respectively.

    # either copy the config...
    sub init {
        my ($self, $config) = @_;
        $self->{ config } = $config;
        # ...more code...
        return $self;
    }

    # ...or the individual items
    sub init {
        my ($self, $config) = @_;
        
        # no need to check if either of these are defined because the
        # on_warn() and on_error() methods will Do The Right Thing.
        $self->{ ON_WARN  } = $config->{ on_warn  };
        $self->{ ON_ERROR } = $config->{ on_error };
        
        # ...more code...
        return $self;
    }

With either of the above in place, you can then define C<on_warn> and
C<on_error> handlers and expect them to work when the L<error()> and
L<warn()> methods are called. 

    my $object = Your::Badger::Module->new(
        on_warn  => \&my_warn,
        on_error => \&my_error,
    );
    
    $object->warn("Rebel Alliance engaging");    # calls my_warn()
    $object->error("Exhaust port unshielded!");  # calls my_error()

=head2 warn($message)

A method to raise a warning.  The default behaviour is to forward all
arguments to Perl's C<warn> function.  However, you can install your
own warning handlers on a per-class or per-object basis using the 
L<on_warn()> method or by setting a C<$ON_WARN> package variable 
in your module.  See L<on_warn()> for further details.

    $object->warn("Careful with that axe, Eugene!");

=head2 on_warn($handler, $another_handler, ...)

This method allows you to install one or more callback handlers which are
called whenever a warning is raised via the L<warn()> method. Multiple
handlers can be installed and will be called in turn whenever an error occurs.
The warning message is passed as an argument to the handlers.

For example, if you wanted to forward warning messages to your favourite 
logging tool, you might do something like this:

    my $log = My::Fave::Log::Tool->new(%log_config);
    
    $object->on_warn( 
        sub { 
            my $message = shift;
            $log->warning("$message);
            return $message;
        } 
    );

The value returned from the callback is forwarded to the next handler (if
there is one). If a callback returns a false value or an empty list then the
remaining handlers will not be called.

The default behaviour of the C<on_warn()> method is to replace any existing
warning handlers with the new one(s) specified.  You can prefix the 
handler(s) with C<'before'> or C<'after'> to add them to the existing list of 
handlers. e.g.

    $object->on_warn( before => \&one, \&two );
    $object->on_warn( after  => \&one, \&two );

The L<on_warn()> method returns a reference to the list, so you can also
monkey about with it directly if you want the handler(s) to go somewhere else.

    my $handlers = $object->on_warn;
    shift(@$handlers, \&one);       # add before existing handlers
    push(@$handlers, \&two);        # add after existing handlers

You can also specify a method name as a warning handler. For example, if you
want to automatically upgrade all warnings to errors for a particular object,
you can write this:

    $object->on_warn('error');      # calls $object->error() on warnings

You can also specify C<'warn'> as a handler which will call Perl's C<warn()>
function.  This is the default value.  To explicitly disable any handlers,
you can use a value of C<0>.

    $object->on_warn('warn');       # raise warning - the default action
    $object->on_warn(0);            # no warnings

These values can be imported from L<Badger::Constants> as the C<WARN> and 
C<NONE> constants.

    use Badger::Constants 'WARN NONE';
    $object->on_warn(WARN);         # raise warning - the default action
    $object->on_warn(NONE);         # no warnings

The L<on_warn()> method works equally well as a class method. In this case it
sets the C<$ON_WARN> package variable for the class. This acts as the
default handler list for any objects of that class that don't explicitly
define their own warning handlers.

    Your::Badger::Module->on_warn(\&handler_sub);

If you prefer you can define this using the C<$ON_WARN> package variable.
This will then be used as the default for all objects of this class.

    package Your::Badger::Module;
    use base 'Badger::Base';
    our $ON_WARN = \&handler_sub;

Multiple values should be defined using a list reference.  Method names
and the special C<warn> flag can also be included.

    our $ON_WARN = [ \&this_code_first, 'this_method_next', 'warn' ]

=head2 error($message)

The C<error()> method is used for error reporting.  When an object method
fails for some reason, it calls the C<error()> method passing an argument
denoting the problem that occurred.  This causes an exception object to
be created (see L<Badger::Exception>) and thrown via C<throw()>.  In this
case the C<error()> method will never return.

    sub engage {
        my $self = shift;
        return $self->error('warp drive offline');
    }

Multiple arguments can be passed to the C<error()> method.  They are 
concatenated into a single string.

    sub engage {
        my $self = shift;
        return $self->error(
            'warp drive ',
             $self->{ engine_no }, 
            ' is offline' 
        );
    }

The error method can also be called without arguments to return the error
message previously thrown by a call to C<error()>. In this case it performs
exactly the same function as the L<reason()> method.

    eval { $enterprise->engage }
        || warn "Could not engage: ", $enterprise->error;

The fact that the C<error()> method can be called without arguments allows you
to write things like this:

    # doesn't throw anything if list is empty
    $self->error(@list_of_errors);

An existing exception object can also be passed as a single argument to the
error method. In this case, the exception object is re-thrown unmodified.

    sub save_the_world {
        eval { $self->world_peace };
    
        if ($@) {
            $self->call_international_rescue($@);   # call Thunderbirds
            return $self->error($@);                # re-throw error
        };
    }

ASIDE: You may have noticed in these examples that I'm using the C<return>
keyword when raising an error.  For example:

    return $self->error('warp drive offline');

The C<error()> method doesn't return when you call it with arguments so the
C<return> keyword has no effect whatsoever. However, I like to put it there to
give a clear indication of what my intentions are at that point. It also means
that the code will continue to return even if a subclass should "accidentally"
define a different L<error()> method that doesn't throw an error (don't laugh
- it happens). It's also useful when used in conjunction with syntax
highlighting to see at a glance where the potential exit points from a method
are (assuming you make C<return> bright red or something obvious like I do).

The C<error()> method can also be called as a class method. In this case, it
updates and retrieves the C<$ERROR> package variable in the package of the
subclass module. This can be used to raise and examine errors thrown by class
methods.

    # calling package error() method
    my $object = eval { Your::Badger::Module->new() }
        || warn "Could not create badger module: ", 
                Your::Badger::Module->error();
    
    # accessing $ERROR package variable
    my $object = eval { Your::Badger::Module->new() }
        || warn 'Could not create badger module: ",
                $Your::Badger::Module::ERROR;

=head2 on_error($handler, $another_handler, ...)

This method is similar to L<on_warn()> in allowing you to install a callback 
handler which is called whenever an error is raised via the L<error()> method
(or the L<error_msg()> wrapper).

    $world->on_error( 
        sub { 
            my $message = shift;
        
            Thunderbirds->call({
                priority => IR_PRIORITY_HIGH,
                message  => $message,
            });
        
            return $message;    # forward message to next handler
        }
    );

The value returned from the callback is forwarded to the next handler.
If a callback returns a false value or an empty list then the remaining
handlers will not be called.  However, the error will still be raised
regardless of what any of the handlers do or return.

=head2 decline($reason, $more_reasons, ...)

The C<decline()> method is used to indicate that a method failed but without
raising an error. It is typically used for methods that are asked to fetch a
resource (e.g. a record in a database, file in a filesystem, etc.) that may
not exist. In the case where it I<isn't> considered an error if the requested
resource is missing then the method can call the L<decline()> method. It works
like L<error()> in that it stores the message internally for later inspection
via L<reason()>. But instead of throwing the message as an exception, it 
simply returns C<undef>

    sub forage {
        my ($self, $name) = @_;
    
        # hard error if database isn't connected
        my $db = $self->{ database }
            || return $self->error('no database')
    
        if ($thing = $db->fetch_thing($name)) {
            # return true value on success
            return $thing;
        }
        else {
            # soft decline if not found
            return $self->decline("not found: $name")
        }
    }

Like L<error()>, the L<decline()> method can be called without arguments to
return the most recent decline message, although it's probably better to 
use L<reason()> which is designed specifically for that purpose.  The
L<decline()> method can also be called as a class method as well as an 
object method, as per L<error()>.

=head2 declined()

Returns the values of the internal flag which indicates if an object declined
by calling the L<decline()> method.  This is set to C<1> whenever the 
L<decline()> method is called and cleared back to C<0> whenever the 
L<error()> method is called.

    my $result = eval { $forager->fetch('nuts') };
    
    if ($result) {
        print "result: $result\n";
    }
    elsif ($forager->declined) {
        print "declined: ", $forager->reason, "\n";
    }
    else {
        print "error: ", $forager->reason, "\n";
    }

=head2 reason()

Returns the message generated by the most recent call to L<error()> or
L<decline()> (or any of the wrapper methods like L<error_msg()> and 
L<decline_msg()>).

    $forager->forage('nuts and berries')
        || die $forager->reason;

=head2 message($type, @args)

This method generates a message using a pre-defined format. Message formats
should be defined in a C<$MESSAGES> package variable in the object's package
or one of its base classes.

    # base class
    package Badger::Example::One
    use base 'Badger::Base';
    
    our $MESSAGES = {
        hai => 'Hello %s',
    };

    # subclass
    package Badger::Example::Two;
    use base 'Badger::Example::One';
    
    our $MESSAGES = {
        bye => 'Goodbye %s',
    };

    # using the classes
    package main;
    
    my $two = Badger::Example::Two->new();
    $two->message( hai => 'World' );    # Hello World
    $two->message( bye => 'World' );    # Goodbye World

The C<$two> object can use message formats defined in its
own package (C<Badger::Example::Two>) and also those of its base class
(C<Badger::Example::One>).

The messages are formatted using the L<xprintf()|Badger::Utils/xprintf()>
function in L<Badger::Utils>. This is a thin wrapper around the built-in
C<sprintf()> function with some additional formatting controls to simplify the
process of using positional arguments.

Messages are used internally by the L<error_msg()> and L<decline_msg()>
methods for generating error messages, but you can use them for any kind of
simple message generation.

There are a number of benefits to defining messages in a central repository
like this. 

First, it makes it easy to reuse the same message format in different places.
Also known as the "DRY" principle - I<Don't Repeat Yourself>.

Second, it allows you to put all your messages in one place instead of dotting
them all over your code. The benefit here is a clearer I<separation of
concerns> between the underlying logic of your application and the
presentational aspects.

The third benefit comes as a result of this clear separation - it becomes
trivially easy to change the messages generated by your application because
they're all defined in one place (possibly in several different modules if
that's how you choose to break it down, but at least they're in I<one> place
in each of those modules). Possible applications of this include: localising
an application to different spoken languages; generating messages in colour
(as the L<Badger::Debug> and L<Badger::Test> modules do); or formatting
messages as HTML.

=head2 warn_msg($message, @args)

This is a wrapper around the L<warn()> and L<message()> methods.
The first argument defines a message format.  The remaining arguments
are then applied to that format via the L<message()> method.  The
resulting output is then forwarded to the L<warn()> method.

    our $NAME     = 'Badger';
    our $MESSAGES = {
        using_default => "Using default value for %s: %s",
    };
    
    sub init {
        my ($self, $config) = @_;
        
        if ($config->{ name }) {
            $self->{ name } = $config->{ name };
        }
        else {
            $self->warn_msg( using_default => name => $NAME );
            $self->{ name } = $NAME;
        }
        
        return $self;
    }

If a C<name> isn't provided as a configuration parameter then the 
default C<$NAME> will be used and the following warning will be 
generated:

    Using default value for name: Badger

=head2 error_msg($message, @args)

This is a wrapper around the L<error()> and L<message()> methods,
similar to L<warn_msg()>.

    package Your::Zoo;
    use base 'Badger::Base';
    
    our $MESSAGES = {
        not_found => "I can't find the %s you asked for: %s",
    }
    
    sub animal {
        my ($self, $name) = @_;
        
        return $self->fetch_an_animal($name)
            || $self->error_msg( missing => animal => $name );
    }

Calling the C<animal()> method on this object with an animal that can't
be found, like this:

    $zoo->animal('Badgerpotamus');

Will generate an error message like this:

    your.zoo error - I can't find the animal you asked for: Badgerpotamus

=head2 decline_msg($message, @args)

This is a wrapper around the L<decline()> and L<message()> methods,
similar to L<warn_msg()> and L<error_msg()>.

    our $MESSAGES = {
        not_found => 'No %s found in the forest',
    };
    
    sub forage {
        my ($self, $name) = @_;
        
        return $self->database->fetch_item($name)
            || $self->decline_msg( not_found => $name );
    }

The L<reason()> method can be used to return the message generated.

    my $food = $forager->forage('nuts')
        || warn $forager->reason;       # No nuts found in the forest

=head2 fatal_msg($message, @args)

This is a wrapper around the L<fatal()> and L<message()> methods,
similar to L<error_msg()> and co.

=head2 throw($type, $info, %more_info)

This method throws an exception by calling C<die()>.  It can be called
with one argument, which can either be a L<Badger::Exception> object
(or subclass), or an error message which is upgraded to an exception
object (which makes it behave exactly the same as L<error()>).

    # error message - same thing as error()
    $object->throw('an error has occurred');
    
    # exception object
    $e = Badger::Exception->new( 
        type => 'engine',
        info => 'warp drive offline' 
    );
    $object->throw($e);

In the first case, the L<exception()> and L<throws()> methods will be 
called to determine the exception class (L<Badger::Exception> by default)
and type for the exception, respectively.

The method can also be called with two arguments. The first defines the
exception C<type>, the second the error message.

    $object->throw( engine => 'warp drive offline' );

The second argument can also be another exception object.  If the
exception has the same type as the first argument then it is re-thrown
unchanged.

    $e = Badger::Exception->new( 
        type => 'engine',
        info => 'warp drive offline' 
    );
    $object->throw( engine => $e ) };

In the example above, the C<$e> exception already has a type of C<engine> and
so is thrown without change.  If the exception types don't match, or if the
exception isn't the right kind of exception object that we're expecting
(as reported by L<exception()>) then a new exception is thrown with the 
old one attached via the C<info> field.

     $object->throw( propulsion => $e );

Here a new C<propulsion> exception is thrown, with the previous C<engine>
exception linked in via the C<info> field. The exception object has
L<type()|Badger::Exception/type()> and L<info()|Badger::Exception/info()>
methods that allow you to inspect its value, iteratively if necessary. Or you
can just print an exception and rely on its overloaded stringification
operator to call the L<text()|Badger::Exception/text()> method. For the error
thrown in the previous example, that would be:

    propulsion error - engine error - warp drive offline

=head2 throw_msg($type, $message, @args)

This is a wrapper around the L<throw()> and L<message()> methods for throwing
custom exceptions using message formats to generate the error information
string. The first argument defines the exception type. The second is the name
of the message format. The remaining arguments are uses to populate the
placeholders in the message format.

    our $MESSAGES = {
        offline => '%s is offline',
    };

    sub engage {
        my $self = shift;
        $self->throw_msg( warp => offline => 'warp drive' )
            unless $self->warp_drive_ready;
        # make it so
    }
    
    # throws the following exception:
    warp error - warp drive is offline

=head2 try($method, @args)

This method wraps another method call in an C<eval> block to catch any
exceptions thrown.

    my $result = $object->try( fetch => 'answer' ) || 42;

This example is equivalent to:

    my $result = eval { $object->fetch('answer') } || 42;

The error thrown can be retrieved using the C<reason()> method.

    my $result = $object->try( fetch => 'answer' )|| do {
        warn "Could not fetch answer: ", $object->reason;
        42;     # a sensible default
    };

If you call the C<try()> method without any arguments then it will return a
C<Badger::Base::Trial> object as a wafer thin wrapper around the original 
object.  Any methods called on this delegate object will be forwarded to 
the original object, wrapped up in an C<eval> block to catch any errors
thrown.

    my $result = $object->try->fetch('answer') ||= do { 
        ...
    };

=head2 catch($type, $method, @args)

TODO - this method depends on some code in L<Badger::Exception> which
I haven't written yet.

=head2 throws($type)

You can set the default exception type for L<throw()> by calling the
L<throws()> method with an argument, either as an object method (to affect
that object only) or as a class method (to affect all objects that don't set
their own value explicitly).  Note that the L<error()> and L<error_msg()>
methods call L<throw()> internally, so changing the exception type will
also affect the exceptions thrown by those methods.

    # object method
    $object->throws('food');
    $object->throw('No nuts');              # food error - No nuts
    $object->error('No nuts');              # food error - No nuts

    # class method
    Badger::Example->throws('food');
    Badger::Example->throw('No berries');   # food error - No berries
    Badger::Example->error('No berries');   # food error - No berries
    
    # all objects of this class now throw food by default
    my $badger = Badger::Example->new;
    $badger->throw('No cheese');            # food error - No cheese
    $badger->error('No cheese');            # food error - No cheese

You can also set this value for an object by passing a C<throws> 
configuration parameter to the L<new()> constructor method.

    my $badger = Badger::Example->new(
        throws => 'food',
    );

This relies on the default behaviour of the L<init()> method which stores
a reference to the original configuration parameters in C<$self-E<gt>{config}>.
If you want to use this feature then you should ensure that any specialised
L<init()> method you define does the same thing, or copies the C<throws>
value from C<$config> into C<$self-E<gt>{THROWS}>.

    # example 1: store entire config for later
    sub init {
        my ($self, $config) = @_;
        $self->{ config } = $config;
        # do other stuff
        return $self;
    }

    # example 2: extract specific parameter up front
    sub init {
        my ($self, $config) = @_;
        $self->{ THROWS } = $config->{ throws };
        # do other stuff
        return $self;
    }

You can set the default exception type for your own modules that inherit
from C<Badger::Base> by adding a C<$THROWS> package variable;

    package Badger::Example;
    use base 'Badger::Base';
    our $THROWS = 'food';

If you don't specify an exception type then one will be generated from 
the module's class name using the L<id()|Badger::Class/id()> method in
L<Badger::Class>.

=head2 exception($class)

This method can be used to get or set the exception class for an object.
The default value is L<Badger::Exception>. 

    use Badger::Example;
    use Some::Other::Exception;
    Badger::Example->exception('Some::Other::Exception');
    
    # now Badger::Example objects throw Some::Other::Exception

You can set the default exception class for your own modules that inherit
from C<Badger::Base> by adding a C<$EXCEPTION> package variable;

    package Badger::Example;
    use base 'Badger::Base';
    use Some::Other::Exception;
    our $EXCEPTION = 'Some::Other::Exception';

=head2 fatal($info, $more_info, ...)

This method is used internally to raise a fatal error.  It bypasses the 
normal error reporting mechanism and dies with a stack backtrace by calling 
C<confess()> (see L<Carp>).

The most common reason for a fatal error being raised is calling the
L<message()> method (or either of the L<error_msg()> or L<decline_msg()>
wrapper methods) with a message format that doesn't exist. The stack backtrace
will tell you where in your code you're making the call so you can easily find
and fix it.

=head2 not_implemented($what)

A method of convenience which raises an error indicating that the method
isn't implemented

    sub example_method {
        shift->not_implemented;
    }

Calling the C<example_method()> would result in an error message similar
to this (shown here split across two lines):

    your.badger.module error - example_method() is not implemented 
    for Your::Badger::Module in /path/to/your/script.pl at line 42

Note that it tells you where the C<example_method()> was called from,
not where the method is defined. 

The C<not_implemented()> method is typically used in methods defined in a base
classes that subclasses are expected to re-define (a.k.a. pure virtual methods
or abstract methods).

You can pass an argument to be more specific about what it is that 
isn't implemented.

    sub example_method {
        shift->not_implemented('in base class');
    }

The argument is added to the generated error message following the 
method name.  A single space is also added to separate them.

    your.badger.module error - example_method() is not implemented in
    base class for Your::Badger::Module in ...etc...

=head2 todo($what)

A method of convenience useful during developing to indicate that a method
isn't implemented yet.  It raises an error stating that the method is
still TODO.

    sub not_yet_working {
        shift->todo;
    }

The error message generated looks something like this:

    your.badger.module error - not_yet_working() is TODO in 
    Your::Badger::Module at line 42

You can pass an argument to be more specific about what is still TODO.

    sub not_yet_working {
        my ($self, $x) = @_;
        if (ref $x) {
            $self->todo('support for references');
        }
        else {
            # do something
        }
    }

The error message generated would then be:

    your.badger.module error - not_yet_working() support for 
    references is TODO in Your::Badger::Module at line 42

=head2 debug($msg1,$msg2,...)

This method is mixed in from the L<Badger::Debug> module. It provides a simple
way of generating debugging messages which include the source module and line
number where the message was generated.

    sub example {
        my $self = shift;
        $self->debug('entered example()');
        # ... some code ...
        $self->debug('leaving example()');
    }

=head2 debug_msg($message, @args)

This is a wrapper around the L<debug()> and L<message()> methods,
similar to L<warn_msg()>, L<error_msg()> and friends.

    our $MESSAGES = {
        here => 'You are in %s',
    };
    
    sub example {
        my $self = shift;
        
        $self->debug_msg( 
            here => 'a maze of twisty little passages, all alike' 
        ) if DEBUG;
        
        # ... some code ...
        
        $self->debug_msg( 
            here => 'boat, floating on a sea of purest green' 
        ) if DEBUG;
    }
    
=head2 debug_up($level,$msg1,$msg2,...)

Another debugging method mixed in from L<Badger::Debug>.  This is a wrapper
around L<debug()> which reports the file and line number of a caller 
higher up the call stack.  This is typically used when you create your
own debugging methods, as shown in the following example.


    sub parse {
        my $self = shift;
        
        while (my ($foo, $bar) = $self->get_foo_bar) {
            $self->trace($foo, $bar);               # report line here
            # do something
        }
    }
    
    sub trace {
        my ($self, $foo, $bar) = @_;
        $self->debug_up(2, "foo: $foo  bar: $bar"); # not here
    }

See L<Badger::Debug> for further details.

=head1 PACKAGE VARIABLES

The C<Badger::Base> module uses a number of package variables to control
the default behaviour of the objects derived from it.

=head2 $DEBUG

This flag can be set true to enable debugging in C<Badger::Base>.

    $Badger::Base::DEBUG = 1;

The C<Badger::Base> module does not use or define any C<$DEBUG> variable
in the subclasses derived from it.  However, you may want to do something
similar in your own modules to assist in debugging.

    package Your::Badger::Module;
    use base 'Badger::Base';
    
    # allow flag to be set before this module is loaded
    our $DEBUG = 0 unless defined $DEBUG;
    
    sub gnarly_method {
        my ($self, $item) = @_;
        $self->debug("gnarly_method($item)\n") if $DEBUG;
        # your gnarly code
    }

The C<Badger::Class> module defines the C<debug> method and import hook
which will automatically define a C<$DEBUG> variable for you.

    package Your::Badger::Module;
    
    use Badger::Class
        base  => 'Badger::Base',
        debug => 0;

=head2 $DECLINED

This package variable is defined in each subclass derived from
C<Badger::Base>. It is a boolean (0/1) flag used by the L<error()>,
L<decline()> and L<declined()> methods. The L<decline()> method sets it to
C<1> to indicate that the object declined a request. The L<error()> method
clears it back to C<0> to indicate that a hard error occurred. The
L<declined()> method simply returns the value.

=head2 $ERROR

This package variable is defined in each subclass derived from
C<Badger::Base>.  It stores the most recent error message raised
by L<decline()> or L<error()>.

=head2 $EXCEPTION

This package variable is used to define the name of the class
that should be used to instantiate exception objects.  The default
value in C<Badger::Base> is C<Badger::Exception>.

Subclasses may define an C<$EXCEPTION> package variable to change this
value.  

    package Your::Badger::Module;
    use base 'Badger::Base';
    use Your::Exception;
    our $EXCEPTION = 'Your::Exception';

Those that don't explicitly define an C<$EXCEPTION> will inherit the value
from any of their base classes, possibly coming all the way back up to the
default value in C<Badger::Base>.

Calling the C<exception()> class method with an argument will update the 
C<$EXCEPTION> package variable in that class.

    # sets $Your::Badger::Module::EXCEPTION
    Your::Badger::Module->exception('Your::Exception');

=head2 $MESSAGES

This package variable is used to reference a hash array of messages that can
be used with the L<message()>, L<warn_msg()>, L<error_msg()> and
L<decline_msg()> methods. The C<Badger::Base> module defines a number of
messages that it uses internally.


    our $MESSAGES = { 
        not_found       => '%s not found: %s',
        not_found_in    => '%s not found in %s',
        not_implemented => '%s is not implemented %s',
        no_component    => 'No %s component defined',
        bad_method      => "Invalid method '%s' called on %s at %s line %s",
        invalid         => 'Invalid %s specified: %s',
        unexpected      => 'Invalid %s specified: %s (expected a %s)',
        missing_to      => 'No %s specified to %s',
        missing         => 'No %s specified',
        todo            => '%s is TODO %s',
        at_line         => '%s at line %s',
        at_file_line    => '%s in %s at line %s',
    };

The L<message()> method searches for C<$MESSAGES> in the current class
and those of any base classes.  That means that any objects derived from
C<Badger::Base> can use these message formats.

    package Your::Badger::Module;
    use base 'Badger::Base';
    
    sub init {
        my ($self, $config) = @_;
        $self->{ name } = $config->{ name }
            || $self->error_msg( missing => $name );
        return $self;
    }

You can define additional C<$MESSAGES> for your own classes.

    package Your::Badger::Module;
    use base 'Badger::Base';
    
    our $MESSAGES = {
        life_jim  => "It's %s Jim, but not as we know it",
    }
    
    sub bones {
        my ($self, $thing)= @_;
        $self->warn_msg( life_jim => $thing );
        return $self;
    }

Calling the C<bones()> method like this:

    $object->bones('a badger');

will generate a warning like this:

    It's a badger Jim, but not as we know it.

=head2 $ON_ERROR

This package variable is used to define one or more error handlers
that will be invoked whenever the L<error()> method is called.

The C<Badger::Base> module doesn't define any C<$ON_ERROR> package
variable by default.  The L<on_error()> method can be called as a 
class method to set the C<$ON_ERROR> package variable.

    Your::Badger::Module->on_error(\&my_handler);

You can also define an C<$ON_ERROR> handler or list of handlers in 
your module.

    package Your::Badger::Module;
    use base 'Badger::Base';
    
    # one of the following...
    our $ON_ERROR = 'warn';         # call Perl's warn()
    our $ON_ERROR = 'method_name';
    our $ON_ERROR = \&code_ref;
    our $ON_ERROR = [ 'warn', 'method_name', \&code_ref ];
    
    # code refs get message as first argument
    sub code_ref {
        my $message = shift;
        # do something...
    }
    
    # methods get implicit $self, then message argument
    sub method_name {
        my ($self, $message) = @_;
        # do something...
    }

=head2 $ON_WARN

This package variable is used to define one or more error handlers
that will be invoked whenever the L<warning()> method is called.  It
works in exactly the same way as L<$ON_ERROR>.

=head2 $THROWS

This package variable is used to define the default exception type
thrown by the L<throw()> method (and L<error()> and L<error_msg()> which
call it indirectly).  It can be set by calling the L<throws()> class method.

    Your::Badger::Module->throws('food');

You can define C<$THROWS> in your own modules that are derived from
C<Badger::Base>.

    package Your::Badger::Module;
    use base 'Badger::Base';
    our $THROWS = 'food';

If the C<$THROWS> value is not defined in the current class or any of
an object's base classes, then the L<id()> method is used to construct
an identifier for the module to use instead.

=head1 OBJECT INTERNALS

The C<Badger::Base> module uses the following internal object items to
store information.

=head2 config

The default L<init()> method stores a reference to the hash array of
configuration parameters in the C<$self-E<gt>{config}> slot. If you're using
the default L<init()> method then your other methods can use this to lookup
configuration parameters lazily.

If you've defined your own L<init()> method then this item won't exist
unless your L<init()> method adds it explicitly.

=head2 DECLINED

The value of the declined flag, as per the L<$DECLINED> package variable.

=head2 ERROR

The last error raised, as per the L<$ERROR> package variable.

=head2 EXCEPTION

Used to store the class name that should used to instantiate exceptions.
Equivalent to the L<$EXCEPTION> package variable but operating on a per-object
basis. Can be inspected or modified by calling the L<exception()> object
method.

=head2 ON_ERROR

An internal list of handlers to call when an error is raised.  Equivalent 
to the L<$ON_ERROR> package variable but operating on a per-object basis.
Can be inspected or modified by calling the L<on_error()> object method.

=head2 ON_WARN

An internal list of handlers to call when a warning is raised.  Equivalent 
to the L<$ON_WARN> package variable but operating on a per-object basis.
Can be inspected or modified by calling the L<on_warn()> object method.

=head2 THROWS

Used to store the exception type that the object should throw.  Equivalent 
to the L<$THROWS> package variable but operating on a per-object basis.
Can be inspected or modified by calling the L<throws()> object method.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
