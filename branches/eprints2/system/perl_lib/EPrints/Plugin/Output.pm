package EPrints::Plugin::Output;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::Output::ABSTRACT = 1;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();
	$d{name} = "Base output plugin: This should have been subclassed";
	$d{suffix} = ".txt";
	$d{visible} = "all";
	$d{mimetype} = "text/plain";
	return %d;
}

sub render_name
{
	my( $plugin ) = @_;

	return $plugin->{session}->make_text( $plugin->{name} );
}

# all or ""
sub is_visible
{
	my( $plugin, $vis_level ) = @_;
	return( 1 ) unless( defined $vis_level );

	return( 0 ) unless( defined $plugin->{visible} );

	if( $vis_level eq "all" && $plugin->{visible} ne "all" ) {
		return 0;
	}

	return 1;
}

sub can_accept
{
	my( $plugin, $format ) = @_;

	foreach my $a_format ( @{$plugin->{accept}} ) {
		if( $a_format =~ m/^(.*)\*$/ ) {
			my $base = $1;
			return( 1 ) if( substr( $format, 0, length $base ) eq $base );
		}
		else {
			return( 1 ) if( $format eq $a_format );
		}
	}

	return 0;
}


sub output_list
{
	my( $plugin, %opts ) = @_;
	
	my @r = '';

	my $part;

	foreach my $dataobj ( $opts{list}->get_records ) {
		$part = $plugin->output_dataobj( $dataobj );
		if( defined $opts{fh} ) { print {$opts{fh}} $part; } else { push @r, $part; }
	}	

	if( !defined $opts{fh} ) { return join( '', @r ); }
}

# if this an output plugin can output results for a single dataobj then
# this routine returns a URL which will export it. This routine does not
# check that it's actually possible.
sub dataobj_export_url
{
	my( $plugin, $dataobj ) = @_;

	my $dataset = $dataobj->get_dataset;
	if( $dataset->confid ne "eprint" ) {
		# only know URLs for eprint objects
		return undef;
	}

	my $pluginid = $plugin->{id};

	unless( $pluginid =~ m#^output/(.*)$# )
	{
		$plugin->{session}->get_archive->log( "Bad pluginid in dataobj_export_url: ".$pluginid );
		return undef;
	}
	my $format = $1;

	my $url = $plugin->{session}->get_archive->get_conf( "perl_url" );
	$url .= "/export/".$dataobj->get_id."/".$format;
	$url .= "/".$plugin->{session}->get_archive->get_id;
	$url .= "-".$dataobj->get_dataset->confid."-".$dataobj->get_id.$plugin->{suffix};

	return $url;
}

	

1;
