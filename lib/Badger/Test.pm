package Badger::Test;

use Carp;
use Badger::Class
    version   => 0.01,
    base      => 'Badger::Base',
    import    => 'CLASS class',
    constants => 'ARRAY DELIMITER PKG',
    constant  => { DEBUG => 'DEBUG' },
    exports   => {
        all   => 'plan ok is isnt like unlike pass fail', # skip todo skip_rest 
        hooks => {
            debug => \&debug_hook,
            map { $_ => \&export_hook }
            qw( manager colour color args tests )
        },
    };

use Badger::Test::Manager;
our $MANAGER = 'Badger::Test::Manager';
our ($DEBUG, $DEBUGGING);

*color = \&colour;

sub export_hook {
    my ($class, $target, $key, $symbols) = @_;
    croak "You didn't specify a value for the '$key' load option"
        unless @$symbols;
    $class->$key(shift @$symbols);
}

sub debug_hook {
    my ($class, $target, $key, $symbols, $import) = @_;
    croak "You didn't specify any values for the 'debug' load option.\n" 
        unless @$symbols;

    # define $DEBUG in caller
    no strict 'refs';
    *{ $target.PKG.DEBUG } = \$DEBUGGING;

    # set $DEBUG in this class to contain the argument passed - a list
    # of class names to enable $DEBUG in when/if debugging is enabled
    my $value = shift @$symbols;
    return unless $value;           # zero/false for no debugging
    $class->debug($value);
}

sub manager {
    my $class = shift;
    return @_
        ? ($MANAGER = shift)
        :  $MANAGER;
}

sub colour {
    shift;
    manager->colour(@_);
}

sub args {
    my $self = shift;
    my $args = @_ && ref $_[0] eq ARRAY ? shift : [ @_ ];
    my $arg;
    
    # quick hack until Badger::Config is done
    while (@$args && $args->[0] =~ /^-/) {
        $arg =  shift @$args;
        if ($arg =~ /^-c|--colou?r/) {
            $self->colour(1);
        }
        elsif ($arg =~ /^-d|--debug/) {
#            $arg = @$args && $args->[0] !~ /^-/ ? shift : 1;
#            $self->debugging($arg);
            $self->debugging(1);
        }
        else {
            last;
        }
     }  
}

sub tests {
    shift; 
    plan(@_);
}

sub debug {
    my $self = shift;
    $self->class->var( DEBUG => shift );
}

sub debugging {
    my $self  = shift;
    my $flag  = shift || 1;
    my $debug = $self->class->var('DEBUG');
    $debug = [ split(DELIMITER, $debug) ] unless ref $debug eq ARRAY;
    
    foreach my $pkg (@$debug) {
        class($pkg)->var( DEBUG => $flag );
    }
    $DEBUGGING = $flag;
}

class->methods(
    plan   => sub ($;$)  { manager->plan(@_)   },
    ok     => sub ($;$)  { manager->ok(@_)     },
    is     => sub ($$;$) { manager->is(@_)     },
    isnt   => sub ($$;$) { manager->isnt(@_)   },
    like   => sub ($$;$) { manager->like(@_)   },
    unlike => sub ($$;$) { manager->unlike(@_) },
    pass   => sub (;$)   { manager->pass(@_)   },
    fail   => sub (;$)   { manager->fail(@_)   },
);


1;

__END__

=head1 NAME

Badger::Test - test module

=head1 SYNOPSIS

    use Badger::Test
        tests => 7,
        debug => 'My::Badger::Module Your::Badger::Module',
        args  => \@ARGV;
    
    # -d in @ARGV will enable $DEBUG for My::Badger::Module 
    # and Your::Badger::Module.  -c will enable colour mode.
    #  e.g. $ perl t/test.t -d -c
    
    ok( $bool, 'Test passes if $bool true' );
    
    is( $one, $two, 'Test passes if $one eq $two' );
    isnt( $one, $two, 'Test passes if $one ne $two' );
    
    like( $one, qr/regex/, 'Test passes if $one =~ /regex/' );
    unlike( $one, qr/regex/, 'Test passes if $one !~ /regex/' );
    
    pass('This test always passes');
    fail('This test always fails');

=head1 DESCRIPTION

This module implements a simple test framework in the style of
L<Test::Simple> or L<Test::More>.  As well as the usual L<plan()>,
L<ok()>, L<is()>, L<isnt()> and other methods you would expect to
find, it also implements a number of export hooks to enable certain
Badger-specific features.

=head1 CLASS METHODS

=head2 tests()

This class method can be used to set the number of tests.  It does the
same thing as the C<plan()> function.

    Badger::Test->tests(42);

=head2 manager()

Method to get or set the name of the backend test manager object class
defined in C<$MANAGER>.

    # defining a custom manager class
    Badger::Test->manager('My::Test::Manager');

=head2 colour()

Method to enable or disable colour output.

    Badger::Test->colour(1);        # enable
    Badger::Test->colour(0);        # disable

=head2 color()

An alias for L<colour()>.


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

=head2 $DEBUG_FORMAT

The L<debug()> method uses the message format in the C<$DEBUG_FORMAT>
package variable to generate debugging messages.  The default value is:

    [<class> line <line>] <msg>

The C<E<lt>classE<gt>>, C<E<lt>lineE<gt>> and C<E<lt>msgE<gt>> markers
denote the positions where the class name, line number and debugging 
message are inserted.

The C<Badger::Class> module doesn't define or use any C<$DEBUG_FORMAT>
package variable in classes derived from it.

NOTE: the L<debug()> method and C<$DEBUG_FORMAT> variable are probably
going to be moved to L<Badger::Debug>.

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

Those that don't will inherit any defined value of the C<$EXCEPTION> package
variable in any their base classes, possibly coming all the way back up to the default
value in C<Badger::Base>.

Calling the C<exception()> class method with an argument will update the 
C<$EXCEPTION> package variable in that class.

    # sets $Your::Badger::Module::EXCEPTION
    Your::Badger::Module->exception('Your::Exception');

=head2 $ID

This package variable can be defined to provide a default identifier
for the class.  This is used as the default exception type for errors
raised via the L<error()> and L<error_msg()> methods (and L<throw()>
when called with a single message argument).  The default value for 
each class is returned by the L<id()> method.

    package Your::Badger::Module;
    use base 'Badger::Base';
    our $ID = 'YBM';

    package main;
    Your::Badger::Module->error('Fail!')    # YBM error - Fail!

Calling the C<id()> method with an argument will update the C<$ID> package
variable in that class.

    # sets $Your::Badger::Module::ID
    Your::Badger::Module->id('BadgerMod');

=head2 $MESSAGES

This package variable is used to reference a hash array of messages that
can be used with the L<message()>, L<error_msg()> and L<decline_msg()> 
methods.  The C<Badger::Base> module defines a number of messages that
it uses internally.

    our $MESSAGES = { 
        not_found       => '%s not found: %s',
        not_found_in    => '%s not found in %s',
        not_implemented => '%s is not implemented %s',
        no_component    => 'No %s component defined',
        bad_method      => "Invalid method '%s' called on %s at %s line %s",
        unexpected      => 'Invalid %s specified: %s (expected a %s)',
        missing_to      => 'No %s specified to %s',
        missing         => 'No %s specified',
        todo            => '%s is TODO %s',
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
configuration parameters in the C<$self->{ config }> slot. If you're using the
default L<init()> method then your other methods can use this to lookup
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
