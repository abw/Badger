package Badger::Progress;

use Badger::Class
    version => 0.01,
    debug   => 0,
    base    => 'Badger::Base',
    config  => 'picture|class:PICTURE size';

our $PICTURE = <<'EOF';
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMmoNMMNmmNMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMs -NMN/:-yMMMNMMMMNMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMy``/M/`` hMNMMMMMMMMMMMdo:-yMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMN `..``.sMMMMMMMMMMMMs.```sNs//::oddMMMMMMMMMMM
MMMMMMMMMMMMMM:````-mMMMMMMMMMMMh-```.dh.````````:yMMMMMMMMM
MMMMMMMMMMMMMM/```hMMMMMMMMMMMN+```` o: ```````````:sNMMMMMM
MMMMMMMMMMMMMM-`.mMMMMMMMMMMMN:``````````````````````-ymNMMM
MMMMMMMMMMMMMy .mMMMMMMMMMMMm-``````````````````````:+yyhmhh
MMMMMMMMMMMMy`:mMMMMMMMMMMMM+ ```````````.``-:osyhNMMMMMMMNd
MMMMMMMMMMMM``MMMMMMMMMMMMN+ `````````.+dNdMMMMMMMMMMMMMMMMM
MMMMMMMMMMMy yMMMMMMMMMMMN:`````````.oNMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMo`hMMMMMMMMMMN/````````.+NMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMM+-NMMMMMMMMMM/  ``````oMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMM//MMMMMMMMMm-`:.` ```:NMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMM/oMMMMMMMMd .y-//-`` yMMMMMMMMMMMMMMMMMMMMMNNmNNN
MMMMMMMMMMN:NMMMMMMMd.`-/:-:``.yMMMMMMMMMMMMMMMMMMMMNmmmmmmh
MMMMMMMMMMy-MMMMMMMd````````.oMMMMMMMMMMMMMMMMMMMNNmNmdyyys/
MMMMMMMMMMdmMMMMMMd.`````-+hMMMMMMMMMMMMMMNmdhhhddmmdhyys+/-
MMMMMMMMMNMMMMMMMM.` ` :mMMMMMMMMMMMMMmyo:::ssyyhyshyyyoo/:-
MMMMMMMNNmmmNMNMMN:````/MMMMMMMMMMNy+:.-..-/+oo/s+oooooo+::.
MMMMMMNmssoymNMN:``````-MMMMMMds:.``..--::-:/:+:oooo/+:/::-:
MMMMMNossos+smNNNMho/.`/MMNs:.````.`.-:----://:-/o///o:.-:-.
MMMMMh./::oooyhmMNNMMh.oN+```````````..--/+/:/o/s/+s:///+:.`
MMMMMN....:/++-+NMNNMNyNo```````````.-...-/:/-+/+/o//+/o:..`
MMMMMMNy/.:`.-`-hmNNNNMM/ `````````..-.--.--::ooo++/////..--
MMMMMMMMMMMNmmNNNMMMMMNm.```````````....--/::///++s+:-::/.--
MMMMMMMMMMMMMMMMMMNmMMNd:`````````````...///o/+o++sos+:s++:/
MMMMMMMMMMMMNMMMMMMMddNN-```````````.-.--:/++/++/sosos+o:/::
EOF

sub init {
    my ($self, $config) = @_;
    $self->configure($config);
    $self->debug("picture:\n$self->{ picture }\n") if DEBUG;
    $self->{ pixels } = [split(//, $self->{ picture })];
    $self->{ max    } = scalar(@{ $self->{ pixels } });
    $self->{ count  } = 0;
    $self->{ pixel  } = 0;
    return $self;
}

sub pixel {
    my $self   = shift;
    my $pixels = $self->{ pixels };
    if ($self->{ size }) {
        $self->{ count }++;
        my $end = int( $self->{ max } * $self->{ count } / $self->{ size } );
        if ($end > $self->{ pixel }) {
            my $start = $self->{ pixel };
            $self->{ pixel } = $end;
            return substr($self->{ picture }, $start, $end - $start);
        }
        else {
            return '';
        }
    }
    else {
        return $pixels->[ $self->{ count }++ % @$pixels ];
    }
}

sub remains {
    my $self   = shift;
    my $pixels = $self->{ pixels };
    if ($self->{ size }) {
        if (my $rest = $self->{ max } - $self->{ pixel }) {
            return substr($self->{ picture }, $self->{ pixel }, $rest);
        }
    }
    return '';
}

sub reset {
    my $self = shift;
    $self->{ count } = 0;
}

1;
