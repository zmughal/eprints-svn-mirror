# Make site for local previewing

# Change this to where you can look at your mockup
LOCALROOT=http://noggin.ecs.soton.ac.uk/~rht96r/eprints.org/

local: cleanlocal
	mkdir out
	./build-site.pl --siteroot=${LOCALROOT} --dest=out
	mkdir out/fr
	./build-site.pl --config=site-fr.cfg --siteroot=${LOCALROOT} --htmlroot=${LOCALROOT}fr/ --dest=out/fr

cleanlocal:
	rm -rf out
	rm -f gimp.script

target: cleantarget
	mkdir out-target
	./build-site.pl
	mkdir out-target/fr
	./build-site.pl --config=site-fr.cfg

cleantarget:
	rm -rf out-target
	rm -f gimp.script

clean: cleanlocal cleantarget


install: target
	scp -r out-target/* eprints@orgs:htdocs
