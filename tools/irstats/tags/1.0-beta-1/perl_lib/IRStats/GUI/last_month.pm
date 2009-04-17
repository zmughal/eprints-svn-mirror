package IRStats::GUI::last_month;

use strict;

use IRStats::View::DailyDownloadsGraph;

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
	my $start_year = $today[5]+1900;
	my $start_month = $today[4]+1;
	$start_month -= 1;
	if( $start_month == 0 ) { $start_month = 12; $start_year-=1; }

	my $hash = {
		eprints=>$eprints,
		start_day=>$today[3],
		start_month=>$start_month,
		start_year=>$start_year,
		end_day=>$today[3],
		end_month=>$today[4]+1,
		end_year=>$today[5]+1900,
		view=> 'DailyDownloadsGraph',
	};

	my $params = IRStats::Params->new($conf, $hash);
	my $view_name = 'DailyDownloadsGraph';

	$view_name = 'IRStats::View::' . $view_name;
	my $view = $view_name->new($params, $session->get_database);
# not actually printing... but need to do this for the URL and to make the image render
	$view->render();
	my $url = $view->get('visualisation')->get('url_relative');

	print "Location: $url\n";
	print "Content-type: text/html\n\n";
}

1;
