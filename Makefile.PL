use ExtUtils::MakeMaker;

my %opts = (
    'NAME'         => 'Badger',
    'VERSION'      => 0.07,
    'PMLIBDIRS'    => [ 'lib' ], 
    'dist'         => {
        'COMPRESS' => 'gzip',
        'SUFFIX'   => 'gz',
    },
    'test'         => {
        'TESTS'    => join(' ', glob 't/*/*.t'),
    },
);

if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
    $opts{ AUTHOR   } = 'Andy Wardley <abw@wardley.org>';
    $opts{ ABSTRACT } = 'Application programming toolkit',
    $opts{ LICENSE  } = 'perl',
}

WriteMakefile( %opts );

