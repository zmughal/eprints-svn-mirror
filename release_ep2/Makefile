.SUFFIXES : .tgz

EPRINTS_VERSION = 2.0.a
DATE = date +%Y-%m-%d

NIGHTLY_DESC = "EPrints $(EPRINTS_VERSION) Alpha (Nightly Build "`$(DATE)`")"
NIGHTLY_VERSION = "$(EPRINTS_VERSION)-"`$(DATE)`
MILESTONE_DESC_A = "EPrints $(EPRINTS_VERSION) (
MILESTONE_DESC_B = ) [Born on "`$(DATE)`"]"
MILESTONE_VERSION = "$(EPRINTS_VERSION)"
CODENAME_foo.tar.gz = "hello mum"


eprints2-nightly.tar.gz:
	echo HEAD $(NIGHTLY_VERSION) $(NIGHTLY_DESC) licenses/gpl.txt eprints-nightly 
	./makepackage.pl HEAD $(NIGHTLY_VERSION) $(NIGHTLY_DESC) licenses/gpl.txt eprints-nightly 

eprints2-alpha-1.tar.gz:
	./makepackage.pl eprints2-alpha-1 $(MILESTONE_VERSION) $(MILESTONE_DESC_A)Anchovy$(MILESTONE_DESC_B) licenses/gpl.txt 

ddx:

foo.tar.gz: 
A=1
	echo $(A)
bar.tar.gz: 
	echo $@
	echo $<
	echo $*
	echo $(CODENAME_$@)
	#./makepackage.pl eprints2-alpha-1 $(MILESTONE_VERSION) $(MILESTONE_DESC_A)$(CODENAME_$@)$(MILESTONE_DESC_B) licenses/gpl.txt 
