#========================================================================
#
# Badger::Debug
#
# DESCRIPTION
#   Mixin module implementing functionality for debugging.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Debug;

use Carp;
use Badger::Rainbow 
    ANSI => 'bold red yellow green cyan white';
use Scalar::Util 'blessed';
use Badger::Class
    base      => 'Badger::Exporter',
    version   => 0.01,
    constants => 'PKG REFS SCALAR ARRAY HASH CODE REGEX DELIMITER',
    words     => 'DEBUG',
    import    => 'class',
    constant  => {
        UNDEF => '<undef>',
    },
    exports   => {
        tags  => {
            debug => 'debugging debug debug_up debug_caller debug_args',
            dump  => 'dump dump_data dump_data_inline
                      dump_ref dump_hash dump_list dump_text'
        },
        hooks => {
            color    => \&enable_colour,
            colour   => \&enable_colour,
            dumps    => [\&_export_debug_dumps,    1],  # expects 1 arguments
            default  => [\&_export_debug_default,  1],
            modules  => [\&_export_debug_modules,  1],
            'DEBUG'  => [\&_export_debug_constant, 1],
            '$DEBUG' => [\&_export_debug_variable, 1],
        },
    };
    
our $PAD       = '    ';
our $MAX_TEXT  = 48;
our $MAX_DEPTH = 3;     # prevent runaways in debug/dump
our $FORMAT    = "[<class> line <line>] <msg>"  
    unless defined $FORMAT;
our $CALLER_UP = 0;     # hackola to allow debug() to use a different caller
our $DEBUG     = 0 unless defined $DEBUG;


#-----------------------------------------------------------------------
# export hooks
#-----------------------------------------------------------------------

sub _export_debug_dumps {
    my ($self, $target, $symbol, $value, $symbols) = @_;
    $self->export_symbol($target, dumper => sub {
        $_[0]->dump_hash($_[0],$_[1],$value);
    });
    unshift(@$symbols, ':dump');
    return $self;
}


sub _export_debug_default {
    my ($self, $target, $symbol, $value, $symbols) = @_;
    unshift(
        @$symbols, 
        '$DEBUG' => $value, 
         'DEBUG' => $value,
         'debug', 
         'debugging'
    );
    return $self;
}


sub _export_debug_variable {
    my ($self, $target, $symbol, $value) = @_;
    no strict REFS;

    # use any existing value in $DEBUG
    $value = ${ $target.PKG.DEBUG }
        if defined ${ $target.PKG.DEBUG };
        
    $self->debug("$symbol option setting $target \$DEBUG to $value\n") if $DEBUG;
    *{ $target.PKG.DEBUG } = \$value;
}


sub _export_debug_constant {
    my ($self, $target, $symbol, $value) = @_;
    no strict REFS;

    # use any existing value in $DEBUG
    $value = ${ $target.PKG.DEBUG }
        if defined ${ $target.PKG.DEBUG };
    
    $self->debug("$symbol option setting $target DEBUG to $value\n") if $DEBUG;
    *{ $target.PKG.DEBUG } = sub () { $value };
}


sub _export_debug_modules {
    my ($self, $target, $symbol, $modules) = @_;
    $self->debug_modules($modules);
}


#-----------------------------------------------------------------------
# exportable debugging methods
#-----------------------------------------------------------------------

sub debugging {
    my $self = shift;
    my $pkg  = ref $self || $self;
    no strict REFS;

    # return current $DEBUG value when called without args
    return ${ $pkg.PKG.DEBUG } || 0
        unless @_;
    
    # set new debug value when called with an argument
    my $debug = shift;
    $debug = 0 if $debug =~ /^off$/i;

    # TODO: consider setting different parts of the flag, like TT2, 

    $self->debug("debugging() Setting $pkg debug to $debug\n") if $DEBUG;
    
    if (defined ${ $pkg.PKG.DEBUG }) {
        # update existing variable
        ${ $pkg.PKG.DEBUG } = $debug;
    }
    else {
        # define new variable, poking it into the symbol table using
        # *{...} rather than ${...} so that it's visible at compile time,
        # thus preventing any "Variable $DEBUG not defined errors
        *{ $pkg.PKG.DEBUG } = \$debug;
    }
    return $debug;
} 


sub debug {
    my $self   = shift;
    my $msg    = join('', @_),
    my $class  = ref $self || $self;
    my $format = $FORMAT;
    my ($pkg, $file, $line) = caller($CALLER_UP);
    $class .= " ($pkg)" unless $class eq $pkg;
    $msg .= "\n" unless $msg =~ /\n$/;
    my $data = {
        msg   => $msg,
        class => $class,
        file  => $file,
        line  => $line,
    };
    $format =~ s/<(\w+)>/defined $data->{ $1 } ? $data->{ $1 } : "<$1 undef>"/eg;
    print STDERR $format;
}


sub debug_up {
    my $self = shift;
    local $CALLER_UP = shift;
    $self->debug(@_);
}


sub debug_caller {
    my $self = shift;
    my ($pkg, $file, $line, $sub) = caller(1);
    my $msg = "$sub called from ";
    ($pkg, undef, undef, $sub) = caller(2);
    $msg .= "$sub in $file at line $line\n";
    $self->debug($msg);
}


sub debug_args {
    my $self = shift;
    $self->debug_up( 
        2, "args: ",  
        join(', ', map { $self->dump_data_inline($_) } @_),
        "\n"
    );
}


sub debug_modules {
    my $self    = shift;
    my $modules = @_ == 1 ? shift : [ @_ ];
    my $debug   = 1;

    $modules = [ split(DELIMITER, $modules) ] 
        unless ref $modules eq ARRAY;
        
    # TODO: handle other refs?

    foreach my $pkg (@$modules) {
        no strict REFS;
        *{ $pkg.PKG.DEBUG } = \$debug;
    }
}


#-----------------------------------------------------------------------
# data dumping methods
#-----------------------------------------------------------------------

sub dump {
    my $self = shift;
    my $code = $self->can('dumper');
    return $code 
         ? $code->($self, @_)
         : $self->dump_ref($self, @_);
}


sub dump_data {
    if (! defined $_[1]) {
        return UNDEF;
    }
    elsif (! ref $_[1]) {
        return $_[1];
    }
    elsif (blessed($_[1]) && (my $code = $_[1]->can('dump'))) {
        shift;  # remove $self object, leave target object first
        return $code->(@_);
    }
    else {
        goto &dump_ref;
    }
}


sub dump_ref {
    my ($self, $data, $indent) = @_;
    
    # TODO: change these to reftype
    if (UNIVERSAL::isa($data, HASH)) {
        return $self->dump_hash($data, $indent);
    }
    elsif (UNIVERSAL::isa($data, ARRAY)) {
        return $self->dump_list($data, $indent);
    }
    elsif (UNIVERSAL::isa($data, REGEX)) {
        return $self->dump_text("$data");
    }
    elsif (UNIVERSAL::isa($data, SCALAR)) {
        return $self->dump_text($$data);
    }
    else {
        return $data;
    }
}


sub dump_data_inline {
    local $PAD = '';
    my $text = shift->dump_data(@_);
    $text =~ s/\n/ /g;
    return $text;
}


sub dump_hash {
    my ($self, $hash, $indent, $keys) = @_;
    $indent ||= 0;
    return "..." if $indent > $MAX_DEPTH;
    my $pad = $PAD x $indent;

    return '{ }' unless $hash && %$hash;
    
    if ($keys) {
        $keys = [ split(DELIMITER, $keys) ]
            unless ref $keys;
        $keys = { map { $_ => 1 } @$keys }
            if ref $keys eq ARRAY;
        return $self->error("Invalid keys passed to dump_hash(): $keys")
            unless ref $keys eq HASH;
            
        $self->debug("constructed hash keys: ", join(', ', %$keys)) if $DEBUG;
    }
    
    return "\{\n" 
        . join( ",\n", 
                map { "$pad$PAD$_ => " . $self->dump_data($hash->{$_}, $indent + 1) }
                sort grep { $keys ? $keys->{ $_ } : 1 } keys %$hash 
           ) 
        . "\n$pad}";
}


sub dump_list {
    my ($self, $list, $indent) = @_;
    $indent ||= 0;
    my $pad = $PAD x $indent;

    return '[ ]' unless @$list;
    return "\[\n$pad$PAD" 
        . ( @$list 
            ? join(",\n$pad$PAD", map { $self->dump_data($_, $indent + 1) } @$list) 
            : '' )
        . "\n$pad]";
}


sub dump_text {
    my ($self, $text, $length) = @_;
    $text = $$text if ref $text;
    $length ||= $MAX_TEXT;
    my $snippet = substr($text, 0, $length);
    $snippet .= '...' if length $text > $length;
    $snippet =~ s/\n/\\n/g;
    return $snippet;
}



#-----------------------------------------------------------------------
# enable_colour()
#
# Export hook which gets called when the Badger::Debug module is 
# used with the 'colour' or 'color' option.  It redefines the formats
# for $Badger::Base::DEBUG_FORMAT and $Badger::Exception::FORMAT
# to display in glorious ANSI technicolor.
#-----------------------------------------------------------------------

sub enable_colour {
    my ($class, $target, $symbol) = @_;
    $target ||= (caller())[0];
    $symbol ||= 'colour';

    print bold green "Enabling debug in $symbol from $target\n";

    # colour the debug format
    $FORMAT 
         = cyan('[<class> line <line>]')
         . yellow(' <msg>');

    # exceptions are in red
    $Badger::Exception::FORMAT 
        = bold red $Badger::Exception::FORMAT;

    $Badger::Exception::MESSAGES->{ caller } 
        = yellow('<4>')   . cyan(' called from ')
        . yellow("<1>\n") . cyan('  in ')
        . white('<2>')   . cyan(' at line ')
        . white('<3>');
}



1;

__END__

=head1 NAME

Badger::Debug - base class mixin module implement debugging methods

=head1 SYNOPSIS

    package Your::Module;
    
    use Badger::Debug 
        default => 0;   # default value for $DEBUG and DEBUG
    
    sub some_method {
        my $self = shift;
        
        # DEBUG is a compile-time constant, so very efficient
        $self->debug("First Message") if DEBUG;
        
        # $DEBUG is a runtime variable, so more flexible
        $self->debug("Second Message") if $DEBUG;
    }

    package main;
    use Your::Module;
    
    Your::Module->some_method;      # no output, debugging off by default
    Your::Module->debugging(1);     # turns runtime debugging on
    Your::Module->some_method;      # [Your::Module line 13] Second Message

=head1 DESCRIPTION

This mixin module implements a number of methods for debugging. Read L<The
Whole Caboodle> if you just want to get started quickly. Read L<Picky Picky
Picky> if you want to get all picky about what you want to use or want more
information on the individual features.

Note that all of the debugging methods described below work equally well as
both object and class methods even if we don't explicitly show them being
used both ways.

    # class method
    Your::Module->debug('called as a class method');
    
    # object method
    my $object = Your::Module->new;
    $object->debug('called as an object method');

=head2 The Whole Caboodle

The L<default> import option is the all-in-one option that enables all
debugging features. The value you specify with it will be used as the default
debugging status. Use C<0> if you want debugging off by default, or any true
value if you want it on.

    package Your::Module;
    
    use Badger::Debug 
        default => 0;

The L<default> option imports the L<debug()> and L<debugging()> methods,
the L<$DEBUG> package variable (set to the default value you specified 
unless it's already defined to be something else), and the L<DEBUG>
constant subroutine (defined to have the same value as the L<$DEBUG>
variable).

In your module's methods you can call the L<debug()> method to generate
debugging messages. You can use the L<DEBUG> constant or the L<$DEBUG>
variable as a condition so that messages only get displayed when debugging is
enbled.

    sub some_method {
        my $self = shift;
        
        # DEBUG is a compile-time constant, so very efficient
        $self->debug("First Message") if DEBUG;
        
        # $DEBUG is a runtime variable, so more flexible
        $self->debug("Second Message") if $DEBUG;
    }

The L<DEBUG> constant is resolved at compile time so it results in more
efficient code. When debugging is off, Perl will completely eliminate the
first call to the L<debug()> method in the above example.  The end result
is that there's no performance overhead incurred by including debugging
statements like these.

The L<$DEBUG> package variable is a little more flexible because you can
change the value at any point during the execution of your program. You might
want to do this from inside the module (say to enable debugging in one
particular method that's causing problems), or outside the module from a
calling program or another module. The L<debugging()> method is provided
as a convenient way to change the C<$DEBUG> package variable for a module.

    Your::Module->debugging(0);     # turn runtime debugging off
    Your::Module->debugging(1);     # turn runtime debugging on

The downside is that checking the L<$DEBUG> variable at runtime is less
efficient than using the L<DEBUG> compile time constant. Unless you're working
on performance critical code, it's probably not something that you should
worry about.

However, if you are the worrying type then you can use C<Badger::Debug> 
to get some of the best bits of both worlds.  When your module is loaded,
both L<DEBUG> and L<$DEBUG> will be set to the default value you specified
I<< unless C<$DEBUG> is already defined >>.  If it is defined then the
L<DEBUG> constant will be set to whatever value it has.  So if you define
the L<$DEBUG> package variable I<before> loading the module then you'll
be able to enable both run time and compile time debugging messages without
having to go and edit the source code of your module.

    $Your::Module::DEBUG = 1;
    require Your::Module;

Alternately, you can let C<Badger::Debug> do it for you.  The L<modules>
import option allows you to specify one or more modules that you want 
debugging enabled for.  

    use Badger::Debug 
        modules => 'My::Module::One My::Module::Two';
    
    use My::Module::One;        # both runtime and compile time
    use My::Module::Two;        # debugging enabled in both modules

The benefit of this approach is that it happens at compile time.
If you do it I<before> you C<use> your modules, then you'll get
both compile time and run time debugging enabled.  If you do it after
then you'll get just runtime debugging enabled.  Best of all - you don't
need to change any of your existing code to load modules via C<require>
instead of C<use>

=head2 Picky Picky Picky

The C<Badger::Debug> module allow you to be more selective about what
you want to use.  This section described the individual debugging methods
and the L<DEBUG> and L<$DEBUG> flags that can be used to control debugging.

In the simplest case, you can import the L<debug()> method into your own
module for generating debugging messages.

    package Your::Module;
    use Badger::Debug 'debug';
    
    sub some_method {
        my $self = shift;
        $self->debug("Hello from some_method()");
    }

In most cases you'll want to be able to turn debugging messages on and off.
You could do something like this:

    # initialise $DEBUG if it's not already set
    our $DEBUG = 0 unless defined $DEBUG;
    
    sub some_method {
        my $self = shift;
        $self->debug("Hello from some_method()") if $DEBUG;
    }

If you use the C<unless defined $DEBUG> idiom shown in the example shown above
then it will also allow you to set the C<$DEBUG> flag I<before> your module is
loaded. This is particularly useful if the module is auto-loaded on demand by
another module or your own code.

    # set $DEBUG flag for your module
    $Your::Module::DEBUG = 1;
    
    # later...
    require Your::Module;       # debugging is enabled

You can also achieve the same effect at compile time using the
C<Badger::Debug> L<modules> export option.

    use Badger::Debug
        modules => 'Your::Module';  # sets $Your::Module::DEBUG = 1
    use Your::Module;               # debugging is enabled

The advantage of using the L<$DEBUG> package variable is that you can change
the value at any point to turn debugging on or off. For example, if you've got
a section of code that requires debugging enabled to track down a particular
bug then you can write something like this:

    sub gnarly_method {
        my $self = shift;
        
        local $DEBUG = 1;
        $self->debug("Trying to track down the cause bug 666");
        
        # the rest of your code...
        $self->some_method;
    }

Making the change to C<$DEBUG> C<local> means that it'll only stay set to C<1>
until the end of the C<gnarly_method()>. It's a good idea to add a debugging
message any time you make temporary changes like this. The message generated
will contain the file and line number so that you can easily find it later 
when the bug has been squashed and either comment it out (for next time) or
remove it.

The C<Badger::Debug> module has a L<$DEBUG> export hook which will define the
the C<$DEBUG> variable for you.  The value you provide will be used as the
default for C<$DEBUG> if it isn't already defined.

    package Your::Module;
    
    use Badger::Debug 
        'debug',
        '$DEBUG' => 0;
    
    sub some_method {
        my $self = shift;
        $self->debug("Hello from some_method()") if $DEBUG;
    }

The L<debugging()> method can also be imported from C<Badger::Debug>.  This
provides a simple way to set the L<$DEBUG> variable.

    Your::Module->debugging(1);     # debugging on
    Your::Module->debugging(0);     # debugging off

The downside to using a package variable is that it slows your code down
every time you check the L<$DEBUG> flag.  In all but the most extreme cases,
this should be of no concern to you whatsoever.  Write your code in the way
that is most convenient for you, not the machine.  

B<WARNING:> Do not even begin to consider entertaining the merest thought of
optimising your code to make it run faster until your company is on the verge
of financial ruin due to your poorly performing application and your boss has
told you (with confirmation in writing, countersigned by at least 3 members of
the board of directors) that you will be fired first thing tomorrow morning
unless you make the code run faster I<RIGHT NOW>.

Another approach is to define a constant L<DEBUG> value.

    package Your::Module;
    
    use Badger::Debug 'debug';
    use constant DEBUG => 0;
    
    sub some_method {
        my $self = shift;
        $self->debug("Hello from some_method()") if DEBUG;
    }

This is an all-or-nothing approach.  Debugging is on or off and there's
nothing you can do about it except for changing the constant definition
in the source code and running the program again.  The benefit of this
approach is that L<DEBUG> is defined as a compile time constant.  When
L<DEBUG> is set to C<0>, Perl will effectively remove the entire debugging
line at compile time because it's based on a premise (C<if DEBUG>) that
is known to be false.  The end result is that there's no runtime performance
penalty whatsoever.

C<Badger::Debug> also provides the L<DEBUG> hook if this is the kind of 
thing you want.

    package Your::Module;
    
    use Badger::Debug 
        'debug',
        'DEBUG' => 0;
    
    sub some_method {
        my $self = shift;
        $self->debug("Hello from some_method()") if DEBUG;
    }

What makes this extra-special is that you're only specifying the I<default>
value for the C<DEBUG> constant. If the C<$DEBUG> package variable is defined
when the module is loaded then that value will be used instead. So although
it's not possible to enable or disable debugging for different parts of a
module, you can still enable debugging for the whole module by setting the
C<$DEBUG> package variable before loading it.

    # set $DEBUG flag for your module
    $Your::Module::DEBUG = 1;
    
    # later...
    require Your::Module;       # debugging is enabled

Here's a reminder of the other way to achieve the same thing at compile time
using the C<Badger::Debug> L<modules> export option.

    use Badger::Debug
        modules => 'Your::Module';  # sets $Your::Module::DEBUG = 1
    use Your::Module;               # debugging is enabled

You can combine the use of both L<$DEBUG> and L<DEBUG> in your code, for a
two-level approach to debugging. The L<DEBUG> tests will always be resolved at
compile time so they're suitable for low-level debugging that either has a
performance impact or is rarely required. The L<$DEBUG> tests will be resolved
at run time, so they can be enabled or disabled at any time or place.

    sub some_method {
        my $self = shift;
        $self->debug("Hello from some_method()") if DEBUG;
        $self->debug("Goodbye from some_method()") if $DEBUG;
    }

=head1 IMPORT OPTIONS

All of the L<debugging methods|DEBUGGING METHODS> can be imported selectively
into your module. For example:

    use Badger::Debug 'debug debugging debug_caller';

The following import options are also provided.

=head2 default

Used to set the default debugging value and import various debugging methods
and flags.

    use Badger::Debug
        default => 0;           # debugging off by default

It imports the L<debug()> and L<debugging()> methods along with the 
L<$DEBUG> package variable and L<DEBUG> constant.

See L<The Whole Caboodle> for further discussion on using it.

=head2 $DEBUG

Used to define a C<$DEBUG> variable in your module.  A default value 
should be specified which will be used to set the C<$DEBUG> value if
it isn't already defined.

    use Badger::Debug
        '$DEBUG' => 0;           # debugging off by default
        
    print $DEBUG;                # 0

=head2 DEBUG

Used to define a C<DEBUG> constant in your module.  If the C<$DEBUG>
package variable is defined then the C<DEBUG> constant will be set to
whatever value it contains.  Otherwise it will be set to the default 
value you provide.

    use Badger::Debug
        'DEBUG' => 0;            # debugging off by default
        
    print DEBUG;                 # 0

=head2 modules

This option can be used to set the C<$DEBUG> value true in one or more
packages.  This ensures that any debugging will be enabled in those modules.

    use Badger::Debug
        modules => 'My::Module::One My::Module::Two';
        
    use My::Module::One;        # debugging enabled in both modules
    use My::Module::Two;

Modules that haven't yet been loaded will have both compile time (L<DEBUG>)
and run time (L<$DEBUG>) debugging enabled.  Modules that have already been
loaded will only have run time debugging enabled.

=head2 dumps

This option can be used to construct a specialised L<dump()> method for
your module.  The method is used to display nested data in serialised
text form for debugging purposes.  The default L<dump()> method for an 
object will display all items stored within the object.  The C<dumps>
import option can be used to limit the dump to only display the fields
specified.

    package Your::Module;
    use Badger::Debug dumps => 'foo bar baz';
    # ...more code...
    
    package main;
    my $object = Your::Module->new;
    print $object->dump;            # dumps foo, bar and baz

=head2 colour / color

Either of these (depending on your spelling preference) can be used to 
enable colourful (or colorful) debugging.

    use Badger::Debug 'colour';

Debugging messages will then appear in colour (on a terminal supporting 
ANSI escape sequences).  See the L<Badger::Test> module for an example
of this in use.

=head2 :debug

Imports all of the L<debug()>, L<debugging()>, L<debug_up()>, 
L<debug_caller()> and L<debug_args()> methods.

=head2 :dump

Imports all of the L<dump()>, L<dump_ref()>, L<dump_hash()>, L<dump_list()>,
L<dump_text()>, L<dump_data()> and L<dump_data_inline()> methods.

=head1 DEBUGGING METHODS

=head2 debug($msg1, $msg2, ...)

This method can be used to generate debugging messages.

    $object->debug("Hello ", "World\n");

It prints all argument to STDERR with a prefix indicating the 
class name, file name and line number from where the C<debug()> method
was called.

    [Badger::Example line 42] Hello World

At some point in the future this will be extended to allow you to tie in
debug hooks, e.g. to forward to a logging module.

=head2 debug_up($n, $msg1, $msg2, ...)

The L<debug()> method generates a message showing the file and line number
from where the method was called. The C<debug_up()> method can be used to
report the error from somewhere higher up the call stack. This is typically
used when you create your own debugging methods, as shown in the following
example.

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

The C<trace()> method calls the L<debug_up()> method telling it to look I<two>
levels up in the caller stack instead of the usual I<one> (thus
C<debug_up(1,...)> has the same effect as C<debug(...)>).  So instead of 
reporting the line number in the C<trace()> subroutine (which would be the
case if we called C<debug(...)> or C<debug_up(1,...)>), it will correctly
reporting the line number of the call to C<trace()> in the C<parse()> 
method.

=head2 debug_caller()

Prints debugging information about the current caller.

    sub wibble {
        my $self = shift;
        $self->debug_caller;
    }

=head2 debug_args()

Prints debugging information about the arguments passed.

    sub wibble {
        my $self = shift;
        $self->debug_args(@_);
    }

=head2 debugging($flag)

This method of convenience can be used to set the C<$DEBUG> variable for 
a module.  It can be called as a class or object method.

    Your::Module->debugging(1);     # turn debugging on
    Your::Module->debugging(0);     # turn debugging off

=head2 debug_modules(@modules)

This method can be used to set the C<$DEBUG> true in one or more modules.
Modules can be specified as a list of package names, a reference to a list,
or a whitespace delimited string.

    Badger::Debug->debug_modules('Your::Module::One Your::Module::Two');

The method is also accessible via the L<modules> import option.

=head1 DATA INSPECTION METHODS

These methods of convenience can be used to inspect data structures.
The emphasis is on brevity for the sake of debugging rather than full
blown inspection.  Use L<Data::Dumper> or on of the other fine modules
available from CPAN if you want something more thorough.

The methods below are recursive, so L<dump_list()>, on finding a hash
reference in the list will call L<dump_hash()> and so on.  However, this
recursion is deliberately limited to no more than L<$MAX_DEPTH> levels deep
(3 by default).  Remember, the emphasis here is on being able to see enough
of the data you're dealing with, neatly formatted for debugging purposes,
rather than being overwhelmed with the big picture.

If any of the methods encounter an object then they will call its 
L<dump()> method if it has one.  Otherwise they fall back on L<dump_ref()>
to expose the internals of the underlying data type.  You can create your
own custom L<dump()> method for you objects or use the L<dumps> import
option to have a custom L<dump()> method defined for you.

=head2 dump()

Debugging method which returns a text representation of the object internals.

    print STDERR $object->dump();

You can define your own C<dump()> for an object and this will be called 
whenever your object is dumped.  The L<dumps> import option can be used
to generate a custom C<dump()> method.

=head2 dump_ref($ref)

Does The Right Thing to call the appropriate dump method for a reference
of some kind.

=head2 dump_hash(\%hash)

Debugging method which returns a text representation of the hash array passed
by reference as the first argument.

    print STDERR $object->dump_hash(\%hash);

=head2 dump_list(\@list)

Debugging method which returns a text representation of the array
passed by reference as the first argument.

    print STDERR $object->dump_list(\@list);

=head2 dump_text($text)

Debugging method which returns a truncated and sanitised representation of the 
text string passed (directly or by reference) as the first argument.

    print STDERR $object->dump_text($text);

The string will be truncated to L<$MAX_TEXT> characters and any newlines
will be converted to C<\n> representations.

=head2 dump_data($item)

Debugging method which calls the appropriate dump method for the item passed
as the first argument.  If it is an object with a L<dump()> method then that
will be called, otherwise it will fall back on L<dump_ref()>, as it will
for any other non-object references.  Non-references are passed to the 
L<dump_text()> method.

    print STDERR $object->dump_data($item);

=head2 dump_data_inline($item)

Wrapper around L<dump_data()> which strips any newlines from the generated
output, suitable for a more compact debugging output.

    print STDERR $object->dump_data_inline($item);

=head1 MISCELLANEOUS METHODS

=head2 enable_colour()

Enables colourful debugging and error messages.

    Badger::Debug->enable_colour;

=head1 PACKAGE VARIABLES

=head2 $FORMAT

The L<debug()> method uses the message format in the C<$FORMAT>
package variable to generate debugging messages.  The default value is:

    [<class> line <line>] <msg>

The C<E<lt>classE<gt>>, C<E<lt>lineE<gt>> and C<E<lt>msgE<gt>> markers
denote the positions where the class name, line number and debugging 
message are inserted.

=head2 $MAX_DEPTH

The maximum depth that the L<data inspection methods|DATA INSPECTION METHODS>
will recurse to.

=head2 $MAX_TEXT

The maximum length of text that will be returned by L<dump_text()>.

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
