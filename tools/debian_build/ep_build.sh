#!/bin/bash
if [ "$4" == "" ] 
then
	echo "Usage ep_build new_path last_path version";
	echo "eg. ep_build eprints-3.1.0 eprints-3.1.0-rc-6 3.1 stable";
else
	FOO=${1//eprints-/eprints_}
	cp -R $2/debian $1/
	echo "$FOO_all.deb web extra" > $1/debian/files;
	diff $2/CHANGELOG $1/CHANGELOG > changes.txt
	java ProcessChangelog $1 changes.txt
	cat $1/debian/changelog >> changes.txt
	mv changes.txt $1/debian/changelog
	cd $1
	dpkg-buildpackage -rfakeroot -edct05r@ecs.soton.ac.uk
	cd ..
	mkdir repo
	if [ "$4" == "stable" ] 
	then
		rm -fR repo/$3/
		mkdir repo/$3
		mkdir repo/$3/stable/
		mkdir repo/$3/unstable/
		mkdir repo/$3/source/
		cp ${FOO}_all.deb repo/$3/stable/
		mv ${FOO}_all.deb repo/$3/unstable/
		mv ${FOO}* repo/$3/source/
		cd repo/$3/
		dpkg-scanpackages stable /dev/null | gzip -9c > stable/Packages.gz
		dpkg-scanpackages unstable /dev/null | gzip -9c > unstable/Packages.gz
		dpkg-scansources source /dev/null | gzip -9c > source/Sources.gz
	fi
	if [ "$4" == "unstable" ]
	then
		mkdir repo/$3
		mkdir repo/$3/stable/
		mkdir repo/$3/unstable/
		mkdir repo/$3/source/
		rm -fR repo/$3/unstable/*
		rm -fR repo/$3/source/$FOO*
		mv ${FOO}_all.deb repo/$3/unstable/
		mv ${FOO}* repo/$3/source/
		rm -f repo/$3/source/Sources.gz
		cd repo/$3/
		dpkg-scanpackages unstable /dev/null | gzip -9c > unstable/Packages.gz
		dpkg-scansources source /dev/null | gzip -9c > source/Sources.gz
	fi

fi
