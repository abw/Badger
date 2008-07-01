package Badger::Test::Manager;

use Badger::Class
    version     => 0.01,
    debug       => 1,
    base        => 'Badger::Prototype',
    import      => 'class';

our $ESCAPES    = qr/\e\[(.*?)m/;      # remove ANSI escapes
our $REASON     = 'No reason given';
our $MESSAGES   = {
    no_plan     => "You haven't called plan() yet!\n",
    dup_plan    => "You called plan() twice!\n",
    plan        => "1..%s\n",
    skip        => "1..0 # skipped: %s\n",
    name        => "test %s at %s line %s",
    ok          => "ok %s - %s\n",
    not_ok      => "not ok %s - %s\n%s",
    not_eq      => "  expect: [%s]\n  result: [%s]\n",
    not_ne      => "  unexpected match: [%s]\n",
    not_like    => "  expect: /%s/\n  result: [%s]\n",
    not_unlike  => "  expect: ! /%s/\n  result: [%s]\n",
    too_few     => "# Looks like you planned %s tests but only ran %s.\n",
    too_many    => "# Looks like you planned only %s tests but ran %s.\n",
};
our $SCHEME     = {
    green       => 'ok',
    red         => 'not_ok',
    cyan        => 'plan skip too_few too_many',
    yellow      => 'not_eq not_ne not_like not_unlike',
};
our $COLOURS    = {
    red         => 31,
    green       => 32,
    yellow      => 33,
    blue        => 34,
    magenta     => 35,
    cyan        => 36, 
    white       => 37,
};

# Sorry, English and American/Spanish only, no couleur, colori, farbe, etc.
*color = \&colour;


#-----------------------------------------------------------------------
# constructor method
#-----------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    $self->{ plan     } = $config->{ plan    } || 0;
    $self->{ count    } = $config->{ count   } || 1;
    $self->{ results  } = $config->{ results } || [ ];
    $self->{ reason   } = $config->{ reason  } || $REASON;
    $self->{ colour   } = $config->{ colour  } || $config->{ color } || 0;
    return $self;
}

sub skip_all ($;$) {
    my $self = shift->prototype;
    $self->test_msg( skip => shift || $self->{ reason } );
    exit;
}
    

#------------------------------------------------------------------------
# plan($n)
#
# Declare how many (more) tests are expected to come.  If ok() is called 
# before plan() then the results are cached instead of being printed up
# front.  When plan() is called, the total number of tests (including any 
# cached) is known and the "1..$n" line can be printed along with any 
# cached results.  After that, calls to ok() generated output immediately.
#------------------------------------------------------------------------

sub plan ($$;$) {
    my $self = shift->prototype;
    my ($tests, $reason) = @_;

    # calling plan() twice would be ambiguous
    return $self->error_msg('dup_plan')
        if $self->{ plan };

    # if $tests == 0 then skip all
    return $self->skip_all($reason)
        unless $tests;
    
    # update the plan to account for any tests that have already been run
    my $results = $self->{ results };
    $tests += @$results;
    $self->test_msg( plan => $tests );
    $self->{ plan } = $tests;

    # now flush any cached test results
    while (@$results) {
        my $test = shift @$results;
        $self->result(@$test);
    }
}

sub flush {
    my $self    = shift->prototype;
    my $results = shift || $self->{ results };
    return unless @$results;
    $self->{ plan } ||= @$results;
    while (@$results) {
        my $test = shift @$results;
        $self->result(@$test);
    }
}

sub result {
    my $self = shift->prototype;
    my $ok   = shift;

    return $self->error('no_plan')
        unless $self->{ plan };
    
    return $ok
        ? $self->test_msg(     ok => @_ )
        : $self->test_msg( not_ok => @_ );
}
    
sub ok ($$;$$) {
    my $self = shift->prototype;
    my ($ok, $name, $detail) = @_;
    $detail ||= '';

    $name ||= $self->test_name;

    if ($self->{ plan }) {
        $self->result($ok, $self->{ count }, $name, $detail);
    }
    else {
        # cache results if plan() not yet called
        push(@{ $self->{ results } }, [ $ok, $self->{ count }, $name, $detail ]);
    }

    $self->{ count }++;
    return $ok;
}

sub is ($$$;$) {
    my $self = shift->prototype;
    my ($result, $expect, $msg) = @_;
    $msg ||= $self->test_name();

    # force stringification of $result to avoid 'no eq method' overload errors
    $result = "$result" if ref $result;	   

    # if we have coloured output enabled then the result might not match
    # the expected because of embedded ANSI escapes, so we strip them out
    my ($r, $e) = map { 
        s/$ESCAPES//g if $self->{ colour };
        $_ 
    } ($result, $expect);
        
    if ($r eq $e) {
        return $self->pass($msg);
    }
    else {
        for ($expect, $result) {
            s/\n/\n          |/g;
        }
        return $self->fail($msg, $self->message( not_eq => $expect, $result ));
    }
}

sub isnt ($$$;$) {
    my $self = shift->prototype;
    my ($result, $expect, $msg) = @_;
    $msg ||= $self->test_name();

    # force stringification of $result to avoid 'no eq method' overload errors
    $result = "$result" if ref $result;	   

    # if we have coloured output enabled then the result might not match
    # the expected because of embedded ANSI escapes, so we strip them out
    my ($r, $e) = map { 
        s/$ESCAPES//g if $self->{ colour };
        $_ 
    } ($result, $expect);
        
    if ($r ne $e) {
        return $self->pass($msg);
    }
    else {
        for ($expect, $result) {
            s/\n/\n          |/g;
        }
        return $self->fail($msg, $self->message( not_eq => $expect, $result ));
    }
}

sub like ($$$;$) {
    my $self = shift->prototype;
    my ($result, $expect, $name) = @_;
    $name ||= $self->test_name();

    # strip ANSI escapes if necessary
    my $r = $result;
    $r =~ s/$ESCAPES//g if $self->{ colour };

    if ($r =~ $expect) {
        $self->pass($name);
    }
    else {
        return $self->fail($name, $self->message( not_like => $expect, $result ));
    }
}

sub unlike ($$$;$) {
    my $self = shift->prototype;
    my ($result, $expect, $name) = @_;
    $name ||= $self->test_name();

    # strip ANSI escapes if necessary
    my $r = $result;
    $r =~ s/$ESCAPES//g if $self->{ colour }; 

    if ($r !~ $expect) {
        $self->pass($name);
    }
    else {
        return $self->fail($name, $self->message( not_unlike => $expect, $result ));
    }
}

sub pass ($;$) {
    shift->ok(1, @_);
}

sub fail ($;$) {
    shift->ok(0, @_);
}

sub test_name ($) {
    my $self = shift->prototype;
    my ($pkg, $file, $line) = caller(1);
    $self->message( name => $self->{ count }, $file, $line );
}


#sub skip_rest {
#    my $msg = shift || '';
#    ok( 1, "skipping test...$msg" )
#        while $COUNT <= $EXPECT;
#    exit();
#}


sub test_msg {
    my $self = shift;
    print $self->message(@_);
}

sub colour {
    my $self = shift->prototype;

    # enable colour mode by inserting ANSI escapes into $MESSAGES
    if (@_ && ($self->{ colour } = shift)) {
        foreach my $col (keys %$SCHEME) {
            my $code = $COLOURS->{ $col }
                || $self->error("Invalid colour name in \$SCHEME: $col\n");
            $MESSAGES->{ $_ } = ANSI_escape_lines($code, $MESSAGES->{ $_ })
                for split(/\s+/, $SCHEME->{ $col });
        }
    }

    return $self->{ colour };
}

sub ANSI_escape_lines {
    my $attr = shift;
    my $text = join('', @_);

    return join("\n", 
        map {
            # look for an existing escape start sequence and add new 
            # attribute to it, otherwise add escape start/end sequences
            s/ \e \[ ([1-9][\d;]*) m/\e[$1;${attr}m/gx 
                ? $_
                : "\e[${attr}m" . $_ . "\e[0m";
        }
        split(/\n/, $text, -1)   # -1 prevents it from ignoring trailing fields
    );
}

sub finish {
    my $self = shift->prototype;
    $self->flush;           # output any cached results

    my $ran  = $self->{ count } - 1;
    my $plan = $self->{ plan };
    
    if ($ran < $plan) {
        $self->test_msg( too_few => $plan, $ran );
    }
    elsif ($ran > $plan) {
        $self->test_msg( too_many => $plan, $ran );
    }
}

sub DESTROY {
    shift->finish;
}


1;

__END__

=head1 NAME

Badger::Test::Manager - test manager module

=head1 SYNOPSIS

    use Badger::Test::Manager;

    # object methods
    my $manager = Badger::Test::Manager->new( plan => 7 );
    $manager->ok($bool, 'This is a test');
    $manager->pass('This is ok');
    $manager->fail('This is not ok');
    $manager->is($this, $this, 'This and that are equal');
    $manager->isnt($this, $this, 'This and that are not equal');
    $manager->like($this, qr/that/, 'This is matched by that');
    $manager->unlike($this, qr/that/, 'This is not matched by that');

    # class methods
    Badger::Test::Manager->plan(7);
    Badger::Test::Manager->ok($bool, 'This is a test');
    Badger::Test::Manager->pass('This is ok');
    Badger::Test::Manager->fail('This is not ok');
    # ... plus is(), isnt(), like() unlike() methods, as above
    
=head1 DESCRIPTION

This module implements a simple test manager for L<Badger::Test>.

=head1 METHODS

All methods can be called as class methods or object methods.  In the
case of class methods, they are called against a prototype object
returned by the L<prototype()|Badger::Prototype/protoype()> method
inherited from L<Badger::Prototype>.

=head2 plan($tests)

How many tests you plan to run.  An error will be thrown if you try
to call this method twice.

=head2 result($flag,@args)

Low-level method to generate a test result.

=head2 ok($flag, $name)

Report on the success or failure of a test:

    $manager->ok(1, 'This is good');
    $manager->ok(0, 'This is bad');

=head2 is($this, $that, $name)

Test if the first two arguments are equal.

    $manager->is($this, $that, "This and that are equal");

=head2 isnt($this, $that, $name)

Test if the first two arguments are not equal.

    $manager->isnt($this, $that, "This and that are equal");

=head2 like($text, qr/regex/, $name)

Test if the first argument is matched by the regex passed as the second
argument.

    $manager->like($this, qr/like that/i, "This and that are alike");

=head2 unlike($text, qr/regex/, $name)

Test if the first argument is not matched by the regex passed as the second
argument.

    $manager->unlike($this, qr/like that/i, "This and that are unalike");

=head2 pass($name)

Pass a test.

    $manager->pass('Module Loaded');

=head2 fail($name)

Fail a test.

    $manager->fail('Stonehenge crushed by a dwarf');

=head2 skip_all($reason)

Skip all tests.  This should be called instead of L<plan()>

    $manager->skip_all("We don't have that piece of scenery any more");

=head2 colour($flag)

Method to enable or disable colour mode.

=head2 color($flag)

An alias for L<colour()>.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Test>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
