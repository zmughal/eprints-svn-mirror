package IRStats::GUI::get_view2;

use strict;

sub generate
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $conf = $session->get_conf;

	my $cgi = $session->cgi;

	my $date_choice = $cgi->param('IRS_datechoice');
	my $start_date;
	my $end_date;
	if ($date_choice eq 'period')
	{
		my $period = $cgi->param('period');
		if ($period =~ /^-([0-9]+)m$/)
		{
			my $months = $1;
			my $end_date_obj = IRStats::Date->new(); #defaults to yesterday;
			my $start_date_obj = $end_date_obj->clone();
			foreach (1 .. $months)
			{
				$start_date_obj->decrement('month');
			}
			$start_date_obj->increment('day');
			$start_date = $start_date_obj->render('numerical');
			$end_date = $end_date_obj->render('numerical');
		}
		elsif ($period =~ /^Q([0-9])([0-9]{4,4})/)
		{
			my ($quarter, $year) = ($1, $2);
			$start_date = $year . ((($quarter-1) * 3) + 1) . '01';
			$end_date = $year . ($quarter * 3) . '31';
		}
		else
		{
			Carp::confess "Invalid Period Data\n";
		}
	}
	elsif ($date_choice eq 'range')
	{
		$start_date = sprintf("%04d%02d%02d",$cgi->param('start_year'),$cgi->param('start_month'),$cgi->param('start_day'));
		$end_date = sprintf("%04d%02d%02d",$cgi->param('end_year'),$cgi->param('end_month'),$cgi->param('end_day'));
	}
	else
	{
		Carp::confess "Invalid Choice of Date: $date_choice\n";
	}

	my $sets = $conf->get_value( "set_ids" );

	my $eprint_choice = $cgi->param('IRS_epchoice');
	my $eprints;
	if ($eprint_choice eq 'All')
	{
		$eprints = 'all';
	}
	elsif ($eprint_choice eq 'EPrint')
	{
		$eprints = 'eprint_' . $cgi->param('eprint');
	}
	elsif (grep { $_ eq $eprint_choice } @$sets)
	{
		$eprints = $cgi->param($eprint_choice."s");
	}
	else
	{
		Carp::confess "Invalid Choice of EPrint: $eprint_choice\n";
	}

	if(!$eprints)
	{
		Carp::confess "No choice made for [$eprint_choice]\n";
	}

	my $param_hash = { view => $cgi->param('view'), start_date => $start_date, end_date => $end_date, eprints => $eprints };


	my $params = IRStats::Params->new($conf, $param_hash);

	my $view_name = $params->get('view');

	if ($view_name !~ /CSV$/){
		print $cgi->header("text/html; charset=UTF-8");
	}
	else
	{
		print "Content-type: text/csv\n";
		print "Content-Disposition: attachment; filename=\"stats.csv\"\n";
		print "Content-Description: EPrints Stats CSV Dump\n\n";
	}

	my $flag = scalar grep { $_ eq $view_name } $session->get_views;

	if ($flag)
	{
		my $view_name = 'IRStats::View::' . $view_name;
		my $view = $view_name->new($params, $session->get_database);
		print $view->render();
	}
	else
	{
		Carp::confess "Unrecognised view $view_name: available views are ".join(',',$session->get_views);
	}
}

1;
