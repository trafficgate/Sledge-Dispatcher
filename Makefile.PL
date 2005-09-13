use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'      => 'Sledge::Dispatcher',
    'VERSION_FROM' => 'lib/Sledge/Dispatcher.pm', # finds $VERSION
    'PREREQ_PM' => {
	Test::More => 0.32,
    },
);
