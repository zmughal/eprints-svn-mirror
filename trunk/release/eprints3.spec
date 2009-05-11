%define source_name eprints3
%define user eprints
%define user_group eprints
# This is the standard path used by the upstream
%define install_path /opt/eprints3
%define package __TARBALL__

Name: eprints3
Version: __RPMVERSION__
Release: 1%{?dist}
Summary: Open Access Repository Software
License: GPL
Group: Applications/Communications
URL: http://software.eprints.org/
Source0: %{package}.tar.gz
BuildArch: noarch
# Patch0: %{source_name}-%{version}.patch
BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot
BuildRequires: httpd >= 2.0.52
BuildRequires: mod_perl >= 2.0.0
BuildRequires: perl >= 2:5.8.0
BuildRequires: perl(DBI) perl(Unicode::String)
BuildRequires: perl(DBD::mysql) perl(MIME::Base64) perl(Net::SMTP)
BuildRequires: perl(XML::Parser) perl(Time::HiRes) perl(CGI)
BuildRequires: perl(MIME::Lite) perl(Readonly)
BuildRequires: perl(XML::LibXML) >= 1.63
BuildRequires: antiword tetex-latex wget gzip tar ImageMagick unzip elinks
BuildRequires: /usr/bin/pdftotext
Requires: httpd >= 2.0.52
Requires: mod_perl >= 2.0.0
Requires: perl >= 2:5.8.0
Requires: perl(DBI) perl(Unicode::String)
Requires: perl(DBD::mysql) perl(MIME::Base64) perl(Net::SMTP)
Requires: perl(XML::Parser) perl(Time::HiRes) perl(CGI)
Requires: perl(MIME::Lite) perl(Readonly)
Requires: perl(XML::LibXML) >= 1.63
Requires: antiword tetex-latex wget gzip tar ImageMagick unzip elinks
Requires: /usr/bin/pdftotext
Requires: chkconfig
Provides: eprints3
# Some modules are dynamically loaded by eprints, which confuses AutoReq
AutoReq: 0
# All eprint's perl modules are private and shouldn't be AutoProvided
AutoProv: 0

%description
EPrints is a web-based content management system for information archiving. It
allows a large number of contributors to share their digital objects/documents
with others. Contributors provide descriptive data (metadata) which is
dependent on the type of object being deposited (presentations, articles, books
etc.).

Before being published objects must be accepted by an editor. Users can access
published objects through web-page listings, searches, email alerts or via
integration with other systems.

%prep
%setup -q -c -n %{name}
# %patch 

%build
pushd %{package}
./configure --prefix=%{install_path} --with-user=%{user} --with-group=%{user_group} --with-apache=2 --with-smtp-server=localhost --disable-user-check --disable-group-check
pushd perl_lib
# We ought to use the system libraries
rm -rf URI.pm URI Unicode Proc MIME Readonly
popd
popd

%install
rm -rf $RPM_BUILD_ROOT

pushd %{package}
mkdir -p ${RPM_BUILD_ROOT}%{install_path}
echo 'Installing into:'
echo $RPM_BUILD_ROOT%{install_path}
DESTDIR=$RPM_BUILD_ROOT%{install_path}
export DESTDIR
make install
popd

mkdir -p $RPM_BUILD_ROOT/etc/rc.d/init.d
install -m755 $RPM_BUILD_ROOT%{install_path}/bin/epindexer $RPM_BUILD_ROOT/etc/rc.d/init.d/epindexer

APACHE_CONF=%{install_path}/cfg/apache.conf
mkdir -p $RPM_BUILD_ROOT/etc/httpd/conf.d
cat > $RPM_BUILD_ROOT/etc/httpd/conf.d/eprints3.conf << "EOF"
# This includes the eprints Apache configuration which enables virtual hosts on
# port 80 and creates a virtual host for each configured archive.

EOF
echo "Include $APACHE_CONF" >> $RPM_BUILD_ROOT/etc/httpd/conf.d/eprints3.conf
chmod 644 $RPM_BUILD_ROOT/etc/httpd/conf.d/eprints3.conf

# We have to build a custom list of files to make SystemSettings.pm a config
# file in the same directory as normal packaged files
# We also take the opportunity to make only those directories that need
# be writable by the eprints user
find $RPM_BUILD_ROOT%{install_path} -type f -print |
	sed "s@^$RPM_BUILD_ROOT@@g" |
	grep -v "SystemSettings.pm$" |
	grep -v "/etc/httpd/conf.d/eprints3.conf" |
	grep -v "^%{install_path}/var" |
	grep -v "^%{install_path}/cfg" |
	grep -v "^%{install_path}/archives" > %{name}-%{version}-filelist
if [ "$(cat %{name}-%{version}-filelist)X" = "X" ] ; then
	echo "ERROR: EMPTY FILE LIST"
	exit -1
fi

# Strip directories from the file list (otherwise they get left behind on
# erase)
find $RPM_BUILD_ROOT%{install_path} -type d -print |
	sed "s@^$RPM_BUILD_ROOT@@g" |
	grep -v "^%{install_path}/var" |
	grep -v "^%{install_path}/cfg" |
	grep -v "^%{install_path}/archives" |
	sed "s/^/\%dir /" >> %{name}-%{version}-filelist

%clean
rm -rf $RPM_BUILD_ROOT

%files -f %{name}-%{version}-filelist
%defattr(-,root,root)
%doc %{package}/AUTHORS %{package}/CHANGELOG %{package}/COPYING %{package}/NEWS %{package}/README %{package}/VERSION
%attr(0644,root,root) /etc/httpd/conf.d/eprints3.conf
%attr(0755,root,root) /etc/rc.d/init.d/epindexer
%config %{install_path}/perl_lib/EPrints/SystemSettings.pm
# archives, needs to persist permissions to sub-directories
%dir %attr(02775,%{user},%{user_group}) %{install_path}/archives
# var needs to be writable by eprints and apache
%dir %attr(0775,%{user},%{user_group}) %{install_path}/var
# cfg needs to be writable by generate_apacheconf
%dir %attr(0755,%{user},%{user_group}) %{install_path}/cfg
# %config %attr(-,%{user},%{user_group}) %{install_path}/var/auto-apache*.conf
# %ghost %{install_path}/var/indexer.log*

%pre
/usr/sbin/groupadd %{user_group} 2>/dev/null || /bin/true
/usr/sbin/useradd -d %{install_path} -g %{user_group} -M %{user} -G apache 2>/dev/null || /bin/true
/usr/sbin/usermod -a -G eprints apache

%post
pushd %{install_path} > /dev/null
/bin/su -c ./bin/generate_apacheconf %{user}
popd > /dev/null
/sbin/chkconfig --add epindexer

%preun
/sbin/chkconfig --del epindexer

%postun
if [ "$1" eq "0" ]; then
	/usr/sbin/userdel eprints || :
	/usr/sbin/groupdel eprints || :
fi

%changelog
* Mon May 11 2009 Tim Brody <tdb01r@ecs.soton.ac.uk>
 - Changes submitted by Alexander Bergolth <leo AT strike.wu-wien.ac.at>
 - Changed xpdf dependency to /usr/bin/pdftotext
 - Only remove eprints user on uninstall

* Wed Sep 12 2007 Tim Brody <tdb01r@ecs.soton.ac.uk>
 - Fedora Linux style
 - Added Apache conf.d file
 - Added epindexer init.d file

* Tue Sep 11 2007 Tim Brody <tdb01r@ecs.soton.ac.uk>
 - ShowTable is just an old dependency in DBD::mysql?
 - Removed rpmpatch.sh
 - Changed description to same as Debian package
 - Do generate_apacheconf on post-install
 - Don't make eprints a nologin user
 - Don't automatically find dependencies/provides

* Fri May 18 2007 Tim Brody <tdb01r@ecs.soton.ac.uk>
 - Changed most files to be owned by root
 - Made SystemSettings a config file

* Sun Feb 18 2007 Tim Brody <tdb01r@ecs.soton.ac.uk>
 - Added all shell dependencies
 - Removed sendmail dependency (not sure about this one)
 - Remove eprints user on uninstall
 - Add apache to eprints group on install

* Fri Feb 16 2007 Tim Brody <tdb01r@ecs.soton.ac.uk>
 - Added pdftotext and antiword dependencies
 - Set /sbin/nologin for eprints user
 - Remove a bunch more bundled modules in favour of RPM versions

* Tue Aug 15 2006 Tim Brody <tdb01r@ecs.soton.ac.uk>
 - Initial release
