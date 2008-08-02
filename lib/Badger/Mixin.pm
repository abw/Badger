#========================================================================
#
# Badger::Mixin
#
# DESCRIPTION
#   Base class for mixins that allow you to "mix in" functionality using
#   composition rather than inheritance.  Similar in concept to roles,
#   although operating at a slightly lower level.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Mixin;

use Badger::Class
    version   => 3.00,
    debug     => 0,
    base      => 'Badger::Exporter',
    import    => 'class',
    constants => 'PKG REFS ONCE ARRAY DELIMITER',
    words     => 'EXPORT_TAGS MIXINS';


sub mixin {
    my $self   = shift;
    my $target = shift || (caller())[0];
    my $class  = $self->class;
    my $mixins = $class->list_vars(MIXINS); 
    $self->debug("mixinto($target): ", $self->dump_data($mixins), "\n") if $DEBUG;
    $self->export($target, $mixins);
}

sub mixins {
    my $self   = shift;
    my $syms   = @_ == 1 ? shift : [ @_ ];
    my $class  = $self->class;
    my $mixins = $class->var_default(MIXINS, [ ]);
    
    $syms = [ split(DELIMITER, $syms) ] 
        unless ref $syms eq ARRAY;

    push(@$mixins, @$syms);
    $self->export_any($syms);
    
    return $mixins;
}


1;
