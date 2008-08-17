package Badger::Docs::Pod;

use Badger::Class
    version     => 0.01,
    debug       => 1,
    base        => 'Pod::Parser',
    set_methods => 'tree',
    constant    => {
        PARSE_TREE => 'Pod::ParseTree',
    };

use Badger::Debug 'debug';


sub begin_pod {
    my $self = shift;
    print "begin_pod\n";
    $self->debug("begin_pod()\n") if $DEBUG;
    $self->{ tree    } = $self->PARSE_TREE->new;
    $self->{ options } = { };
}

sub command {
    my ($self, $command, $paragraph, $line, $pod_para) = @_;
    print "command_pod\n";
    $self->debug("command($command, $paragraph, $line, $pod_para)\n") if $DEBUG;
#    $pod_para−>parse_tree( $parser->parse_text( $self->{ options }, $paragraph, $line );
    $self->tree->append( $pod_para );
}

sub verbatim {
    my ($self, $paragraph, $line, $pod_para) = @_;
    $self->debug("verbatim($paragraph, $line, $pod_para)\n") if $DEBUG;
    $self->tree->append( $pod_para );
}

sub textblock {
    my ($self, $paragraph, $line, $pod_para) = @_;
#    my $ptree = $parser−>parse_text({<<options>>}, $paragraph, ...);
#    $pod_para−>parse_tree( $ptree );
    $self->tree->append( $pod_para );
}


1;
