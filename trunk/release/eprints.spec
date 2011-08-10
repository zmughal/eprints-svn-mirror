%{!?_epname: %define _epname eprints}
%{!?_epversion: %define _epversion 0.0.0}
%{!?_eprelease: %define _eprelease 1}
%{!?_epuser: %define _epuser eprints}
%{!?_epgroup: %define _epgroup eprints}
%{!?_epbase_path: %define _epbase_path /usr/share/eprints}
%{!?_eppackage: %define _eppackage eprints-0.0.0}

Name: %{_epname}
Version: %{_epversion}
Release: %{_eprelease}%{?dist}
Summary: Open Access Repository Software
License: GPLv3
Group: Applications/Communications
URL: http://software.eprints.org/
Source0: http://files.eprints.org/cgi/source/%{_eppackage}.tar.gz
BuildArch: noarch
# Patch0: %{source_name}-%{version}.patch
BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot
BuildRequires: perl
Requires: httpd >= 2.0.52
Requires: mod_perl >= 2.0.0
Requires: perl >= 2:5.8.0
Requires: perl(DBI)
Requires: perl(DBD::mysql) perl(MIME::Base64) perl(Net::SMTP)
Requires: perl(Time::HiRes) perl(CGI) perl(Digest::MD5)
Requires: perl(XML::LibXML) >= 1.63 perl(XML::LibXSLT)
Requires: perl(XML::SAX)
Requires: tetex-latex wget gzip tar ImageMagick unzip elinks
Requires: poppler-utils
Requires: chkconfig
# Some modules are dynamically loaded by eprints, which confuses AutoReq
AutoReq: 0
# All eprint's perl modules are private and shouldn't be AutoProvided
AutoProv: 0
#Provides: %{name} = %{version}

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
pushd %{_eppackage}
./configure --prefix=%{_epbase_path} --with-user=%{_epuser} --with-group=%{_epgroup} --with-smtp-server=localhost --disable-user-check --disable-group-check
pushd perl_lib
# We ought to use the system libraries
mv URI/OpenURL.pm OpenURL.pm
rm -rf URI.pm URI Unicode Proc MIME/Lite.pm
mkdir URI
mv OpenURL.pm URI/
popd
popd

%install
rm -rf $RPM_BUILD_ROOT

pushd %{_eppackage}
mkdir -p ${RPM_BUILD_ROOT}%{_epbase_path}
echo 'Installing into:'
echo $RPM_BUILD_ROOT%{_epbase_path}
DESTDIR=$RPM_BUILD_ROOT%{_epbase_path}
export DESTDIR
make install
popd

mkdir -p $RPM_BUILD_ROOT/etc/rc.d/init.d
install -m755 $RPM_BUILD_ROOT%{_epbase_path}/bin/epindexer $RPM_BUILD_ROOT/etc/rc.d/init.d/%{name}

APACHE_CONF=%{_epbase_path}/cfg/apache.conf
mkdir -p $RPM_BUILD_ROOT/etc/httpd/conf.d
cat > $RPM_BUILD_ROOT/etc/httpd/conf.d/%{name}.conf << "EOF"
# This includes the eprints Apache configuration which enables virtual hosts on
# port 80 and creates a virtual host for each configured archive.

EOF
echo "Include $APACHE_CONF" >> $RPM_BUILD_ROOT/etc/httpd/conf.d/%{name}.conf
chmod 644 $RPM_BUILD_ROOT/etc/httpd/conf.d/%{name}.conf

# We have to build a custom list of files to make SystemSettings.pm a config
# file in the same directory as normal packaged files
# We also take the opportunity to make only those directories that need
# be writable by the eprints user
find $RPM_BUILD_ROOT%{_epbase_path} -type f -print |
	sed "s@^$RPM_BUILD_ROOT@@g" |
	grep -v "/etc/httpd/conf.d/%{name}.conf" > %{name}-%{version}-filelist
if [ "$(cat %{name}-%{version}-filelist)X" = "X" ] ; then
	echo "ERROR: EMPTY FILE LIST"
	exit -1
fi

# Strip directories from the file list (otherwise they get left behind on
# erase)
find $RPM_BUILD_ROOT%{_epbase_path} -type d -print |
	sed "s@^$RPM_BUILD_ROOT@@g" |
	sed "s/^/\%dir /" >> %{name}-%{version}-filelist

mkdir $RPM_BUILD_ROOT%{_epbase_path}/cfg/{apache,apache_ssl}
touch $RPM_BUILD_ROOT%{_epbase_path}/cfg/{apache,apache_ssl}.conf

%clean
rm -rf $RPM_BUILD_ROOT

%files -f %{name}-%{version}-filelist
%defattr(-,%{_epuser},%{_epgroup})
%doc %{_eppackage}/AUTHORS %{_eppackage}/CHANGELOG %{_eppackage}/COPYING %{_eppackage}/NEWS %{_eppackage}/README %{_eppackage}/VERSION
%attr(0644,root,root) /etc/httpd/conf.d/%{name}.conf
%attr(0755,root,root) /etc/rc.d/init.d/%{name}
#%config %{_epbase_path}/perl_lib/EPrints/SystemSettings.pm
# archives, needs to persist permissions to sub-directories
#%dir %attr(02775,-,-) %{_epbase_path}/archives
# var needs to be writable by eprints and apache
#%dir %attr(0775,-,-) %{_epbase_path}/var
# cfg needs to be writable by generate_apacheconf
#%dir %attr(0775,-,-) %{_epbase_path}/cfg
#%dir %attr(0775,-,-) %{_epbase_path}/cfg/cfg.d
%ghost %{_epbase_path}/cfg/apache.conf
%ghost %{_epbase_path}/cfg/apache_ssl.conf
%ghost %{_epbase_path}/cfg/apache
%ghost %{_epbase_path}/cfg/apache_ssl
# %ghost %{_epbase_path}/var/indexer.log*

%pre
/usr/sbin/groupadd %{_epgroup} 2>/dev/null || /bin/true
/usr/sbin/useradd -d %{_epbase_path} -g %{_epgroup} -M %{_epuser} -G apache 2>/dev/null || /bin/true
/usr/sbin/usermod -a -G %{_epuser} apache

%post
pushd %{_epbase_path} > /dev/null
/bin/su -c ./bin/generate_apacheconf %{_epuser}
popd > /dev/null
/sbin/chkconfig --add %{name}
(selinuxenabled && chcon -R -u unconfined_u -t httpd_sys_content_t %{_epbase_path}archives/ %{_epbase_path}lib/ %{_epbase_path}var/) || /bin/true

%preun
/sbin/chkconfig --del %{name}

%postun
#if [ "$1" = 0 ]; then
#	/usr/sbin/userdel eprints || :
#	/usr/sbin/groupdel eprints || :
#fi

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
