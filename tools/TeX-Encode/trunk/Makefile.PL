use 5.008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'TeX::Encode',
    VERSION_FROM      => 'lib/TeX/Encode.pm', # finds $VERSION
    PREREQ_PM         => {
		Pod::LaTeX => 0.56,
		HTML::Parser => 3.35,
		HTML::Entities => 1.27,
		Test::More => 0.1,
		Encode::Encoding => 0.1,
	}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/TeX/Encode.pm', # retrieve abstract from module
       AUTHOR         => 'Timothy D Brody <tdb01r@ecs.soton.ac.uk>') : ()),
	dist		=> { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);
