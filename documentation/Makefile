ONLINEHELPFILES = online-help/latex/online-help.tex online-help/latex/access.tex online-help/latex/deposit.tex online-help/latex/register.tex online-help/latex/subscribe.tex online-help/latex/userarea.tex
all: eprints-install.pdf eprints-install.html eprints-install-headless.html online-help.pdf online-help-final

eprints-install.pdf: installation/latex/eprints-install.tex installation/latex/eprints-install-body.tex
	cd installation/latex ; pdflatex eprints-install ; pdflatex eprints-install
	mv installation/latex/eprints-install.pdf .

eprints-install.html: installation/latex/eprints-install.tex installation/latex/eprints-install-body.tex
	cd installation/latex ; latex eprints-install ; latex eprints-install ; latex2html -split 0 -no_navigation -info 0 -white -no_reuse -show_section_numbers eprints-install
	mv installation/latex/eprints-install/eprints-install.html .
	mv installation/latex/eprints-install/eprints-install.css .
	rm -rf installation/latex/eprints-install

eprints-install-headless.html: eprints-install.html
	remove_html_head.pl <eprints-install.html >eprints-install-headless.html

online-help.pdf:  $(ONLINEHELPFILES)
	cd online-help/latex ; pdflatex online-help ; pdflatex online-help
	mv online-help/latex/online-help.pdf .

online-help-final: $(ONLINEHELPFILES)
	rm -rf online-help-final online-help-html
	cd online-help/latex ; latex online-help ; latex online-help ; latex2html -split 4 -no_navigation -info 0 -white -no_reuse online-help
	mv online-help/latex/online-help online-help-html
	sleep 30s # For NFS to catch up...
	./generate_help_html.pl
	rm -rf online-help-html

install-online-help: online-help.pdf online-help-final
	cp online-help.pdf ../system/static/help/
	cp online-help-final/*.jpg ../system/static/help
	cp online-help-final/*.html ../system/static/help
	

clean:
	rm -rf eprints-install.pdf eprints-install.html eprints-install.css eprints-install-headless.html *.log installation/latex/*.aux installation/latex/*.dvi installation/latex/*.log installation/latex/*.ps
	rm -rf online-help.pdf *.log online-help/latex/*.aux online-help/latex/*.dvi online-help/latex/*.log online-help/latex/*.ps online-help-final online-help-html
