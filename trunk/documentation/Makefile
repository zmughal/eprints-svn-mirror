eprints-install.pdf: installation/latex/eprints-install.tex installation/latex/eprints-install-body.tex
	cd installation/latex ; pdflatex eprints-install ; pdflatex eprints-install
	mv installation/latex/eprints-install.pdf .

eprints-install.html: installation/latex/eprints-install.tex installation/latex/eprints-install-body.tex
	cd installation/latex ; latex eprints-install ; latex eprints-install ; latex2html -split 0 -no_navigation -info 0 -white -no_reuse -show_section_numbers eprints-install
	mv installation/latex/eprints-install/eprints-install.html .
	mv installation/latex/eprints-install/eprints-install.css .
	rm -rf installation/latex/eprints-install

clean:
	rm -rf eprints-install.pdf eprints-install.html *.log installation/latex/*.aux installation/latex/*.dvi installation/latex/*.log installation/latex/*.ps
	
