%define source_name eprints3
%define user eprints
%define user_group eprints
%define install_path /opt/eprints3

Summary: Open Access Repository Software
Name: eprints3
Version: 3.0.0
Release: 2
URL: http://software.eprints.org/
Source0: %{source_name}-%{version}.tar.gz
# Patch0: %{source_name}-%{version}.patch
License: GPL
Group: Applications/Communications
BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot
BuildRequires: httpd >= 2.0.52
BuildRequires: perl >= 2:5.8.0
BuildRequires: perl(DBI) perl(Data::ShowTable) perl(Unicode::String)
BuildRequires: perl(DBD::mysql) perl(MIME::Base64) perl(Net::SMTP)
BuildRequires: perl(XML::Parser) perl(Time::HiRes) perl(CGI)
BuildRequires: perl(MIME::Lite) perl(Readonly)
BuildRequires: perl(XML::LibXML) >= 1.63
Requires: httpd >= 2.0.52
Requires: perl >= 2:5.8.0
Requires: perl(DBI) perl(Data::ShowTable) perl(Unicode::String)
Requires: perl(DBD::mysql) perl(MIME::Base64) perl(Net::SMTP)
Requires: perl(XML::Parser) perl(Time::HiRes) perl(CGI)
Requires: perl(MIME::Lite) perl(Readonly)
Requires: perl(XML::LibXML) >= 1.63
Requires: sendmail xpdf antiword
BuildArch: noarch
provides: perl(EPrints::BackCompatibility)

%description
GNU EPrints primary goal is to be set up as an open archive for research papers, and the default configuration reflects this, but it could be easily used for other things such as images, research data, audio archives - anything that can be stored digitally, but you'll have make more changes to the configuration.

%prep
%setup -q -c -n %{name}
# %patch 

%build
pushd %{source_name}-%{version}
/usr/sbin/groupadd %{user_group} || /bin/true
/usr/sbin/useradd -d %{install_path} -g %{user_group} -M %{user} -G apache || /bin/true
./configure --prefix=${RPM_BUILD_ROOT}%{install_path} --with-user=%{user} --with-group=%{user_group} --with-apache=2 --with-smtp-server=localhost
pushd perl_lib
rm -rf URI.pm URI XML Unicode Proc MIME Readonly
popd
popd

%install
pushd %{source_name}-%{version}
mkdir -p ${RPM_BUILD_ROOT}%{install_path}
echo 'Installing into:'
echo $RPM_BUILD_ROOT%{install_path}
make install
./rpmpatch.sh $RPM_BUILD_ROOT
popd

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,%{user},%{user_group})
/opt/eprints3
%config /etc/httpd/conf.d/eprints3.conf
# %config /opt/eprints3/perl_lib/EPrints/SystemSettings.pm

%pre
/usr/sbin/groupadd %{user_group} 2>/dev/null || /bin/true
/usr/sbin/useradd -d %{install_path} -g %{user_group} -M %{user} -G apache -s /sbin/nologin 2>/dev/null || /bin/true

%post

%preun

%postun

%changelog
* Fri Feb 16 2007 Tim Brody <tdb01r@ecs.soton.ac.uk>
 - Added pdftotext and antiword dependencies
 - Set /sbin/nologin for eprints user
 - Remove a bunch more bundled modules in favour of RPM versions

* Tue Aug 15 2006 Tim Brody <tdb01r@ecs.soton.ac.uk>
 - Initial release
