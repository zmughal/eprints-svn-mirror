package IRStats::GUI::dashboard;

use strict;

our @ISA = qw( IRStats::GUI );

sub title
{
	"IRStats Dashboard";
}

sub body
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $conf = $session->get_conf;

	my $cgi = $session->cgi;

	my $database = $self->{database} = $session->get_database;

	my $eprint_set = $cgi->param('eprints') || 'all';

	my $params = $self->{params} = IRStats::Params->new($conf, { eprints => $eprint_set});

	#if we need to override the default parameters of ONE YEAR OF TIME and THE SET PASSED IN.
	my $view_params = $self->{view_params}
	{
		DailyDownloadsGraph => { start_date => ago($params->get('end_date'), 'month')  }
	};

	my $raw_data_links = [
		'stats.cgi?page=get_view&eprints=' . $params->get('eprints') . '&start_date=' . ago($params->get('end_date'),'week')->render('numerical')  . '&view=RawDataTableCSV',
		'stats.cgi?page=get_view&eprints=' . $params->get('eprints') . '&start_date=' . ago($params->get('end_date'),'month')->render('numerical')  . '&view=RawDataTableCSV',
		'stats.cgi?page=get_view&eprints=' . $params->get('eprints') . '&view=RawDataTableCSV',
	];

	my @set_ids = $conf->set_ids;

	my $set = 'all';
	my ($set_member_code, $set_member_id, $short_citation, $full_citation, $url);
	my @set_views = $conf->all_dashboard;

	if( $eprint_set ne 'all' )
	{
		for(@set_ids, 'eprint')
		{
			if( $eprint_set =~ /^$_\_(.*)/ )
			{
				$set = $_;
				$set_member_code = $1;
				$set_member_id = $database->get_id($set_member_code, $set); 
				last;
			}
		}
		my $set_views_dashboard = $set."_dashboard";
		if( not defined $set_member_code )
		{
			die "$eprint_set is not a valid eprint set: must be one of ".join(',',@set_ids,'eprint');
		}
		elsif( not defined $set_member_id or $set_member_id eq 'ERR' )
		{
			die "$set_member_code is not a member of the $set set. This may be because you entered your query data incorrectly or because $set_member_code has not yet been imported into irstats.";
		}
		if( $conf->is_set( $set_views_dashboard ) )
		{
			@set_views = $conf->$set_views_dashboard;
		}
		$short_citation = $database->get_citation($set_member_id, $set, 'short');
		$full_citation = $database->get_citation($set_member_id, $set, 'full');
		$url = $database->get_url($set_member_id, $set);
	}

	my %available = map { $_ => 1 } $session->get_views;
	foreach my $view (@set_views)
	{
		unless( $available{$view} )
		{
			die "$view is not a valid view, check the configuration file setting for ${set}_dashboard";
		}
	}

	if( $set eq 'all' )
	{
		print "<h1>Dashboard for all records</h1>\n";
	}
	else
	{
		print "<h1>Dashboard for $full_citation</h1>\n";

		if( $url and $url !~ m/^OOPS/ )
		{
			print "<p><a href='".CGI::escapeHTML($url)."'>".CGI::escapeHTML($url)."</a></p>\n";
		}
	}

	print "<div id='irstats_dashboard_views'>\n";
	foreach my $view (@set_views)
	{
		my $title = $session->get_phrase( "view:$view:title" ) || $view;
		print "<div class='irstats_view'>\n",
			"<h2>", $title, "</h2>\n",
			"<div class='irstats_view_inner'>", $self->view($view), "</div>\n",
			"</div>";
	}
	print "<div style='clear: left'></div>\n";
	print "</div>";

	if( $available{RawDataTableCSV} )
	{
		print "<h2>Download Raw Data For:</h2>\n<table><tr><td>";
		print '<a href="' . $raw_data_links->[0] . '">One Week</a>';
		print '</td><td>';
		print '<a href="' . $raw_data_links->[1] . '">One Month</a>';
		print '</td><td>';
		print '<a href="' . $raw_data_links->[2] . '">One Year</a>';
		print '</td></table>';
	}
}

sub view
{
	my( $self, $view_name ) = @_;

	my $params = $self->{params};
	my $view_params = $self->{view_params};
	my $database = $self->{database};
	my @views = $self->{session}->get_views;

	my $mask_params = ({view => $view_name});
	foreach my $param_name(keys %{$view_params->{$view_name}})
	{
		$mask_params->{$param_name} = $view_params->{$view_name}->{$param_name};
	}
	$params->mask($mask_params);
	$view_name = 'IRStats::View::' . $view_name;
	my $view = $view_name->new($params, $database);
	my $r = $view->render();
	$params->unmask();
	return $r;
}


sub ago
{
	my ($date, $period) = @_;
	my $new_date = $date->clone();
	$new_date->decrement($period);
	return $new_date;
}

1;
