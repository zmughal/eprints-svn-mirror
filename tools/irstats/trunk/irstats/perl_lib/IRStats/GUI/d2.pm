Carp::confess "Deprecated - was development version of dashboard?";

__END__

#!/usr/bin/perl -I/opt/irstats/irstats1/perl_lib -I/opt/irstats/irstats1/perl_lib/ChartDirector 

use CGI qw(:standard);
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use Data::Dumper;
use strict;
use warnings;

use IRStats::Params;
use IRStats::DatabaseInterface;
use IRStats::Configuration;


print "Content-type: text/html; charset=utf-8\n\n";

my $conf = IRStats::Configuration->new();

my $view_dir = $conf->get_value("view_path");
opendir(DIR, $view_dir);
my @view_files = grep(/\.pm$/,readdir(DIR));
closedir(DIR);

foreach my $i (0 .. $#view_files) {
	my $view_file = $view_dir . $view_files[$i];
	require $view_file;
	$view_files[$i] =~ s/\.pm$//;
}

my $cgi = new CGI;

my $params = IRStats::Params->new($conf, { eprints => $cgi->param('eprints')});



my $views = {
1 => 'AllMonthlyDownloadsGraph',
2 => 'DailyDownloadsGraph',
3 => 'DownloadCountHTML',
4 => 'HighestClimbersTable',
5 => 'MonthlyDownloadsByGroupGraph',
6 => 'MonthlyDownloadsGraph',
7 => 'MonthlyUniqueVisitorsGraph',
8 => 'RandomFromTopTenHTML',
9 => 'RawDataTableCSV',
10 => 'RawDataTableHTML',
11 => 'ReferrerGraph',
12 => 'SearchEngineGraph',
13 => 'TopCountriesTable',
14 => 'TopItemHTML',
15 => 'TopTenAcademies',
16 => 'TopTenAuthorsTable',
17 => 'TopTenNonSearchReferrers',
18 => 'TopTenSearchTermsTable',
19 => 'TopTenTable'
};

#if we need to override the default parameters of ONE YEAR OF TIME and THE SET PASSED IN.
my $view_params =
{
	$views->{2} => { start_date => month_ago($params->get('end_date'))  }
};


my $set_views = 
{
	eprint => [
		{ view => $views->{1}, label => "Monthly Downloads" },
		{ view => $views->{2}, label => "Daily Downloads" },
		{ view => $views->{11}, label => "Referrer Types" },
		{ view => $views->{15}, label => "Top University Visitors" },
		{ view => $views->{17}, label => "Top Referrers (Non-Search)" },
		{ view => $views->{18}, label => "Top Search Terms" }
	],
	group => [ 
		{ view => $views->{1}, label => "Monthly Downloads" },
		{ view => $views->{2}, label => "Daily Downloads" },
		{ view => $views->{11}, label => "Referrer Types" },
		{ view => $views->{15}, label => "Top University Visitors" },
		{ view => $views->{17}, label => "Top Referrers (Non-Search)" },
		{ view => $views->{18}, label => "Top Search Terms" }

	],
	author => [
		{ view => $views->{1}, label => "Monthly Downloads" },
		{ view => $views->{2}, label => "Daily Downloads" },
		{ view => $views->{11}, label => "Referrer Types" },
		{ view => $views->{15}, label => "Top University Visitors" },
		{ view => $views->{17}, label => "Top Referrers (Non-Search)" },
		{ view => $views->{18}, label => "Top Search Terms" }
	]
};
my $eprint_set = $params->get('eprints');
my ($set, $set_member_code) = split(/_/,$eprint_set);

my $database = IRStats::DatabaseInterface->new($conf);
my $set_member_id = $database->get_id($set_member_code, $set); 
my $short_citation = $database->get_citation($set_member_id, $set, 'short');
my $full_citation = $database->get_citation($set_member_id, $set, 'full');

my $url = $database->get_url($set_member_id, $set);


print'
<html>
<head>
<title>IRStats Dashboard</title>
</head>
<body style="font-family: Verdana, Arial, sans-serif">
';

my $set_label = "ERR";
if ($set eq 'eprint')
{
	$set_label = 'Eprint';
}
elsif ($set eq 'author')
{
	$set_label = 'Author';
}
elsif ($set eq 'group')
{
	$set_label = 'Research Group';
}

print "
<h1>
Dashboard For $set_label:
<a href='$url'>$url</a>
</h1>
";

print"
<p>$full_citation</p>
";





print '
<table>',
'<tr>' ,
'<td><h2 style="margin-top:1em; margin-bottom: 0em">' , $set_views->{$set}->[0]->{label} , '</h2></td>' ,
'<td><h2 style="margin-top:1em; margin-bottom: 0em">' , $set_views->{$set}->[1]->{label} , '</h2></td>' ,
'</tr>',
'<tr>' ,
'<td>' , view($set_views->{$set}->[0]->{view}) , '</td>' ,
'<td>' , view($set_views->{$set}->[1]->{view}) , '</td>' ,
'</tr>',
'<tr>' ,
'<td><h2 style="margin-top:1em; margin-bottom: 0em">' , $set_views->{$set}->[2]->{label} , '</h2></td>' ,
'<td><h2 style="margin-top:1em; margin-bottom: 0em">' , $set_views->{$set}->[3]->{label} , '</h2></td>' ,
'</tr>',
'<tr>' ,
'<td>' , view($set_views->{$set}->[2]->{view}) , '</td>' ,
'<td>' , view($set_views->{$set}->[3]->{view}) , '</td>' ,
'</tr>',
'<tr>' ,
'<td><h2 style="margin-top:1em; margin-bottom: 0em">' , $set_views->{$set}->[4]->{label} , '</h2></td>' ,
'<td><h2 style="margin-top:1em; margin-bottom: 0em">' , $set_views->{$set}->[5]->{label} , '</h2></td>' ,
'</tr>',
'<tr>' ,
'<td>' , view($set_views->{$set}->[4]->{view}) , '</td>' ,
'<td>' , view($set_views->{$set}->[5]->{view}) , '</td>' ,
'</tr>',
'</table>';

sub view
{
	my ($view_name) = @_;
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


sub month_ago
{
	my ($date) = @_;
	my $new_date = $date->clone();
	$new_date->decrement('month');
	return $new_date;
}
