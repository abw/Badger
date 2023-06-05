package Badger::Filter;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    import    => 'class',
    base      => 'Badger::Base',
    utils     => 'is_object',
    constants => 'NONE ALL TRUE FALSE CODE REGEX ARRAY HASH',
    constant  => {
        FILTER => 'Badger::Filter',
    },
    exports   => {
        any   => 'FILTER Filter',
    };


sub Filter { 
    return FILTER unless @_; 
    return @_ == 1 && is_object(FILTER, $_[0])
        ? $_[0]                                 # return existing Filter object
        : FILTER->new(@_);                      # or construct a new one
}

#-----------------------------------------------------------------------------
# Initialisation methods
#-----------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    my $class  = $self->class;
    my $accept = $config->{ accept };
    my ($include, $exclude);

    if ($accept) {
        if ($accept eq ALL) {
            # default behaviour - no include, no exclude
        }
        elsif ($accept eq NONE) {
            $exclude = '*';
        }
        else {
            # list of "item" (include), "-item" (exclude) or "+item" (include)
            my @items = split(/[^\w\-\+]+/, $accept);
            my (@inc, @exc);

            foreach my $item (@items) {
                if      ($item =~ s/^\-//)  { push(@exc, $item); }
                elsif   ($item =~ s/^\+//)  { push(@inc, $item); }
                else                        { push(@inc, $item); }
            }
            $include = \@inc if @inc;
            $exclude = \@exc if @exc;
        }
    }
    else {
        $include = $class->list_vars(
            INCLUDE => $config->{ include }
        );
        $exclude = $class->list_vars(
            EXCLUDE => $config->{ exclude }
        );
    }

    $self->{ include } = $self->init_filter_set(
        include => $include
    ) if $include;

    $self->{ exclude } = $self->init_filter_set(
        exclude => $exclude
    ) if $exclude;

    return $self;
}

sub init_filter_set {
    my ($self, $name, @items) = @_;
    my $static  = { };
    my $dynamic = [ ];
    my $n       = 0;

    $self->debug(
        "init_filter_set($name) : ", 
        $self->dump_data(\@items)
    ) if DEBUG;

    while (@items) {
        my $item = shift @items;

        if (! ref $item) {
            if ((my $copy = $item) =~ s/\*/.*/g) {
                push(@$dynamic, sub { $_[0] =~ /^$copy$/ });
                $self->debug("$name: set wildcard item: $item") if DEBUG;
            }
            else {
                $static->{ $item } = 1;
                $self->debug("$name: set static item: $item") if DEBUG;
            }
            $n++;
        }
        elsif (ref $item eq ARRAY) {
            unshift(@items, @$item);
            $self->debug("$name: expanded array: ", $self->dump_data($item)) if DEBUG;
        }
        elsif (ref $item eq HASH) {
            my $truly = {
                map  { @$_   }                  # unpack key and value
                grep { $_[1] }                  # only accept true value
                map  { [$_, $item->{ $_ }] }    # pack key and value
                keys %$item
            };
            @$static{ keys %$truly } = map { 1 } values %$truly;
            $n += scalar keys %$truly;
            $self->debug("$name: set hash of true items: ", $self->dump_data($truly)) if DEBUG;
        }
        elsif (ref $item eq CODE) {
            push(@$dynamic, $item);
            $n++;
            $self->debug("$name: added code ref: $item") if DEBUG;
        }
        elsif (ref $item eq REGEX) {
            my $regex = $item;
            push(@$dynamic, sub { $_[0] =~ $regex });
            $n++;
            $self->debug("$name: added regex: $item") if DEBUG;
        }
        else {
            return $self->error_msg( invalid => $name => $item );
        }
    }

    return undef unless $n;

    my $set = {
        static  => $static,
        dynamic => $dynamic,
    };

    $self->debug(
        "init_filter_set($name) $n items: ", 
        $self->dump_data($set)
    ) if DEBUG;

    return $set;
}


#-----------------------------------------------------------------------------
# List filtering methods
#-----------------------------------------------------------------------------

sub accept {
    my $self   = shift;
    my $items  = (@_ == 1 && ref $_[0] eq ARRAY) ? shift : [@_];
    my @accept = grep { $self->item_accepted($_) } @$items;
    return wantarray
        ?  @accept
        : \@accept;
}

sub reject {
    my $self   = shift;
    my $items  = (@_ == 1 && ref $_[0] eq ARRAY) ? shift : [@_];
    my @reject = grep { $self->item_rejected($_) } @$items;
    return wantarray
        ?  @reject
        : \@reject;
}


#-----------------------------------------------------------------------------
# Item filtering methods
#-----------------------------------------------------------------------------

sub item_accepted {
    my ($self, $item) = @_;
    return  $self->item_included($item)
        && !$self->item_excluded($item);
}

sub item_rejected {
    ! shift->item_accepted(@_);
}

sub item_included {
    my $self    = shift;
    my $include = $self->{ include } || return TRUE;
    return $self->check_item($include, @_);
}

sub item_excluded {
    my $self    = shift;
    my $exclude = $self->{ exclude } || return FALSE;
    return $self->check_item($exclude, @_);
}

sub check_item {
    my ($self, $checks, $item) = @_;

    $self->debug(
        "check [$item] via ", 
        $self->dump_data($checks)
    ) if DEBUG;

    return TRUE 
        if $checks->{ static }->{ $item }
        || $checks->{ static }->{"*"};

    foreach my $check (@{ $checks->{ dynamic } }) {
        $self->debug("check: $check") if DEBUG;
        return TRUE
            if $check->($item);
    }

    return FALSE;
}


1;

__END__

=head1 NAME

Badger::Filter - object for simple filtering

=head1 SYNOPSIS

    use Badger::Filter;
    
    # filter to only include certain things
    my $filter = Badger::Filter->new(
        include => [
            'meat',
            qr/beer|wine/,
            sub { $_[0] eq 'soda' },
        ],
    );

    # filter to only exclude certain things
    my $filter = Badger::Filter->new(
        exclude => [
            'cheese',
            qr/alcohol-free|salad|diet/,
            sub { $_[0] eq 'diet soda' },
        ],
    );

    # filter to include and exclude
    my $filter = Badger::Filter->new(
        include => [
            ...
        ],
        exclude => [
            ...
        ],
    );

    # filtering items
    my @items = $filter->accept(
        'meat', 'cheese', 'potato salad', 'green salad',
        'beer', 'alcohol-free beer',
        'wine', 'soda', 'diet soda'
    );

=head1 DESCRIPTION

This module defines a simple object for filtering data.  Items can be 
included and/or excluded via a simple set of rules.

    use Badger::Filter;
    
    my $filter = Badger::Filter->new(
        include => [
            # inclusion rules
        ],
        exclude => [
            # exclusion rules
        ],
    );

The rules that can be specified in either L<include> or L<exclude> options
can be simple strings, regular expressions, hash or list references.

    my $filter = Badger::Filter->new(
        include => [
            'meat',                     # fixed string
            qr/beer|wine/,              # regular expression
            sub { $_[0] eq 'soda' },    # subroutine,
            {
                foo => 1,               # 'foo' fixed string
                bar => 1,               # 'bar' fixed string
                baz => 0,               # ignored (not a true value)
            },
        ],
    );

The L<accept()> method returns any items that match any of the L<include>
rules and don't match any L<exclude> rules.

    my @matching = $filter->accept(@candidates);

If there are any L<include> rules, then a candidate item must match at least 
one of them to be included.  If there aren't any L<include> rules then the 
candidate is assumed to be included by default.

All candidates that are included are then filtered through the L<exclude> 
rules.  If a candidate matches an exclude rule then it is rejected.  If it
doesn't match an L<exclude> rule, or there aren't any L<exclude> rules
defined then the candidate item is accepted.

=head1 CONFIGURATION OPTIONS

=head2 include

One or more items that should be included (i.e. not filtered out) by the 
filter.  This can be any of:

=over 4

=item *

A simple string.  This should match a candidate string exactly for it
to be included.

=item *

A string containing a '*' wildcard character, e.g. C<foo/*>.  The star is used
to represent any sequence of characters.

=item *

A regular expression.  This should match a candidate string for it to
be included.

=item *

A code reference.  The function will be called, passing the candidate as the 
only argument.  It should return any TRUE value if the item should be included
or false if not.

=item *

A hash reference.  All keys in the hash reference with corresponding values
set to any TRUE value are considered to be simple, static strings that a 
candidate string should match.

=item *

A list reference.  Containing any of the above.

=back

=head2 exclude

One or more items that should be excluded (i.e. filtered out) by the 
filter.  This can be any of the same argument types as for L<include>.

=head1 METHODS

=head2 new(%options)

Constructor method.

    my $filter = Badger::Filter->new(
        include => ['badger'],
        exclude => ['ferret'],
    );

=head2 accept(@items)

Returns a list (in list context) or reference to a list (in scalar context)
of all items passed as arguments that are accepted (passed through) by the 
filter.  Each item is tested via a call to L<item_accepted()>.

=head2 reject(@items)

Returns a list (in list context) or reference to a list (in scalar context)
of all items passed as arguments that are rejected by the filter.  Each item
is tested via a call to L<item_rejected()>).

=head2 item_accepted($item)

Return true if the item is included (via a call to the L<item_included()> 
method) and not excluded (ditto to L<item_excluded>).

    my $accept = $filter->item_accepted($candidate);

=head2 item_rejected($item)

Return the logical opposite of L<accepted()>. 

    my $reject = $filter->item_rejected($candidate);

=head2 item_included($item)

Tests if C<$item> should be included by the filter (i.e. passed through, NOT
filtered out).

If there is no L<include> specification defined then the item is accepted
by default (return value is TRUE).  

If there is an L<include> specification then the item must match any one of 
the L<include> checks for it to be included (returns TRUE), otherwise it is 
rejected (returns FALSE).

=head2 item_excluded($item)

Tests if C<$item> should be excluded by the filter (i.e. NOT passed through, 
filtered out).

If there is no L<exclude> specification defined then the item is accepted
by default.  In this case, the return value is FALSE (i.e. item is NOT 
excluded, thus it is included).

If there is an L<exclude> specification then the item will be excluded (return
value is TRUE) if it matches any of the L<exclude> checks.  Otherwise the
method returns FALSE to indicate that the item is NOT excluded (i.e. included).

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2013 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
