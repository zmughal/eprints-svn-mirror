package IRStats::GUI::last_year;

use strict;

use IRStats::View::MonthlyDownloadsGraph;

sub generate
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $conf = $session->get_conf;

	my $cgi = $session->cgi;

#  0    1    2     3     4    5     6     7     8
#($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	my @today = localtime(time);

	my $eprints = $cgi->param('set');
	$eprints = 'all' if( !defined $eprints );

	my $hash = {
		eprints=>$eprints,
		start_day=>1,
		start_month=>$today[4]+1,
		start_year=>$today[5]+1900-1,
		end_day=>31,
		end_month=>$today[4]+1-1,
		end_year=>$today[5]+1900,
		view=> 'MonthlyDownloadsGraph',
	};

	my $params = IRStats::Params->new($conf, $hash);
	my $view_name = 'MonthlyDownloadsGraph';

	$view_name = 'IRStats::View::' . $view_name;
	my $view = $view_name->new($params, $session->get_database);
# not actually printing... but need to do this for the URL and to make the image render
	$view->render();
	my $url = $view->get('visualisation')->get('url_relative');

	print "Location: $url\n";
	print "Content-type: text/html\n\n";
#print "\n";
}

1;
