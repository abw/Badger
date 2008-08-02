# test the ability to specify explicit package symbols and subroutine 
# references in export declarations

package My::Exporter::Explicit::Math;

use constant {
    E   => 2.718,
    PI  => 3.141,
    PHI => 1.618,
};

our $ANSWER = 42;


package My::Exporter::Explicit::Science;

sub physics {
    return "E=mc^2";
}

sub biology {
    return "evolution";
}

sub chemistry {
    return "2 H2O -> 2 H2 + O2";
}


package My::Exporter::Explicit;

use Badger::Class
    exports => {
        tags => {
            math => {
                E   =>  'My::Exporter::Explicit::Math::E',
                PI  => '&My::Exporter::Explicit::Math::PI',
                PHI => \&My::Exporter::Explicit::Math::PHI,
                '$ANSWER' => '$My::Exporter::Explicit::Math::ANSWER',
            },
            science   => {
                physics   => 'My::Exporter::Explicit::Science::physics',
                biology   => '&My::Exporter::Explicit::Science::biology',
                chemistry => \&My::Exporter::Explicit::Science::chemistry,
            },
        }
    };



    
1;
