%define source_name eprints3
%define user eprints
%define user_group eprints
%define install_path /opt/eprints3
%define package __TARBALL__

# Honey/GDOME/LibXML are dynamically loaded, which breaks Requires
AutoReq: 0
# All eprint's perl modules are private, which breaks Provides
AutoProv: 0

Summary: Open Access Repository Software
Name: eprints3
Version: __RPMVERSION__
Release: 1
URL: http://software.eprints.org/
Source0: %{package}.tar.gz
# Patch0: %{source_name}-%{version}.patch
License: GPL
Group: Applications/Communications
BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot
BuildRequires: httpd >= 2.0.52
BuildRequires: mod_perl >= 2.0.0
BuildRequires: perl >= 2:5.8.0
BuildRequires: perl(DBI) perl(Unicode::String)
BuildRequires: perl(DBD::mysql) perl(MIME::Base64) perl(Net::SMTP)
BuildRequires: perl(XML::Parser) perl(Time::HiRes) perl(CGI)
BuildRequires: perl(MIME::Lite) perl(Readonly)
BuildRequires: perl(XML::LibXML) >= 1.63
BuildRequires: xpdf antiword tetex-latex wget gzip tar ImageMagick unzip elinks
Requires: httpd >= 2.0.52
Requires: mod_perl >= 2.0.0
Requires: perl >= 2:5.8.0
Requires: perl(DBI) perl(Unicode::String)
Requires: perl(DBD::mysql) perl(MIME::Base64) perl(Net::SMTP)
Requires: perl(XML::Parser) perl(Time::HiRes) perl(CGI)
Requires: perl(MIME::Lite) perl(Readonly)
Requires: perl(XML::LibXML) >= 1.63
Requires: xpdf antiword tetex-latex wget gzip tar ImageMagick unzip elinks
BuildArch: noarch
Provides: eprints3

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
rm -rf URI.pm URI XML Unicode Proc MIME Readonly
popd
popd

%install
pushd %{package}
mkdir -p ${RPM_BUILD_ROOT}%{install_path}
echo 'Installing into:'
echo $RPM_BUILD_ROOT%{install_path}
DESTDIR=$RPM_BUILD_ROOT%{install_path}
export DESTDIR
make install
popd

# We have to do some trickery to make SystemSettings.pm a config file
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

# Otherwise directories get left behind on erase
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
# %config /etc/httpd/conf.d/eprints3.conf
# %config %attr(-,%{user},%{user_group}) %{install_path}/var/auto-apache*.conf
# %ghost %{install_path}/var/indexer.log*
%config %{install_path}/perl_lib/EPrints/SystemSettings.pm
# archives, needs to persist permissions to sub-directories
%dir %attr(02775,%{user},%{user_group}) %{install_path}/archives
# var needs to be writable by eprints and apache
%dir %attr(0775,%{user},%{user_group}) %{install_path}/var
# cfg needs to be writable by generate_apacheconf
%dir %attr(0755,%{user},%{user_group}) %{install_path}/cfg

%pre
/usr/sbin/groupadd %{user_group} 2>/dev/null || /bin/true
/usr/sbin/useradd -d %{install_path} -g %{user_group} -M %{user} -G apache 2>/dev/null || /bin/true
/usr/sbin/usermod -a -G eprints apache

%post
pushd %{install_path} > /dev/null
/bin/su -c ./bin/generate_apacheconf %{user}
APACHE_CONF=%{install_path}/var/apache.conf
echo "You will need to add the following line to the end of your Apache
configuration:

Include $APACHE_CONF"
popd > /dev/null

%preun

%postun
/usr/sbin/userdel eprints || /bin/true
/usr/sbin/groupdel eprints || /bin/true

%changelog
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
