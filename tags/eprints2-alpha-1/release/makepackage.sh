#!/bin/sh

if [ $# != "4" ]; then
	echo "Usage: makepackage.sh <cvs-version-tag> <package-version> <license-file> <package-filename>"
	exit 1
fi

VERSION_TAG=$1
PACKAGE_VERSION=$2
LICENSE_FILE=`pwd`/$3
PACKAGE_FILE=$4

# Remove the package and export dirs if appropriate
if [ -d "package" ]; then
	/bin/rm -r package
fi

if [ -d "export" ]; then
	/bin/rm -r export
fi

# Check out the code
mkdir export
mkdir package

echo "Exporting from CVS..."

cd export
cvs export -r $VERSION_TAG eprints/system >/dev/null

# Remove the .cvsignore files
/bin/rm `find . -name '.cvsignore'`

echo "Inserting license information..."

# Insert the license information.
FILES=`grep -l "__LICENSE__" eprints/system/bin/* eprints/system/cgi/* eprints/system/cgi/users/* eprints/system/cgi/staff/* eprints/system/lib/*.pm eprints/system/site_lib/*.pm`

for i in $FILES; do
	../insert_license.pl $LICENSE_FILE "$PACKAGE_VERSION" $i
done


echo "Making tarfile..."

# Now make the tar.

mv eprints/system ../package/eprints
cd ../package

# STOPGAP!!!!! Add documents directory
mkdir eprints/html/documents

# Move the library directories (as of version beta-2)
mkdir eprints/perl_lib
mv eprints/lib eprints/perl_lib/EPrints
mv eprints/site_lib eprints/perl_lib/EPrintSite

# Add the installation script
cp -a ../install-scripts/* eprints
cd eprints
autoconf
cd ..

# Remove group write permission
chmod -R g-w eprints
mv eprints $PACKAGE_FILE
# aryan
tar czf ../$PACKAGE_FILE.tar.gz $PACKAGE_FILE

cd ..

echo "Removing temporary directories..."

# Remove the temp dirs.
/bin/rm -r package
/bin/rm -r export

echo "Done."
