#========================================================================
#
# Badger::Class::Vars
#
# DESCRIPTION
#   Class mixin module for adding package variables to a class.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Class::Vars;

use Badger::Debug ':dump';
use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base Badger::Exporter',
    import    => 'BCLASS',
    constants => 'DELIMITER SCALAR ARRAY HASH REFS PKG',
    utils     => 'is_object',
    messages  => {
        no_target => 'No target class specified to generate variables for',
        no_vars   => 'No vars specified to define',
        bad_vars  => 'Invalid vars specified: %s',
        bad_var   => 'Invalid variable name in vars: %s',
        bad_hash  => 'Invalid hash variable for %s in vars: %s',
        bad_sigil => 'Unrecognised sigil for symbol: %s',
    };

    
sub export {
    goto &vars if @_ > 2;
}


sub vars {
    my $class  = shift;
    my $target = shift || return $class->error_msg('no_target');
    my $vars   = @_ == 1 ? shift : { @_ };
    my ($symbol, $sigil, $name, $dest, $ref);

    # downgrade $target from a Badger::Class object to a package name
    $target = $target->name
        if is_object(BCLASS, $target);

    # split text string into lisy ref of variable names
    $vars = [ split(DELIMITER, $vars) ] 
        unless ref $vars;

    # upgrade a list ref to a hash ref
    $vars = { map { $_ => undef } @$vars }
        if ref $vars eq ARRAY;

    $class->error_msg( bad_vars => $vars )
        unless ref $vars eq HASH;

    $class->error_msg('no_vars')
        unless %$vars;

    $class->debug("Defining vars for $target: ", $class->dump_data($vars))
        if DEBUG;

    # This is a slightly simplified (stricter) version of the equivalent 
    # code in vars.pm with a little extra syntactic sugar supported.
    # Unfortunately it's not possible to delegate to vars.pm because 
    # it will only export to its caller, and not to a third party package
    
    while (($symbol, $ref) = each %$vars) {
        no strict REFS;

        # only accept: $WORD @WORD %WORD WORD
        $symbol =~ /^([\$\@\%])?(\w+)$/
            || return $class->error_msg( bad_var => $symbol );
        ($sigil, $name) = ($1 || '$', $2);
        
        # expand destination to full package name ($Your::Module::WORD)
        $dest = $target.PKG.$name;

        $class->debug("var: $sigil$name => ", $ref || '\\'.$sigil.$dest, "\n") 
            if DEBUG;
        
        if ($sigil eq '$') {
            *$dest = defined $ref
                ? (ref $ref eq SCALAR ? $ref : do { my $copy = $ref; \$copy })
                : \$$dest;
        }
        elsif ($sigil eq '@') {
            *$dest = defined $ref
                ? (ref $ref eq ARRAY ? $ref : [$ref])
                : \@$dest;
        }
        elsif ($sigil eq '%') {
            *$dest = defined $ref
                ? (ref $ref eq HASH 
                     ? $ref 
                     : return $class->error_msg( bad_hash => $symbol, $ref )
                  )
                : \%$dest;
        }
        else {
            # should never happen
            return $class->error_msg( bad_sigil => $symbol );
        }
    }
}

1;

__END__

=head1 NAME

Badger::Class::Vars - class module for defining package variables

=head1 SYNOPSIS

    package My::Module;
    
    # simple pre-declaration of variables
    use Badger::Class::Vars '$FOO @BAR %BAZ';
    
    # pre-declaration with values
    use Badger::Class::Vars 
        '$FOO' => 10,
        '@BAR' => [20, 30, 40],
        '%BAZ' => { x => 100, y => 200 };
    
    # via Badger::Class
    use Badger::Class
        vars => '$FOO @BAR %BAZ';
    
    # via Badger::Class with values
    use Badger::Class
        vars => { 
            '$FOO' => 10,
            '@BAR' => [20, 30, 40],
            '%BAZ' => { x => 100, y => 200 },
        };

=head1 DESCRIPTION

This module allows you to pre-declare and optionally, define values for
package variables. It can be used directly, or via the
L<vars|Badger::Class/vars> export hook in L<Badger::Class>.

    # using the module directly
    use Badger::Class::Vars 
        '$FOO @BAR %BAZ';

    # using it via Badger::Class
    use Badger::Class
        vars => '$FOO @BAR %BAZ';   

In the simple case, it works just like the C<vars.pm> module in pre-declaring
the variables named. 

Unlike C<vars.pm>, this method will I<only> define scalar, list and hash
package variables (e.g. C<$SOMETHING>, C<@SOMETHING> or C<%SOMETHING>). 

If you want to define subroutines/methods then you can use the
L<Badger::Class::Methods> module, or the L<methods|Badger::Class/methods>
import hook or L<methods()|Badger::Class/methods()> method in
L<Badger::Class>. If you want to define a glob reference then you're already
operating in I<Wizard Mode> and you don't need our help.

If you don't specify a leading sigil (i.e. C<$>, C<@> or C<%>) then it will
default to C<$> and create a scalar variable.

    use Badger::Class
        vars => 'FOO BAR BAZ';      # declares $FOO, $BAR and $BAZ

You can also use a reference to a hash array to define values for variables.

    use Badger::Class
        vars => {                           # Equivalent code:
            '$FOO' => 42,                   #   our $FOO = 25
            '@WIZ' => [100, 200, 300],      #   our @WIZ = (100, 200, 300)
            '%WOZ' => {ping => 'pong'},     #   our %QOZ = (ping => 'pong')
        };

Scalar package variables can be assigned any scalar value or a reference to
some other data type. Again, the leading C<$> is optional on the variable
names. Note the difference in the equivalent code - this time we end up with
scalar variables and references exclusively.

    use Badger::Class
        vars => {                           # Equivalent code:
            FOO => 42,                      #   our $FOO = 42
            BAR => [100, 200, 300],         #   our $BAR = [100, 200, 300]
            BAZ => {ping => 'pong'},        #   our $BAZ = {ping => 'pong'}
            HAI => sub {                    #   our $HAI = sub { ... }
                'Hello ' . (shift || 'World') 
            },
        };

You can also assign any kind of data to a package list variable.  If it's
not already a list reference then the value will be treated as a single
item list.

    use Badger::Class
        vars => {                           # Equivalent code:
            '@FOO' => 42,                   #   our @FOO = (42)
        };

=head1 METHODS

=head2 vars($target,$vars)

This method defines variable in the C<$target> package. It is usually called
automatically when the module is loaded via C<use>.

The C<$vars> can be specified as a single text string of whitespace delimited
symbols or by reference to a list of individual symbols. The variables will be
declared but undefined.

    # single string
    Badger::Class::Vars->vars(
        'My::Package',
        '$FOO, @BAR, %BAZ'
    );

    # list reference
    Badger::Class::Vars->vars(
        'My::Package',
        ['$FOO', '@BAR', '%BAZ']
    );

Use a reference to a hash array if you want to provide values for the 
variables.

    # hash reference
    Badger::Class::Vars->vars(
        'My::Package',
        {
            '$FOO'  => 10,
            '@BAR' => [20, 30, 40],
            '%BAZ' => { x => 100, y => 200 },
        }
    );

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2008 Andy Wardley.  All Rights Reserved.

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
