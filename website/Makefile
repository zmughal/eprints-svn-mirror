# Make site for local previewing

# Change this to where you can look at your mockup
LOCALROOT=http://lemur.ecs.soton.ac.uk/~cjg/eprints.org/

local: cleanlocal updates
	mkdir out
	./build-site.pl --siteroot=${LOCALROOT} --dest=out
	mkdir out/fr
	./build-site.pl --config=site-fr.cfg --siteroot=${LOCALROOT} --htmlroot=${LOCALROOT}fr/ --dest=out/fr

cleanlocal:
	rm -rf out
	rm -f gimp.script

target: cleantarget updates
	mkdir out-target
	./build-site.pl
	mkdir out-target/fr
	./build-site.pl --config=site-fr.cfg

cleantarget:
	rm -rf out-target
	rm -f gimp.script

updates:
	cp ../release/install-scripts/ChangeLog in-raw/changelog.txt

clean: cleanlocal cleantarget


install: target
	scp -r out-target/* eprints@orgs:htdocs
