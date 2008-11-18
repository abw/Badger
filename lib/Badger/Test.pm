package Badger::Test;

use Carp;
use Badger::Class
    version   => 0.01,
    base      => 'Badger::Base',
    import    => 'CLASS class',
    constants => 'ARRAY DELIMITER PKG',
    words     => 'DEBUG DEBUG_MODULES',
    exports   => {
        all   => 'plan ok is isnt like unlike pass fail     
                  skip_some skip_rest skip_all',        # NOTE: changed skip...
        hooks => {
            skip     => \&_skip_hook,                   # ...to be a hook
            debug    => \&_debug_hook,
            map { $_ => \&_export_hook }
            qw( manager summary colour color args tests )
        },
    };

use Badger::Debug;
use Badger::Exception;
use Badger::Test::Manager;
our $MANAGER   = 'Badger::Test::Manager';
our $DEBUGGER  = 'Badger::Debug';
our $EXCEPTION = 'Badger::Exception';
our ($DEBUG, $DEBUG_MODULES);

*color = \&colour;

sub _export_hook {
    my ($class, $target, $key, $symbols) = @_;
    croak "You didn't specify a value for the '$key' load option"
        unless @$symbols;
    $class->$key(shift @$symbols);
}

sub _debug_hook {
    my ($class, $target, $key, $symbols, $import) = @_;
    croak "You didn't specify any values for the 'debug' load option.\n" 
        unless @$symbols;

    # define $DEBUG in caller
    no strict 'refs';
    *{ $target.PKG.DEBUG } = \$DEBUG;

    # set $DEBUG_MODULE in this class to contain the argument passed - a list
    # of class names to enable $DEBUG in when/if debugging is enabled
    my $modules = shift @$symbols;
    return unless $modules;           # zero/false for no debugging
    $class->debug_modules($modules);
}

sub _skip_hook {
    my ($class, $target, $key, $symbols, $import) = @_;
    $MANAGER->skip_all(shift @$symbols);
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

sub summary {
    shift;
    manager->summary(@_);
}

sub args {
    my $self = shift;
    my $args = @_ && ref $_[0] eq ARRAY ? shift : [ @_ ];
    my $arg;
    
    # quick hack until Badger::Config is done
    while (@$args && $args->[0] =~ /^-/) {
        $arg =  shift @$args;
        if ($arg =~ /^(-c|--colou?r)$/) {
            $self->colour(1);
        }
        elsif ($arg =~ /^(-d|--debug)$/) {
            $self->debugging(1);
        }
        elsif ($arg =~ /^(-s|--summary)$/) {
            $self->summary(1);
        }
        elsif ($arg =~ /^(-t|--trace)$/) {
            $self->trace(1);
        }
        elsif ($arg =~ /^(-h|--help)$/) {
            warn $self->help;
            exit;
        }
        else {
            unshift(@$args, $arg);
            last;
        }
     }  
}

sub tests {
    shift; 
    plan(@_);
}

sub debug_modules {
    my $self = shift;
    $self->class->var( DEBUG_MODULES => shift );
}

sub debugging {
    my $self    = shift;
    my $flag    = $DEBUG = shift || 1;
    my $modules = $self->class->var(DEBUG_MODULES) || return;
    $DEBUGGER->debug_modules($modules);
}

sub trace {
    my $self = shift;
    my $flag = shift || 1;
    $EXCEPTION->trace($flag);
}

sub help {
    return <<END_OF_HELP;
Options:
    -d      --debug             Enable debugging
    -t      --trace             Enable stack tracing
    -c      --colour/--color    Enable colour output
    -s      --summary           Display summary of test results
    -h      --help              This help summary
END_OF_HELP
}


class->methods(
    plan      => sub ($;$)  { manager->plan(@_)      },
    ok        => sub ($;$)  { manager->ok(@_)        },
    is        => sub ($$;$) { manager->is(@_)        },
    isnt      => sub ($$;$) { manager->isnt(@_)      },
    like      => sub ($$;$) { manager->like(@_)      },
    unlike    => sub ($$;$) { manager->unlike(@_)    },
    pass      => sub (;$)   { manager->pass(@_)      },
    fail      => sub (;$)   { manager->fail(@_)      },
    skip      => sub (;$)   { manager->skip(@_)      },
    skip_some => sub (;$$)  { manager->skip_some(@_) },
    skip_rest => sub (;$)   { manager->skip_rest(@_) },
    skip_all  => sub (;$)   { manager->skip_all(@_)  },
);


1;

__END__

=head1 NAME

Badger::Test - test module

=head1 SYNOPSIS

    use Badger::Test
        tests => 8,
        debug => 'My::Badger::Module Your::Badger::Module',
        args  => \@ARGV;
    
    # -d in @ARGV will enable $DEBUG for My::Badger::Module 
    # and Your::Badger::Module, as well as exporting a $DEBUG
    # flag here. -c will enable colour mode.
    # e.g.   $ perl t/test.t -d -c
    
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
L<ok()>, L<is()>, L<isnt()> and other subroutines you would expect to
find, it also implements a number of import hooks to enable certain
Badger-specific features.

=head1 EXPORTED SUBROUTINES

The C<Badger::Test> module exports the following subroutines, similar to 
those found in L<Test::Simple> or L<Test::More>.

=head2 plan($tests)

Specify how many tests you plan to run.  You can also sepcify this using
the L<tests> import hook.

    plan(1);

=head2 ok($flag, $name)

Report on the success or failure of a test:

    ok(1, 'This is good');
    ok(0, 'This is bad');

=head2 is($this, $that, $name)

Test if the first two arguments are equal.

    is($this, $that, "This and that are equal");

=head2 isnt($this, $that, $name)

Test if the first two arguments are not equal.

    isnt($this, $that, "This and that are equal");

=head2 like($text, qr/regex/, $name)

Test if the first argument is matched by the regex passed as the second
argument.

    like($this, qr/like that/i, "This and that are alike");

=head2 unlike($text, qr/regex/, $name)

Test if the first argument is not matched by the regex passed as the second
argument.

    unlike($this, qr/like that/i, "This and that are unalike");

=head2 pass($name)

Pass a test.

    pass('Module Loaded');

=head2 fail($name)

Fail a test.

    fail('Stonehenge in danger of being crushed by a dwarf');

=head2 skip($reason)

Skip a single test.

    skip("That's just nit-picking isn't it?");

=head2 skip_all($reason)

Skip all tests.  This should be called instead of L<plan()>

    skip_all("We don't have that piece of scenery any more");

=head2 skip_some($number,$reason)

Skip a number of tests.

    skip_some(11, "Hugeness of object understated");

=head2 skip_rest(,$reason)

Skip any remaining tests.

    skip_rest("Should have made a big thing out of it");

=head1 CLASS METHODS

The C<Badger::Test> module defines the following class methods to 
access and/or configure the test framework.

=head2 tests()

This class method can be used to set the number of tests.  It does the
same thing as the L<plan()> subroutine.

    Badger::Test->tests(42);

=head2 manager()

Method to get or set the name of the backend test manager object class. This
is defined in the L<$MANAGER> package variable. The default manager is
L<Badger::Test::Manager>.

    # defining a custom manager class
    Badger::Test->manager('My::Test::Manager');

=head2 args(@args)

This method can be used to set various testing options from command line 
arguments.  It is typically called via the L<args> import option.

    use Badger::Test
        debug => 'My::Module',
        args  => \@ARGV,
        tests => 42;

The method parses the arguments looking for the following options:

    -d      --debug             Enable debugging
    -t      --trace             Enable stack tracing
    -c      --colour/--color    Enable colour output
    -s      --summary           Display summary of test results
    -h      --help              This help summary
    
Arguments can be passed as a list or reference to a list.  

    Badger::Test->args(@ARGV);      # either
    Badger::Test->args(\@ARGV);     # or

Any of the arguments listed above appearing at the start of the list will be
removed from the list and acted upon. Processing will end as soon as an
unrecognised argument is encountered.

=head2 summary()

Prints a summary of the test results.  Delegates to L<Badger::Test::Manager>
method of the same name.

=head2 colour()

Method to enable or disable colour output.

    Badger::Test->colour(1);        # technicolor
    Badger::Test->colour(0);        # monochrome

=head2 color()

An alias for L<colour()>.

=head2 debug_modules($modules)

This method can be called to define one or more modules that should have their
C<$DEBUG> flag enabled when running in debug mode (i.e. with the C<-d> command
line option). This method is called by the L<debug> import hook. 

    Badger::Test->debug('My::Badger::Module');  

Multiple modules can be specified in a single string or by reference to a list.

    # whitespace-delimited string
    Badger::Test->debug('My::Badger::Module Your::Badger::Module');  

    # list reference
    Badger::Test->debug(['My::Badger::Module', 'Your::Badger::Module']);  

This method simply stores the list of modules in the C<$DEBUG_MODULES> 
package variable for the L<debugging()> method to use.

=head2 debugging($flag)

This method enables or disables debugging for all modules named in the 
C<$DEBUG_MODULES> list.  It also sets the internal C<$DEBUG> flag.

    Badger::Test->debugging(1);         # enable debugging
    Badger::Test->debugging(0);         # disable debugging

=head2 trace($flag)

This method enables or disables stack tracing in the L<Badger::Exception>
module.

=head2 help()

This method returns the help text display when help is requested with the 
C<-h> or C<--help> command line options.  See L<args()> for further details.

=head1 IMPORT HOOKS

The following import hooks are provided to allow you to load and configure the
C<Badger::Test> module in one fell swoop.

=head2 tests

Specify the number of tests.  Does the same thing as calling the L<plan()>
subroutine or L<tests()> class method.

    use Badger::Test 
        tests => 42;

=head2 manager

An import hook to define a different test manager module. See the L<manager()>
method.

    use My::Test::Manager;
    use Badger::Test 
        manager => 'My::Test::Manager';

=head2 colour

An import hook to enable colour mode.  See the L<colour()> method.

    use Badger::Test 
        colour => 1;

=head2 color

An alias for L<colour>

=head2 args

This import hook can be used to feed the command line arguments to the 
L<args()> method so that C<-d> and C<-c> enable debugging and colour 
moes, respectively.

    use Badger::Test 
        args => \@ARGV;

=head2 debug

An import hook to associate a list of module with our debugging mode.
See the L<debug()> method.

    use Badger::Test 
        debug => 'My::Badger::Module Your Badger::Module',
        args  => \@ARGV;

=head1 PACKAGE VARIABLES

=head2 $MANAGER

This package variable stores the name of the manager class, 
L<Badger::Test::Manager> by default.

=head2 $DEBUG

The C<$DEBUG> package variable holds the name(s) of module(s) for which
debugging should be enabled, as defined via the L<debug()> method.

=head2 $DEBUGGING

Flag set true or false to indicate debugging mode is enabled or disabled.
As set by the L<debugging()> method.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Test::Manager>, L<Test::Simple>, L<Test::More>.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
