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
    version  => 3.00,
    debug    => 0,
    constant => { base_id => 'Badger' },
    import   => 'class classes',
    utils    => 'UTILS blessed reftype';

use Badger::Exception;
use Badger::Debug;

our $ERROR         = '';
our $EXCEPTION     = 'Badger::Exception' unless defined $EXCEPTION;
our $DEBUG_FORMAT  = "[<class> line <line>] <msg>" unless defined $DEBUG_FORMAT;
our $WARN_OUT_LOUD = 1;
our $MESSAGES      = { 
    not_found       => '%s not found: %s',
    not_found_in    => '%s not found in %s',
    not_implemented => '%s is not implemented in %s',
    no_component    => 'No %s component defined',
    bad_method      => "Invalid method '%s' called on %s at %s line %s",
    unexpected      => 'Invalid %s specified: %s (expected a %s)',
    missing         => 'No %s specified',
    todo            => '%s is TODO in %s',
};


sub new {
    my $class = shift;
    if ($DEBUG && ((@_ == 1 && ref $_[0] ne 'HASH') || (@_ > 2 and @_ % 2))) {
        # catch any "Odd number of elements..." warnings before they happen
        # so we can report where this method was called from.
        my ($pkg, $file, $line) = caller();
        $class->debug(
            "WARNING: odd number of elements passed to $class->new(", 
            join(', ', @_), ")\ncalled from $pkg in $file at line $line\n"
        );
    }
    my $args  = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };
    my $self  = bless { }, ref $class || $class;
    $self->init($args);
    return $self;
}

sub init {
    my $self = shift;
    $self->{ config } = shift;
    return $self;
}


#-----------------------------------------------------------------------
# id()
#
# Generates a lower case dotted representation of the class name, with
# the leading base_id() part ('Badger::' by default) removed.
# e.g. Badger::Example ==> 'example', Badger::Foo::Bar ==> foo.bar .
# Subclasses may redefine the base_id() (usually as a constant sub) to 
# strip off a different base part.  In the edge case where the current 
# class has the same type as its base_id() (e.g. Badger), then we return 
# the last component.
#-----------------------------------------------------------------------

sub id { 
    my $self = shift;
    my $pkg  = ref $self || $self;
    no strict 'refs';
    return ${"${pkg}::ID"} ||= do {
        my $base = $self->base_id;
        if ($base eq $pkg) {
            $pkg = $1 if  $pkg =~ /(\w+)$/;
        }
        else {
            $pkg =~ s/^${base}:://;
        }
        $pkg =~ s/::/./g;
        lc $pkg;
    };
}




#------------------------------------------------------------------------
# message($name, @args)
#
# Uses pkghash() to find a message format defined in the $MESSAGES hash 
# array in this package or any of the object's base classes.  It then
# passes the format through sprintf(), applying any additional arguments.
#------------------------------------------------------------------------

sub message {
    my ($self, $name, @args) = @_;

    my $format = $self->class->hash_value( MESSAGES => $name )
        || $self->fatal("message() called with invalid message type: $name");

    # accept numerical flags like %0 %1 %2 as well as %s
    my $n = 0;
    $format =~ s/%(?:(s)|(\d+))/$1 ? $args[$n++] : $args[$2]/ge;
    return $format;
}


#------------------------------------------------------------------------
# decline($reason, $more_reasons, ...)
# 
# General purpose method used to decline a request of some kind.  Joins
# all the arguments into a single string and stores it in the internal 
# ERROR item to be accessed via the error() method.  Also sets the 
# internal DECLINED flag and then returns undef.
#------------------------------------------------------------------------

sub decline {
    my $self  = shift;
    my $class = ref $self || $self;
    my $reason = join('', @_);
    no strict 'refs';
    no warnings;
    
    ${"$class\::ERROR"   } = $reason;
    ${"$class\::DECLINED"} = 1;

    if (reftype $self eq 'HASH') {
        $self->{ ERROR    } = $reason;
        $self->{ DECLINED } = 1;
    }

    return undef;
}


#------------------------------------------------------------------------
# decline_msg()
# 
# Like error_msg(), this calls message() to format the arguments and
# passes the result onto decline()
#------------------------------------------------------------------------

sub decline_msg {
    my $self = shift;
    $self->decline($self->message(@_));
}


#------------------------------------------------------------------------
# declined()
#
# Returns the value of DECLINED, set by decline().
#------------------------------------------------------------------------

sub declined {
    my $self  = shift;
    my $class = ref $self || $self;
    no strict 'refs';
    return ref $self
        ? $self->{ DECLINED }
        : ${"$class\::DECLINED"};
}


#------------------------------------------------------------------------
# error()
# error($msg1, $msg2, $msg3, ...)
#
# Returns current error when called without args.  When called with 
# args they are concatenated to define a new error string which is set
# in the object ERROR item and/or the $ERROR package variable.  A 
# single reference argument (e.g. an exception object) can be passed
# as an argument.  This is used as is without being first stringified.
# If the THROWS item is set then the error is thrown via throw().
#------------------------------------------------------------------------

sub error {
    my $self  = shift;
    my $class = ref $self || $self;
    no strict 'refs';

    if (@_) {
        # don't stringify objects passed as argument
        my $error = ref $_[0] ? shift : join('', map { defined($_) ? $_ : '' } @_);
        my ($handlers, $throws);

        # set package variable
        ${"$class\::ERROR"} = $error;
        ${"$class\::DECLINED"} = 0;

        if (ref $self && reftype $self eq 'HASH') {
            # set ERROR and DECLINED items in object
            $self->{ ERROR    } = $error;
            $self->{ DECLINED } = 0;

            # look for error handlers and throw type in object config, then package
            $handlers = exists $self->{ config }->{ on_error }
                ? $self->{ config }->{ on_error }
                : $class->class->var('ON_ERROR');

            $throws = $self->throws || $class->id;
        }
        else {
            # look in package for error handlers and throw type
            $handlers = $class->class->var('ON_ERROR');
            $throws   = $class->throws || $class->id;
        }

        if ($handlers) {
            # trigger any ON_ERROR handlers
            foreach my $handler (@$handlers) {
                if (ref $handler eq 'CODE') {
                    &$handler($error);
                }
                else {
                    $self->fatal("Invalid ON_ERROR handler: $handler");
                }
            }
        }
        $self->throw($throws, $error);
    }
    elsif (ref $self) {
        return $self->{ ERROR };
    }
    else {
        return ${"$class\::ERROR"};
    }
}


#------------------------------------------------------------------------
# error_msg($code, @args)
#
# Calls error() having first passed argument through message()
#------------------------------------------------------------------------

sub error_msg {
    my $self = shift;
    $self->error($self->message(@_));
}


#-----------------------------------------------------------------------
# on_error(sub { # do this... })
#-----------------------------------------------------------------------

sub on_error {
    my $self = shift;
    no strict 'refs';
    my $list = ref $self 
        ? $self->{ config }->{ on_error } ||= [ ]
        : ${"$self\::ON_ERROR"} ||= [ ];
        
    while (@_) {
        my $handler = shift;
        # TODO: allow handler to be a method name, but then we need to pass $self
        # to it in error().  
        #$handler = $self->can($handler) ||
        $self->fatal("Invalid on_error handler: $handler") 
            unless ref $handler eq 'CODE';
        push(@$list, $handler);
    }

    return $list;
}


#-----------------------------------------------------------------------
# reason()
#
# Return the reason (i.e. the message) for the most recent error or 
# decline.  Does the same thing as calling error() without arguments.
#-----------------------------------------------------------------------

sub reason {
    my $self  = shift;
    my $class = ref $self || $self;
    my $type  = reftype $self || '';
    no strict 'refs';
    return $type eq 'HASH'
         ? $self->{ ERROR }
         : ${"$class\::ERROR"};
}


#------------------------------------------------------------------------
# exception($error)
# exception($type, $error)
# exception($type, $error, @args)
#
# Create an exception object from the arguments provided, using various 
# heuristics to Do The Right Thing when $type and/or $error are already 
# exception objects.
#------------------------------------------------------------------------

sub exception {
    my $self = shift;
    my $type = shift;
#    local $DEBUG = 1;
#    $self->debug("enabled debug\n");

    if (@_) {
        my $info   = shift;
        my $config = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };

        if (blessed $info && $info->isa($EXCEPTION) && $info->type() eq $type) {
            # second argument is already an exception of type $type
            return $info;
        }
        else {
            # construct a new exception from $type and $info fields
            $config->{ type } = $type;
            $config->{ info } = $info;
            $self->debug("creating new exception object: ", $self->dump_hash($config), "\n") if $DEBUG;
            return $EXCEPTION->new($config);
        }
    }
    else {
        # single argument can be an exception object or an error message
        if (blessed $type && $type->isa($EXCEPTION)) {
            $self->debug("returning exception object: ", ref $type, " => $type\n") if $DEBUG;
            return $type;
        }
        else {
            $self->debug("creating new exception object chain: info => $type\n") if $DEBUG;
            return $EXCEPTION->new( info => $type );
        }
    }
    # not reached
}


#------------------------------------------------------------------------
# throw($error)
# throw($type, $error)
# throw($type, $error, @args)
#------------------------------------------------------------------------

sub throw {
    my $self = shift;
#    $self->debug("throw(", join(', ', @_), ")\n");
    die $self->exception(@_);
}

sub throws {
    my $self  = shift;
    my $type  = ref $self ? reftype $self : '';
    my $class = ref $self || $self;
    my $throws;
    no strict 'refs';
    
    if (@_) {
        $throws = $type eq 'HASH'
            ? ($self->{ config }->{ throws } = shift)
            : (${"${class}::THROWS"} = shift);
    }
    elsif ($type eq 'HASH') {
        $throws = $self->{ config }->{ throws };
    }
    return $throws || $self->class->any_var('THROWS');
}


#-----------------------------------------------------------------------
# fatal($error)
#
# Reserved for those special occasions when things have really gone tits 
# up.  We die with a stack backtrace.
#-----------------------------------------------------------------------

sub fatal {
    my $self  = shift;
    my $class = ref $self || $self;
    my $error = join('', @_);
    no strict 'refs';

    # set package variable
    ${"$class\::ERROR"} = $error;

    if (reftype $self eq 'HASH') {
        $self->{ ERROR } = $error;
        $self->{ DECLINED } = 0;
    }

    require Carp;
    Carp::confess("fatal error: ", @_);
}


#-----------------------------------------------------------------------
# not_implemented()
#
# Method of convenience for throwing a "Not Yet Implemented" complete
# with source code location.
#-----------------------------------------------------------------------

sub not_implemented {
    my $self = shift;
    # optional first argument is a hash ref of caller info (for Badger::Methods)
    #my $call = @_ && ref $_[0] eq 'Array' ? shift : [ caller(0) ];
    my $ref = ref $self || $self;
    my ($pkg, $file, $line, $sub) = caller(0);
    $sub = (caller(1))[3];   # report the subroutine that not_implemented() was called from
    $sub =~ s/(.*):://;
    my $msg  = @_ ? join('', ' ', @_) : '';
    return $self->error_msg( not_implemented => "$sub()$msg", "for $ref in $file at line $line" );
}


#-----------------------------------------------------------------------
# todo()
#
# Method of convenience for throwing a "TODO" error complete
# with source code location.
#-----------------------------------------------------------------------

sub todo {
    my $self = shift;
    my ($pkg, $file, $line, $sub) = caller(0);
    $sub = (caller(1))[3];   # report the subroutine that not_implemented() was called from
    $sub =~ s/(.*):://;
    my $msg  = @_ ? join('', ' ', @_) : '';
    return $self->error_msg( todo => "$sub()$msg", "$pkg at line $line" );
}


#-----------------------------------------------------------------------
# debug($msg, $msg, etc)
#
# Generate a debug message.
#-----------------------------------------------------------------------

sub debug {
    my $self   = shift;
    my $msg    = join('', @_),
    my $class  = ref $self || $self;
    my $format = $DEBUG_FORMAT;     #  $self->pkgvar('DEBUG_FORMAT');
    my ($pkg, $file, $line) = caller();
    $class .= " ($pkg)" unless $class eq $pkg;
    my $data = {
        msg   => $msg,
        class => $class,
        file  => $file,
        line  => $line,
    };
    $format =~ s/<(\w+)>/defined $data->{ $1 } ? $data->{ $1 } : "<$1 undef>"/eg;
    print $format;
}



#------------------------------------------------------------------------
# warning()
# warning($msg1, $msg2, $msg3, ...)
#
# Similar to error(), above, but allows multiple (non-fatal) warnings to 
# be raised by pushing them onto an internal list.  Returns a reference
# to a list of warnings when called without arguments.
#------------------------------------------------------------------------

sub warning {
    my $self = shift;
    my $class = ref $self || $self;
    my $warnings;

    no strict 'refs';

    if (@_) {
        # don't stringify objects passed as argument
        my $message = ref $_[0] ? shift : join('', @_);

        if (ref $self) {
            # add to object internal list
            $warnings = $self->{ WARNINGS } ||= [ ];
            push(@$warnings, $message);
        }
        else {
            # add to package list
            $warnings = ${"$class\::WARNINGS"} ||= [ ];
            push(@$warnings, $message);
        }
        # TMP hack for testing/debugging
        warn $message, "\n"
            if $WARN_OUT_LOUD;        # TODO make this optional/handler
        return undef;
    }
    elsif (ref $self) {
        return $self->{ WARNINGS } ||= [ ];
    }
    else {
        return ${"$class\::WARNINGS"} ||= [ ];
    }
}


#------------------------------------------------------------------------
# warnings()
# warnings($warning1, $warning2, ...)
#
# Forwards each of any arguments passed to the warning() method.
# Returns the current list of warnings when called without arguments.
#------------------------------------------------------------------------

sub warnings {
    my $self = shift;
    
    if (@_) {
        # pass separate arguments on to $self->warning()
        foreach my $msg (@_) {
            $self->warning($msg);
        }
        return 0;
    }
    else {
        my $warnings = $self->warning();
        return @$warnings;
    }
}



    


1;
__END__

=head1 NAME

Badger::Base - base class module

=head1 SYNOPSIS

    # define a subclass of Badger::Base
    package My::Badger::Module;
    use base 'Badger::Base';

    # define init() method for initialisation
    sub init {
        my ($self, $config) 
        
        # $config is a hash of named parameters
        $self->{ name } = $config->{ name } 
            || return $self->error('no name specified');
    
        # return $self to indicate success
        return $self;
    }
    
    # rest of the module follows...
    
    package main;
    
    # using the module
    my $object = My::Badger::Module->new( name => 'thingy' )

=head1 DESCRIPTION

This module implements a base class object from which most of the other
C<Badger> modules are derived. It implements a number of methods to aid
in object creation and configuration, error reporting, and debugging.

=head1 METHODS

=head2 new(\%config)

This is a general purpose constructor method.  It accepts either a
reference to a hash array of named parameters (or an object derived
from a hash array), or a list of named parameters which are then
folded into a hash reference.

    # hash reference of named params
    my $object = My::Badger::Module->new({
        arg1 => 'value1',
        arg2 => 'value2',
        ...etc...
    });
    
    # list of named params
    my $object = My::Badger::Module->new(
        arg1 => 'value1',
        arg2 => 'value2',
        ...etc...
    );

The constructor creates a new object by blessing a hash reference
and then calls the C<init()> method, passing the reference to the 
hash array of named parameters.  

The C<new()> method returns whatever the C<init()> method returns
(usually the C<$self> reference, but it can actually be something
else).  If C<init()> doesn't return a true value then the C<new()>
method will return C<undef>.  The C<error()> method can then be 
called to determine the cause of the problem.

    my $object = My::Badger::Module->new()
        || die My::Badger::Module->error();

Constructor errors can also be examined via the C<$ERROR> package
variable.  Note that this is in the package of the subclass module
rather than Badger::Base.

    my $object = My::Badger::Module->new()
        || die $My::Badger::Module::ERROR;

=head3 Configuration Options

The following configuration options are provided by default for 
all objects derived from the Badger::Base module that inherit
its C<new()> method.

=head4 debug

A flag to enable debugging for this object.  Sets an internal
C<DEBUG> flag to the value provided, or uses the default value
set in the C<$DEBUG> package variable.

    my $object = My::Badger::Module->new( debug => 1 );

    # alternately, set $DEBUG package variable
    $My::Badger::Module::DEBUG = 1;

    # debugging now enabled by default
    my $object = My::Badger::Module->new();

    # explicitly disable debugging on a per-object basis
    my $object = My::Badger::Module->new( debug => 0 );

=head4 throws

This option can be set to cause the object to throw as exceptions any
and all errors raised by calls to the C<error($msg)> method.  A
Badger::Exception object is created (or an object of whatever class
is defined in the C<$EXCEPTION> package variable) with its C<type>
set to the value of the C<throws> parameter and C<info> field containing
the error message passed to the C<error($msg)> method.

    my $object = My::Badger::Module->new( throws => 'wibble' );

    $object->error('wibble is wobbling');

In the preceding example, the call to the C<error()> method 
results in an exception object being throw via die with a C<type>
of C<wibble> and C<info> set to C<wibble is wobbling>.

See the C<error()> and C<throw()> methods for further details.

=head2 init(\%config)

This initialisation method is called by the C<new()> constructor method.
It is passed a reference to a hash array of named parameters.  The
method may perform any configuration or initialisation processes and
should then return the C<$self> reference to inidicate success.

    sub init {
        my ($self, $config) = @_;
    
        # set the 'answer' parameter or default to 42
        $self->{ answer } = $config->{ answer } || 42;
        
        return $self;
    }

The C<init()> method can actually return any true value.  Whatever
it returns is what gets passed back to the user from the C<new()>
method.  That's why you nearly always want to pass C<$self> back.
However, there are certain cases (e.g. plugins) where object 
constructors don't return an object at all, just something that is
constructed like one.

If something goes wrong in the C<init()> method then you should 
call the C<error()> method and return C<undef>.  The C<error()>
method returns C<undef> when you pass it an argument, so you
can use it as follows:

    sub init {
        my ($self, $config) = @_;
    
        # set the 'answer' parameter or report error
        $self->{ answer } = $config->{ answer }
            || return $self->error('no answer supplied');
        
        return $self;
    }

=head2 error()

The C<error()> method is used for error reporting.  When an object method
fails for some reason, it calls the C<error()> method passing an argument
denoting the problem that occurred.  It then returns, passing back the 
return value from the error() method (typically C<undef>, but see the 
C<throw> option discussed below).

    sub engage {
        my $self = shift;
        return $self->error('warp drive offline');
    }

Multiple arguments can be passed to the C<error()> method.  They are 
concatenated into a single string.

    sub engage {
        my $self = shift;
        return $self->error( 'warp drive number ', 
                             $self->{ engine_no }, 
                             ' is offline' );
    }

When the C<engage()> method is called, the C<undef> value returned
indicates that an error has occurred.  The C<error()> method can then
be called again, this time without any arguments, to retrieve the
error message.

    $object->engage()
        || die $object->error();  # warp drive number 3 is offline

An exception object can also be passed as a single argument to the 
error method.  In this case, the object is not "stringified" and is
stored internally as it is.

The C<error()> method can also be called as a class method.  In this
case, it updates and retrieves the C<$ERROR> package variable in the 
package of the subclass module.

    # calling package error() method
    my $object = My::Badger::Module->new()
        || die My::Badger::Module->error();
    
    # accessing $ERROR package variable
    my $object = My::Badger::Module->new()
        || die $My::Badger::Module::ERROR;

If an object defines a C<throws> item or if the C<$THROWS> package
variable is defined for the subclass, then the C<error()> method will
call the C<throw()> method to throw the error as an exception instead
of simply returning undef.  The value of the C<throws> item or
C<$THROWS> variable is used to define the exception type, with the error
message providing the additional information.

Here's an example showing how the C<throws> option can be set as
a constructor option.

    my $frob = My::Badger::Frobulator->new( throws => 'frob' );

Now when we call a method that raises an error via the C<error()> method,
it will be thrown as a Badger::Exception object using Perl's die() 
function.

    $frob->something_that_generates_an_error();

It doesn't hurt to add the code to check if the method returns undef.
That way, your code will do the right thing regardless of how the
object error handling is defined.

    $frob->something_that_generates_an_error()
        || die $frob->error();

Here's an example showing the C<$THROWS> package variable being set
for a module.

    package My::Badger::Frobulator;
    use base 'Badger::Base';

    our $THROWS = 'frob';
    
    sub something_that_generates_an_error {
        my $self = shift;
        return $self->error('The sky has fallen in');
    }

Now when we create a My::Badger::Frobulator object, it's as if the
C<throws> option is set by default.

    # errors thrown as exceptions by default
    my $frob = My::Badger::Frobulator->new();

If you want to disable the default behaviour defined by C<$THROWS> then
provide an explicit value for C<throws> as a constructor option.  This
can be set to C<undef> to provide the default (i.e. non-throwing)
behaviour, or can define a different exception type.

    # errors return undef
    my $frob = My::Badger::Frobulator->new( throws => undef );
   
    # error thrown as 'frobless'
    my $frob = My::Badger::Frobulator->new( throws => 'frobless' );

=head2 error_msg($message, @args)

This is a wrapper around the C<error()> and message() methods. 

    our $MESSAGES = {
        missing => 'missing %s in template',
    }
    
    sub foo {
        my $self = shift;
    
        return $self->error_msg( missing => 'foo' )
            unless ... # some code
    }

The above example showing the call to error_msg() is equivalent 
to the following code.

        return $self->error('missing foo in template')
            unless ... # some code

=head2 throw()

This method throws an exception by calling C<die()>.  It can be called
with one argument, which can either be a Badger::Exception object
(or subclass), or an error message which is upgraded into an exception
with the type set to C<'undef'> (that's the literal string C<"undef">
rather than the undefined value).

    # error message 
    $object->throw('an error has occurred');
    
    # exception object
    $e = Badger::Exception->new( type => 'engine',
                                   info => 'warp drive offline' );
    $object->throw($e);

It can also be called with two arguments.  The first defines the
exception C<type>, the second the C<type> which provides an error
message or other information relevant to the exception.

    $object->throw( engine => 'warp drive offline' );

The second argument can also be a Badger::Exception object.  If the
exception has the same type as the first argument, then it is left
unchanged and is thrown as is.  

    eval { $object->throw( engine => $e ) };
    print "$@\n";

In the example above, the C<$e> exception already has a type of
C<engine> and so is thrown without change.  By enclosing the call to
C<throw()> in an C<eval> block, we can catch the exception thrown in
C<$@> and print it, causing its C<text()> method to be called (thanks
to an overloaded stringification operator).  This results in the
following output:

    engine error - warp drive offline

If on the other hand we request that a C<propulsion> error is 
throw:

    eval { $object->throw( propulsion => $e );

Then instead we get a new C<propulsion> exception throw, with the 
previous C<engine> exception linked in via the C<info> field.
This generates the following output:

    propulsion error - engine error - warp drive offline

By this mechanism, exceptions can be nested inside each other to
allow as much (or as little) information about the cause of an
error to be recorded.

=head2 warning()

This method is very similar to C<error()> described above.  However,
while an object can only report one error at any time (we assume that 
an error is a "fatal" condition which requires the object to return 
right away), it can report any number of non-fatal warnings.  The 
C<warning()> method maintains a list of warnings inside the object
or in the C<$WARNINGS> package variable (a reference to a list) when 
called as a class method.

When called with arguments, the C<warning()> method concatentates 
them into a single string and adds it to the current warnings list.

    sub disengage {
        my $self = shift;
    
        $self->warning('warp drive already offline')
            unless $self->{ engaged };
    
        # ...etc...
    
        return 1;
    }

When called in this way, the C<warning()> method returns C<0> (in contrast
to the C<error()> method which returns C<undef>).  So you might choose
to write your method like this:

    sub disengage {
        my $self = shift;
    
        return $self->warning('warp drive already offline')
            unless $self->{ engaged };
    
        # ...etc...
    
        return 1;
    }

And call it like this:

    defined $object->disengage()
        || die $object->error();

When you call the warning() method without any arguments, it returns
a reference to a list of current warnings.

    my $warnings = $object->warning();
    
    if (@$warnings) {
        warn "warning while disengaging warp drive: ", @$warnings;
    }

Please be aware that the C<warnings()> method isn't currently used by
any Badger Toolkit objects and may be deprecated or modified in
future versions.

=head2 warnings()

When called with arguments, this method calls the C<warning()> method once
for each argument.  Thus the following examples are equivalent.

    # single call to warnings()
    $object->warnings('foo', 'bar', 'baz');
    
    # multiple calls to warning()
    $object->warning('foo');
    $object->warning('bar');
    $object->warning('baz');

When called without arguments, the C<warnings()> method returns a 
list of warnings (rather than the reference to a list of warnings 
that C<warning()> returns).

    if ($object->warnings()) {
        die "warning while disengaging warp drive: ", 
            $object->warnings();
    }

As with C<warning()>, this method isn't currently used and is subject
to change or deprecation in future versions.

=head2 decline($reason, $more_reasons, ...)

The C<decline()> method is used to generate a return value and internal
state indicating that a method could not perform its task, but did not
incur an error.  This is typically used by methods which fetch and return
a resource, decline if it cannot be found, or raise an error if something
went seriously wrong.

    sub get_thing {
        my ($self, $name) = @_;
    
        # hard error if database isn't connected
        my $db = $self->{ database }
            || return $self->error('no database')
    
        if ($thing = $database->fetch_thing($name)) {
            # return true value on success
            return $thing;
        }
        else {
            # soft decline if not found
            return $self->decline("thing not found: $name")
        }
    }

The C<decline()> method concatentates all arguments into a single
string, stores it internally, and then returns C<undef>.  The string
should indicate a reason for declining a request (e.g. C<"thing not
found: $name">) and can be subsequently retrieved via the
C<declined()> method.

=head2 declined()

Returns the reason for declining a request, as set by the most recent call
to C<decline()>.

=head2 debug($msg1, $msg2, ...)

Method for debugging.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

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
