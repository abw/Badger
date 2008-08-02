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

use Badger::Class
    base    => 'Badger::Exporter',
    version => 0.01,
    debug   => 0,
    exports => {
        any => [qw( 
            debug debug_caller
            dump_data dump_data_inline
            dump_hash dump_list dump_text 
        )],
        hooks => {
            color  => \&enable_colour,
            colour => \&enable_colour,
        },
    };

use Badger::Rainbow 
    ANSI => 'bold red yellow green cyan';
    
our $PAD       = '    ';
our $TEXTLEN   = 32;
our $MAX_DEPTH = 2;    # prevent runaways in debug/dump
our $FORMAT    = "[<class> line <line>] <msg>"  
    unless defined $FORMAT;


#-----------------------------------------------------------------------
# debug($message, $more_messages, ...)
#
# Print debugging message.
#-----------------------------------------------------------------------

sub debug {
    my $self   = shift;
    my $msg    = join('', @_),
    my $class  = ref $self || $self;
    my $format = $FORMAT;
    my ($pkg, $file, $line) = caller();
    $class .= " ($pkg)" unless $class eq $pkg;
    my $data = {
        msg   => $msg,
        class => $class,
        file  => $file,
        line  => $line,
    };
    $format =~ s/<(\w+)>/defined $data->{ $1 } ? $data->{ $1 } : "<$1 undef>"/eg;
    print STDERR $format;
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
        return $data;
    }
}

sub dump_data_inline {
    local $PAD = '';
    my $text = shift->dump_data(@_);
    $text =~ s/\n/ /g;
    return $text;
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
}



1;

__END__

=head1 NAME

Badger::Debug - base class mixin module implement debugging methods

=head1 SYNOPSIS

    package Badger::Whatever;
    use Badger::Debug 'debug';

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
