.SUFFIXES: 
.SUFFIXES: .html .xml .pdf .dvi .latex .ps .ok .docbook

WORK_DIR = work
DOCBOOK_ROOT = /usr/local/share/docbook
XHTML = $(DOCBOOK_ROOT)/xhtml/docbook.xsl
LATEX = $(DOCBOOK_ROOT)/latex/docbook.xsl

all: alpha

.xml.html: 
	./wellformed.pl $<
	xt $< $(XHTML) > $@

.xml.latex: 
	./wellformed.pl $<
	xt $< $(LATEX) > $*.latex

.xml.docbook:
	./mkdocbook.pl $< > $*.docbook

.latex.dvi: 
	test -d work || mkdir work
	cp $< $(WORK_DIR)
	cd $(WORK_DIR); latex $<
	cp $(WORK_DIR)/$*.dvi .

.dvi.pdf: 
	echo hi
	dvipdfm $<

.dvi.ps: 
	dvips $< -o $@

clean:
	rm -f *.html *.pdf *.ps *.dvi *.latex

.xml.ok:
	./wellformed.pl $< NODTD
	touch $@

eprints.entities: history.ok reqsoftware.ok listinfo.ok
	touch eprints.entities
	rm -f *.html *.pdf *.ps *.dvi *.latex

alpha: eprints.entities alpha.pdf alpha.ps alpha.html alpha.docbook
