dnl
dnl Functions for eprints installation script
dnl

dnl **************************************************************
dnl Check that a particular Perl module is installed
dnl **************************************************************

AC_DEFUN(CHECK_PERL_MOD,
[
AC_MSG_CHECKING(for Perl module: $1)
RESULT=`$PERL_PATH -m"$1"  -e 'print "1\n";'`

if test "x$RESULT" = "x1" ; then
	AC_MSG_RESULT(yes)
else
	AC_MSG_RESULT(no)
	echo "***************************************************************"
	echo "*** Please consult the eprints documentation on how to"
	echo "*** install this missing module. Configuration will now"
	echo "*** continue, but EPrints may not work until this module"
	echo "*** had been installed."
	echo "***************************************************************"
	AC_MSG_ERROR(Perl module $1 not installed)
fi
])


dnl **************************************************************
dnl Test if a perl module is installed and set an environment 
dnl Variable
dnl **************************************************************

AC_DEFUN(TEST_PERL_MOD,
[
AC_MSG_CHECKING(for Perl module: $2)
RESULT=`$PERL_PATH -e 'use $2 $3; print "1\n";' 2>/dev/null`

if test "x$RESULT" = "x1" ; then
	$1=1
	AC_SUBST( $1, "1" )
	AC_MSG_RESULT(yes)
else
	$1=0
	AC_SUBST( $1, "0" )
	AC_MSG_RESULT(no)
fi
])


dnl **************************************************************
dnl Check that a Perl module is installed without "using" it
dnl This is required for modules like Apache::DBI which can't be
dnl used by normal scripts.
dnl **************************************************************

AC_DEFUN(CHECK_PERL_MOD_EXISTS,
[
AC_MSG_CHECKING(for Perl module: $1)

dnl Get the file path; e.g. "Apache::DBI" -> "Apache/DBI/pm"
MOD_DIR_PATH=`echo $1 | sed 's/::/\//g' | sed 's/$/.pm/'`

dnl Check perl's include path for it
PERL_FOUND_MOD=`$PERL_PATH -e 'foreach (@INC) {print "1\n" if -e "$_/'$MOD_DIR_PATH'"}'`

if test "x$PERL_FOUND_MOD" = "x" ; then
	ac_mSG_RESULT(no)
	AC_MSG_WARN(Perl module $1 not installed)
	echo "***************************************************************"
	echo "*** Please consult the eprints documentation on how to"
	echo "*** install this missing module. Configuration will now"
	echo "*** continue, but EPrints may not work until this module"
	echo "*** had been installed."
	echo "***************************************************************"
else
	AC_MSG_RESULT(yes)
fi
])
