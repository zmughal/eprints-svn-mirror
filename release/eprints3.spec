%define source_name eprints3
%define user eprints
%define user_group eprints
%define install_path /opt/eprints3
%define package __TARBALL__

Summary: Open Access Repository Software
Name: eprints3
Version: __RPMVERSION__
Release: 3
URL: http://software.eprints.org/
Source0: %{package}.tar.gz
# Patch0: %{source_name}-%{version}.patch
License: GPL
Group: Applications/Communications
BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot
BuildRequires: httpd >= 2.0.52
BuildRequires: mod_perl >= 2.0.0
BuildRequires: perl >= 2:5.8.0
BuildRequires: perl(DBI) perl(Data::ShowTable) perl(Unicode::String)
BuildRequires: perl(DBD::mysql) perl(MIME::Base64) perl(Net::SMTP)
BuildRequires: perl(XML::Parser) perl(Time::HiRes) perl(CGI)
BuildRequires: perl(MIME::Lite) perl(Readonly)
BuildRequires: perl(XML::LibXML) >= 1.63
BuildRequires: xpdf antiword tetex-latex wget gzip tar ImageMagick unzip elinks
Requires: httpd >= 2.0.52
Requires: mod_perl >= 2.0.0
Requires: perl >= 2:5.8.0
Requires: perl(DBI) perl(Data::ShowTable) perl(Unicode::String)
Requires: perl(DBD::mysql) perl(MIME::Base64) perl(Net::SMTP)
Requires: perl(XML::Parser) perl(Time::HiRes) perl(CGI)
Requires: perl(MIME::Lite) perl(Readonly)
Requires: perl(XML::LibXML) >= 1.63
Requires: xpdf antiword tetex-latex wget gzip tar ImageMagick unzip elinks
BuildArch: noarch
provides: perl(EPrints::BackCompatibility)

%description
Eprints is an open source software package for building open access repositories that are compliant with the Open Archives Initiative Protocol for Metadata Harvesting. It shares many of the features commonly seen in Document Management systems, but is primarily used for institutional repositories and scientific journals.

%prep
%setup -q -c -n %{name}
# %patch 

%build
pushd %{package}
/usr/sbin/groupadd %{user_group} || /bin/true
/usr/sbin/useradd -d %{install_path} -g %{user_group} -M %{user} -G apache || /bin/true
./configure --prefix=%{install_path} --with-user=%{user} --with-group=%{user_group} --with-apache=2 --with-smtp-server=localhost
pushd perl_lib
rm -rf URI.pm URI XML Unicode Proc MIME Readonly
popd
popd

%install
pushd %{package}
mkdir -p ${RPM_BUILD_ROOT}%{install_path}
echo 'Installing into:'
echo $RPM_BUILD_ROOT%{install_path}
# Maybe this will work one day, but at the moment eprints modifies files
# on install, rather than at make
make DESTDIR=$RPM_BUILD_ROOT%{install_path} install
./rpmpatch.sh $RPM_BUILD_ROOT
popd

# We have to do some trickery to make SystemSettings.pm a config file
find $RPM_BUILD_ROOT%{install_path} -type f -print |
	sed "s@^$RPM_BUILD_ROOT@@g" |
	grep -v "SystemSettings.pm$" |
	grep -v "/etc/httpd/conf.d/eprints3.conf" |
	grep -v "^%{install_path}/var" |
	grep -v "^%{install_path}/archives" > %{name}-%{version}-filelist
if [ "$(cat %{name}-%{version}-filelist)X" = "X" ] ; then
	echo "ERROR: EMPTY FILE LIST"
	exit -1
fi

# Otherwise directories get left behind on erase
find $RPM_BUILD_ROOT%{install_path} -type d -print |
	sed "s/^/\%dir /" >> %{name}-%{version}-dirlist

%clean
rm -rf $RPM_BUILD_ROOT

%files -f %{name}-%{version}-filelist
%defattr(-,root,root)
%config /etc/httpd/conf.d/eprints3.conf
%config %{install_path}/var/auto-apache.conf
%config %{install_path}/var/auto-apache-includes.conf
%config %{install_path}/perl_lib/EPrints/SystemSettings.pm
# archives has to be writable by the epadmin tool as the eprints user
# (NB executed code will reside in archives/*/cfg/cfg.d/)
%attr(02775,%{user},%{user_group}) %{install_path}/archives
%ghost %{install_path}/var/indexer.log*

%pre
/usr/sbin/groupadd %{user_group} 2>/dev/null || /bin/true
/usr/sbin/useradd -d %{install_path} -g %{user_group} -M %{user} -G apache -s /sbin/nologin 2>/dev/null || /bin/true
/usr/sbin/usermod -a -G eprints apache

%post

%preun

%postun
/usr/sbin/userdel eprints || /bin/true
/usr/sbin/groupdel eprints || /bin/true

%changelog
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
