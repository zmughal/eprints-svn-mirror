use 5.006000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Text::BibTeX::Yapp',
    VERSION           => '1.00',
#    VERSION_FROM      => 'lib/Text/BibTeX/Yapp.pm', # finds $VERSION
    PREREQ_PM         => {
		"Parse::Yapp::Driver" => 1.05,
	}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Text/BibTeX/Yapp.pm', # retrieve abstract from module
       AUTHOR         => 'Tim D Brody <tdb2@localdomain>') : ()),
	dist              => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);
