#========================================================================
#
# Badger::Logic
#
# DESCRIPTION
#   Simple parser and evaluator for boolean logic expressions, e.g. 
#   'purple or orange', 'animal and (eats_nuts or eats_berries)'
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Logic;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Base',
    as_text   => 'text',
    constants => 'HASH',
    constant  => {
        LOGIC => 'Badger::Logic',
    },
    exports   => {
        any   => 'LOGIC Logic',
    },
    messages  => {
        no_text   => 'No text expression specified.',
        no_rhs    => 'Missing expression following "%s"',
        bad_text  => 'Unexpected text in expression: %s',
        parse     => 'Could not parse logic expression: %s',
        no_rparen => 'Missing ")" at end of nested expression',
    };

our $NODE = {
    'item' => 'Badger::Logic::Item',
    'not'  => 'Badger::Logic::Not',
    'and'  => 'Badger::Logic::And',
    'or'   => 'Badger::Logic::Or',
};

*test = \&evaluate;


sub Logic {
    return @_
        ? LOGIC->new(@_)
        : LOGIC;
}

sub new {
    my $class = shift;
    my $text  = shift;
    return $class->error_msg('no_text') 
        unless defined $text;
    bless {
        text => ref $text ? $text : \$text,
    }, $class;
}

sub evaluate {
    my $self = shift;
    my $args = @_ && ref $_[0] eq HASH ? shift : { @_ };
    $self->tree->evaluate($args);
}

sub tree {
    my $self = shift;
    return $self->{ tree } 
       ||= $self->parse($self->{ text });
}

sub text {
    shift->tree->text;
}

sub parse {
    my $self = shift;
    my $text = shift;
    my $tref = ref $text ? $text : \$text;
    $self->debug("parse($$tref)\n") if DEBUG;
    my $expr = $self->parse_expr($tref) 
        || return $self->error_msg( parse => $$tref );
    if ($$tref =~ / \G \s* (.+) $/cigsx) {
        return $self->error_msg( bad_text => $1 );
    }
    return $expr;
}

sub parse_expr {
    my $self = shift;
    my $text = shift;
    my $left = $self->parse_unary($text) || return;

    if ($$text =~ / \G \s+ (and|or) \s+ /cigx) {
        my $op = $1;
        $self->debug("binary op: $op\n") if $DEBUG;
        my $right = $self->parse_expr($text)
            || return $self->error_msg( no_rhs => $op );
        return $NODE->{ lc $op }->new( $left, $right );
    }
    elsif ($$text =~ / \G \s* \( /cgx) {
        my $expr = $self->parse_expr($text)
            || return $self->error_msg( no_rhs => '(' );
        $$text =~ / \G \s* \) /cgx
            || return $self->error_msg('no_rparen');
        
        return $self->error_msg( bad_text => $1 );
    }

    return $left;
}

sub parse_unary {
    my $self = shift;
    my $text = shift;

    if ($$text =~ / \G \s* (not) \s+ /cigx) {
        my $op = $1;
        $self->debug("unary op: $op\n") if $DEBUG;
        my $right = $self->parse_term($text)
            || return $self->error_msg( no_rhs => $op );
        return $NODE->{ lc $op }->new($right);
    }
    return $self->parse_term($text)
        || $self->decline('Not a unary expression');
}

sub parse_term {
    my $self = shift;
    my $text = shift;

    if ($$text =~ / \G \s* (\w+) /cigx) {
        $self->debug("item: $1\n") if $DEBUG;
        return $NODE->{ item }->new($1);
    }
    elsif ($$text =~ / \G \s* \( /cgx) {
        my $expr = $self->parse_expr($text)
            || return $self->error_msg( no_rhs => '(' );
        $$text =~ / \G \s* \) /cgx
            || return $self->error_msg('no_rparen');
        return $expr;
    }

    return $self->decline('Not a term');
}


#=======================================================================
# node types
#=======================================================================

package Badger::Logic::Expr;
use base 'Badger::Base';

sub new {
    my $class = shift;
    bless [ @_ ], $class;
}

package Badger::Logic::Item;
use base 'Badger::Logic::Expr';

sub evaluate {
    my $self = shift;
    my $args = @_ && ref $_[0] eq 'HASH' ? shift : { @_ };
    return $args->{ $self->[0] };
}

sub text {
    $_[0]->[0];
}

package Badger::Logic::Not;
use base 'Badger::Logic::Expr';

sub evaluate {
    my $self = shift;
    return $self->[0]->evaluate(@_) ? 0 : 1;
}

sub text {
    my $self = shift;
    '(not ' . $self->[0]->text . ')';
}

package Badger::Logic::And;
use base 'Badger::Logic::Expr';

sub evaluate {
    my $self = shift;
    return $self->[0]->evaluate(@_) 
        && $self->[1]->evaluate(@_);
}

sub text {
    my $self = shift;
    '(' . $self->[0]->text . ' and ' . $self->[1]->text . ')';
}

package Badger::Logic::Or;
use base 'Badger::Logic::Expr';

use Badger::Debug ':all';
sub evaluate {
    my $self = shift;
    return $self->[0]->evaluate(@_) 
        || $self->[1]->evaluate(@_);
}

sub text {
    my $self = shift;
    '(' . $self->[0]->text . ' or ' . $self->[1]->text . ')';
}

1;
__END__

=head1 NAME

Badger::Logic - parse and evaluate simple logical expressions

=head1 SYNOPSIS

    use Badger::Logic 'Logic';
    
    my $logic  = Logic('animal and (eats_nuts or eats_berries)');
    my $values = {
        animal    => 1,
        eats_nuts => 1,
    }
    
    if ($logic->test($values)) {
        print "This is an animal that eats nuts or berries\n";
    }

=head1 DESCRIPTION

This module implements a simple parser and evaluator for boolean logic
expressions.  It evolved from a piece of code that I originally wrote to
handle role-based authentication in web applications. 

=head1 EXPORTABLE SUBROUTINES

=head2 LOGIC

This is a shortcut alias to C<Badger::Logic>.

    use Badger::Logic 'LOGIC';
    
    my $logic = LOGIC->new($expr);      # same as Badger::Logic->new($expr);

=head2 Logic()

This subroutine returns the name of the C<Badger::Logic> class when called
without arguments. Thus it can be used as an alias for C<Badger::Logic>
as per L<LOGIC>.

    use Badger::Logic 'Logic';
    
    my $logic = Logic->new($expr);      # same as Badger::Logic->new($expr);

When called with arguments, it creates a new C<Badger::Logic> object.

    my $logic = Logic($expr);           # same as Badger::Logic->new($expr);

=head1 METHODS

=head2 new($expr)

Constructor method to create a new C<Badger::Logic> object from an expression.

    my $logic = Badger::Logic->new('animal and (cat or dog)');

=head2 evaluate($values) / test($values)

Method to evaluate the expression.  A reference to a hash array should be 
passed containing the values that the expression can test.

    my $values = {
        animal => 1,
        cat    => 1,
    };
    
    if ($logic->evaluate($values)) {
        print "This animal is a cat or a dog\n";
    }

=head2 tree()

Returns a reference to the root of a tree of C<Badger::Logic::Node> objects
that represent the parsed expression.

=head1 INTERNAL METHODS

=head2 parse($text)

Main method to parse a logical expression.  This calls L<parse_expr()> and
then checks that all of the text has been successfully parsed.  It returns 
a reference to a C<Badger::Logic::Node> object.

=head2 parse_expr($text)

Method to parse a binary expression.

=head2 parse_unary($text)

Method to parse a unary expression.

=head2 parse_term($text)

Method to parse a single term in a logical expression.

=head1 AUTHOR

Andy Wardley L<http://wardley.org>

=head1 COPYRIGHT

Copyright (C) 2007-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
