#!/bin/sh

# This script is executed by the rpmbuild process to fix the perl_lib path and
# create the apache conf.d file

ROOT=$1

pushd $ROOT

# Include eprints apache conf using a conf.d file
mkdir -p ${ROOT}/etc/httpd/conf.d
echo "Include /opt/eprints3/cfg/apache.conf" > ${ROOT}/etc/httpd/conf.d/eprints3.conf

# Fix the perl path in the script files
pushd ${ROOT}/opt/eprints3/bin
for i in `ls`; do
	echo "Fixing Perl include in: $i"
	sed "s|${ROOT}||" < $i > "${i}.new"
	mv "${i}.new" $i
	chmod 755 $i
done
popd

# Fix the base_path in SystemSettings
pushd ${ROOT}/opt/eprints3/perl_lib/EPrints
sed "s|${ROOT}||" < 'SystemSettings.pm' > "SystemSettings.pm.new"
mv "SystemSettings.pm.new" SystemSettings.pm
popd

popd
