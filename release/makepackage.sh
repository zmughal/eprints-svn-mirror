#!/bin/sh

if [ $# != "4" ]; then
	echo "Usage: makepackage.sh <cvs-version-tag> <package-version> <license-file> <package-filename.tar.gz>"
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
cvs export -r $VERSION_TAG eprints >/dev/null

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

# Remove group write permission
chmod -R g-w eprints

# STOPGAP!!!!! Add documents directory
mkdir eprints/html/documents

tar czf ../$PACKAGE_FILE eprints

cd ..

echo "Removing temporary directories..."

# Remove the temp dirs.
/bin/rm -r package
/bin/rm -r export

echo "Done."
