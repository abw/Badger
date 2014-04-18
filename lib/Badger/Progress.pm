package Badger::Progress;

use Badger::Class
    version => 0.01,
    debug   => 0,
    base    => 'Badger::Base',
    config  => 'picture|class:PICTURE size';

our $PICTURE = <<'EOF';
MMMMMMMMMMMMMMMMMMMMMMMMMZMMMOOMMMZMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMM+~.~8MMD.$MM..NM$ MMMO.MMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMM.ZO~M8...NM...DI ..M .NMZ .+MM=MMMMMMMMMMMMMMMM
MMMMMMMMMMMM:..... ...  ........ ... .... ....ZMMMMMMMMMMMMM
MMMMMI=...=N+MMMN........................ NMMM?D=...+IMMMMMM
MMM:,.. . ....MMMMN.....................MMMMM....   ..,,MMMM
MMM ..MMMMMMMMMMMMM.....................MMMMMMMMMMMMM . 8MMM
MM+. MMMMMMMMMMMMMM.....................MMMMMMMMMMMMMM .+MMM
MM7..MMMMMMMMMMMMM8.....................MMMMMMMMMMMMMM. 7MMM
MM:..MMMMMMMMMMMMM...................... MMMMMMMMMMMMM..+MMM
MMM,. MMMMMMMMMMM8.......................$MMMMMMMMMMM. ,MMMM
MD8? .MMMMMMMMMMM:........................MMMMMMMMMMM .?O8MM
MMD N~MMMMMMMMMMM.........................MMMMMMMMMMM:N.8MMM
8. .MMMMMMMMMMMMI.........................IMMMMMMMMMMMM...DM
MMM:MMMMMMMMMMMM.......................... MMMMMMMMMMMM.8MMM
N .IMMMMMMMMMMMM ......................... MMMMMMMMMMMMI  MM
MM8OMMMMMMMMMMMM ......................... MMMMMMMMMMMMO$MMM
M .OMMMMMMMMMMMM...........................MMMMMMMMMMMM8  NM
M~:OMMMMMMMMMMMM+.........................?MMMMMMMMMMMM7:~MM
$. IMMMMMMMMMMMMM.........................MMMMMMMMMMMMMI .$M
MN.=MMMMMMMMMMMMMN ..................... DMMMMMMMMMMMMM~.NM=
MMM.MMMMMMMMMMMMMMM.....................MMMMMMMMMMMMMMM 8MMM
MMO.MMMMMMMMMMMMMMMM ..................MMMMMMMMMMMMMMMM $MMM
MM~.8MMMMMMMMN7I8MMMM ............... MMMM8I7MMMMMMMMM8 +MMM
MMM  MMMMMMM= MMMMMMMM ............. MMMMMMMM IMMMMMMM. DMMM
MMM?. MMMMMMN.MM NMMMM=.............=MMMMM MM.MMMMMMM  IMMMM
MMM+ .+MMMMMMMMMMMM .MM.............MMI MMMMMMMMMMMM~  =MMMM
MMMMZ.. MMMMMMMMMMMMMMM.............MMMMMMMMMMMMMMM   ZMMMMM
MMMMMN ..=MMMMMMMMMMMMM ............MMMMMMMMMMMMM~. .NMMMMMM
MMMMMMO ...NMMMMMMMMMM$.............8MMMMMMMMMMN... DMMMMMMM
MMMMMMMM+...$MMMMMMMMM ..............MMMMMMMMM7.. ?MMMMMMMMM
MMMMMMMMMD ..:MMMMMMMM...............MMMMMMMM,...DMMMMMMMMMM
MMMMMMMMMM7...MMMMMMMM..... ... .....MMMMMMMM...IMMMMMMMMMMM
MMMMMMMMMMMO   MMMMMMM. .............MMMMMMM . 7MMMMMMMMMMMM
MMMMMMMMMMMM8  ,MMMMMO. .............DMMMMM,. OMMMMMMMMMMMMM
MMMMMMMMMMMMMN. MMMMMO..... ... .....OMMMMM .8MMMMMMMMMMMMMM
MMMMMMMMMMMMMM .IMMMMO...............OMMMM?. MMMMMMMMMMMMMMM
MMMMMMMMMMMMMMM .MMMMO   .   .   ... OMMMM..MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMM:.ZMMMO.....  .  .....OMMMM.:MMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMN ~MMMO. .............OMMM=.DMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM  MM8.  .IMMMMMMMI... =MM  MMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMM+ I  .MMMN+.....=NMMM.. I.+MMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMO.   MM .DMMMMMMMMZNMM... $MMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMM=   MN MMMMMMMMMMMMMM .. MMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMM$...IM7MMMMMMMMMMMMM?...MMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMN  .MMMMMMMMMMMMMMM . DMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMO7...$OOOOOOOOO$ ..+OMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMM?ZOOOOOOOOOOOZ?MNMMMMMMMMMMMMMMMMMMMMM
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
