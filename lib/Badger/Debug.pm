#========================================================================
#
# Badger::Debug
#
# DESCRIPTION
#   Base class mixin module implementing functionality for debugging.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Debug;

use Badger::Class
    base    => 'Badger::Exporter',
    version => 0.01,
    debug   => 0,
    exports => {
        all => [qw( 
            dump_hash dump_list dump_text dump_data 
            dump_data_inline debug_caller 
        )],
        hooks => {
            color  => \&enable_colour,
            colour => \&enable_colour,
        },
    },
    constant => {
        COLOURS => {
            bold    =>  1,
            dark    =>  2,
            black   => 30,
            red     => 31,
            green   => 32,
            yellow  => 33,
            blue    => 34,
            magenta => 35,
            cyan    => 36, 
            white   => 37,
        },
    };

our $PAD       = '    ';
our $TEXTLEN   = 32;
our $MAX_DEPTH = 2;    # prevent runaways in debug/dump

BEGIN {
    my $c = COLOURS;
    no strict 'refs';
    
    # define subroutines: bold, dark, black, red, green, yellow, etc.
    while (my ($col, $n) = each %$c) {
        my $name = __PACKAGE__ . '::' . $col;
        *{$name} = sub(@) { ANSI_escape_lines($n, @_) }
            unless defined &{$name};
    }
}


#------------------------------------------------------------------------
# dump()
#
# Debugging method to return a text representation of the object 
# internals.
#------------------------------------------------------------------------

sub dump {
    my $self = shift;
    $self->dump_data($self);
}


#------------------------------------------------------------------------
# dump_data($item)
#
# Debugging method to return a text representation of a value, calling
# the appropriate dump_hash() or dump_list() method as appropriate.
#------------------------------------------------------------------------

sub dump_data {
    my ($self, $data, $indent) = @_;
    $indent ||= 0;

    if (defined $data) {
        return $data unless ref $data;
    }
    else {
        return '<undef>';
    }

    if (UNIVERSAL::isa($data, 'HASH')) {
        return $self->dump_hash($data, $indent);
    }
    elsif (UNIVERSAL::isa($data, 'ARRAY')) {
        return $self->dump_list($data, $indent);
    }
    elsif (UNIVERSAL::isa($data, 'Regexp')) {
        return $self->dump_text("$data");
    }
    elsif (UNIVERSAL::isa($data, 'SCALAR')) {
        return $self->dump_text($$data);
    }
    else {
#       print STDERR "can't dump data: $data\n";
        return $data;
    }
}

sub dump_data_inline {
    local $PAD = '';
    my $text = shift->dump_data(@_);
    $text =~ s/\n/ /g;
    return $text;
#    goto \&dump_data;
}


#------------------------------------------------------------------------
# dump_hash(\%hash)
#
# Debugging method to return a text representation of a hash reference.
#------------------------------------------------------------------------

sub dump_hash {
    my ($self, $hash, $indent) = @_;
    $indent ||= 0;
    return "..." if $indent > $MAX_DEPTH;
    my $pad = $PAD x $indent;
    
    return '{ }' unless $hash && %$hash;
    return "\{\n" 
        . join( ",\n", 
                map { "$pad$PAD$_ => " . $self->dump_data($hash->{$_}, $indent + 1) }
                sort keys %$hash ) 
        . "\n$pad}";
}


#------------------------------------------------------------------------
# dump_list(\@list)
#
# Debugging method to return a text representation of an array reference.
#------------------------------------------------------------------------

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


#------------------------------------------------------------------------
# dump_text($text, $length)
#
# Debugging method to return a truncated and sanitised representation of 
# a text string.
#------------------------------------------------------------------------

sub dump_text {
    my ($self, $text, $length) = @_;
    $text = $$text if ref $text;
    $length ||= $TEXTLEN;
    my $snippet = substr($text, 0, $length);
    $snippet .= '...' if length $text > $length;
    $snippet =~ s/\n/\\n/g;
    return $snippet;
}


#-----------------------------------------------------------------------
# ANSI_escape_text($attr, $text)
#
# Adds ANSI escape codes to each line of text to colour output.
#-----------------------------------------------------------------------

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
    $Badger::Base::DEBUG_FORMAT 
         = cyan('[<class> line <line>]')
         . yellow(' <msg>');

    # exceptions are in red
    $Badger::Exception::FORMAT 
        = bold red $Badger::Exception::FORMAT;
}


#-----------------------------------------------------------------------
# debug_caller()
#
# Print debugging information about the caller.
#-----------------------------------------------------------------------

sub debug_caller {
    my $self = shift;
    my ($pkg, $file, $line, $sub) = caller(1);
    my $msg = "$sub called from ";
    ($pkg, undef, undef, $sub) = caller(2);
    $msg .= "$sub in $file at line $line\n";
    $self->debug($msg);
}


1;

__END__

=head1 NAME

Badger::Debug - base class mixin module implement debugging methods

=head1 SYNOPSIS

    package Badger::Whatever;
    use Badger::Debug;

    sub some_method {
        my $self = shift;
        $self->debug("This is a debug message\n");
    }

=head1 DESCRIPTION

This mixin module implements a number of methods for debugging.

=head1 METHODS

=head2 debug($msg1, $msg2, ...)

At present this method simply prints all arguments to STDERR, prefixed 
by an object identifier.  This should eventually provide alternatives,
allowing custom debug handlers to be defined, etc.

=head2 dump()

Debugging method which returns a text representation of the object internals.

    print STDERR $object->dump();

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
text string passed (directly or by references) as the first argument.

    print STDERR $object->dump_text($text);

=head2 dump_data($item)

Debugging method which calls the appropriate C<dump_hash()>, C<dump_list()> or 
C<dump_text()> method for the item passed as the first argument.

    print STDERR $object->dump_data($item);

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
