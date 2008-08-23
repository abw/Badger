package Badger::Pod::View;

use Badger::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Badger::Pod::Visitor',
    import    => 'class';

our @TEXT_METHODS   = qw( code data verbatim text );
our @BODY_METHODS   = qw( model paragraph );
our @TITLE_METHODS  = qw( head head2 head2 head3 head4 );
our @FORMAT_METHODS = qw( bold code entity italic link space index zero  );

# generate methods to map visit_xxxx() to view_xxxx()

class->methods(
    map {
        my $name  = $_;
        my $visit = 'visit_' . $_;
        my $view  = 'view_'  . $_;
        $visit => sub {
            my ($self, $item, @args) = @_;
            $self->debug("visiting $name\n") if $DEBUG;
            $self->$view( $item->text );
        },
        $view => sub {
            $_[1];
        },
    }
    @TEXT_METHODS
);

class->methods(
    map {
        my $name  = $_;
        my $visit = 'visit_' . $_;
        my $view  = 'view_'  . $_;
        $visit => sub {
            my ($self, $item, @args) = @_;
            $self->debug("visiting $name: $item to $view\n") if $DEBUG;
            $self->$view(
                join('', $item->body->visit($self, @args))
            );
        },
        $view => sub {
            $_[1];
        },
    }
    @BODY_METHODS, 
    @FORMAT_METHODS,
);

class->methods(
    map {
        my $name  = $_;
        my $visit = 'visit_' . $_;
        my $view  = 'view_'  . $_;
        $visit => sub {
            my ($self, $item, @args) = @_;
            $self->debug("visiting $name\n") if $DEBUG;
            $self->$view(
                join('', $item->title->visit($self, @args)),
                join('', $item->body->visit($self, @args))
            );
        },
        $view => sub {
            join("\n", $_[1] . $_[2]);
        },
    }
    @TITLE_METHODS
);


1;