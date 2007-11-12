use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Net::Honeycomb',
    VERSION_FROM      => 'lib/Net/Honeycomb.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Net/Honeycomb.pm', # retrieve abstract from module
       AUTHOR         => 'Christopher Gutteridge <cjg@ecs.soton.ac.uk>') : ()),
    LIBS              => ['-L/home/cjg/Projects/eprints/Honeycomb/StorageTek5800_SDK_1_1_82/c/Linux/lib -lhoneycomb -ldl'],
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => '-I.', # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
     OBJECT            => '$(O_FILES)', # link all the C files too
);
