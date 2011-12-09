export EP3_INSTALL=`ls /etc/apache2/sites-available/ | grep eprints3`;
if [ "$EP3_INSTALL" == "" ]
then
	`echo "Include /usr/share/eprints3/cfg/apache.conf" > /etc/apache2/sites-available/eprints3`;
	`a2ensite eprints3`;
	`/etc/init.d/apache2 force-reload`;
fi
export EP3_INSTALL=`ls /etc/init.d/ | grep epindexer`;
if [ "$EP3_INSTALL" == "" ]
then
	`ln -s /usr/share/eprints3/bin/epindexer /etc/init.d/epindexer`;
	`update-rc.d epindexer defaults 99 99`;
fi
