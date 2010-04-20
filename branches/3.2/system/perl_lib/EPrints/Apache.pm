package EPrints::Apache;

=item $conf = EPrints::Apache::apache_conf( $repo )

Generate and return the <VirtualHost> declaration for this repository.

=cut

sub apache_conf
{
	my( $repo ) = @_;

	my $id = $repo->get_id;
	my $adminemail = $repo->config( "adminemail" );
	my $host = $repo->config( "host" );
	my $port = $repo->config( "port" );
	$port = 80 if !defined $port;
	my $http_root = $repo->config( "http_root" );
	my $virtualhost = $repo->config( "virtualhost" );
	$virtualhost = "*" if !EPrints::Utils::is_set( $virtualhost );

	my $conf = <<EOC;
#
# apache.conf include file for $id
#
# Any changes made here will be lost if you run generate_apacheconf
# with the --replace option
#

# The main virtual host for this repository
<VirtualHost $virtualhost:$port>
  ServerName $host
  ServerAdmin $adminemail

EOC

	# backwards compatibility
	my $apachevhost = $repo->config( "config_path" )."/apachevhost.conf";
	if( -e $apachevhost )
	{
		$conf .= "  # Include any legacy directives\n";
		$conf .= "  Include $apachevhost\n\n";
	}

	$conf .= <<EOC;
  <Location "$http_root">
    PerlSetVar EPrints_ArchiveID $id

    Options +ExecCGI
    Order allow,deny 
    Allow from all
  </Location>

  # Note that PerlTransHandler can't go inside
  # a "Location" block as it occurs before the
  # Location is known.
  PerlTransHandler +EPrints::Apache::Rewrite
  
</VirtualHost>

EOC

	return $conf;
}

sub apache_secure_conf
{
	my( $repo ) = @_;

	my $id = $repo->get_id;
	my $https_root = $repo->config( "https_root" );

	return <<EOC
#
# secure.conf include file for $id
#
# Any changes made here will be lost if you run generate_apacheconf
# with the --replace option
#

  <Location "$https_root">
    PerlSetVar EPrints_ArchiveID $id
    PerlSetVar EPrints_Secure yes

    Options +ExecCGI
    Order allow,deny 
    Allow from all
  </Location>
EOC
}

1;
