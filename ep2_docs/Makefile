.SUFFIXES: 
.SUFFIXES: .html .xml .pdf .dvi .latex .ps

WORK_DIR = work

DOCBOOK_ROOT = /usr/local/share/docbook
XHTML = $(DOCBOOK_ROOT)/xhtml/docbook.xsl
LATEX = $(DOCBOOK_ROOT)/latex/docbook.xsl

all: alpha

.xml.html:
	xt $< $(XHTML) > $@

.xml.latex:
	xt $< $(LATEX) > $*.latex

.latex.dvi:
	cp $< $(WORK_DIR)
	cd $(WORK_DIR); latex $<; latex $<
	cp $(WORK_DIR)/$*.dvi .

.dvi.pdf:
	echo hi
	dvipdfm $<

.dvi.ps:
	dvips $< -o $@

clean:
	rm -f *.html *.pdf *.ps *.dvi *.latex

alpha: alpha.pdf alpha.html alpha.ps
