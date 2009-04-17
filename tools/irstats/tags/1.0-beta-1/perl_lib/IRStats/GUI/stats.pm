package IRStats::GUI::stats;

our @ISA = qw( IRStats::GUI );

use strict;

sub body
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $conf = $session->get_conf;

	print "<h1>IRStats</h1>\n";

	print <<EOH;
<div class='help'>
This page allows you to generate graphs and tables of data summarising the usage data for eprints in the repository. Select the data you want to graph in 'Set of Eprints', choose the date range to process in 'Date Range', select the type of analysis to make in 'Choice of View' and then click 'Generate'.
</div>
EOH

	my $view_dir = $conf->get_value('view_path');
	opendir(DIR, $view_dir);
	my @view_files = grep(/\.pm$/,readdir(DIR));
	closedir(DIR);

	foreach my $i (0 .. $#view_files) {
		$view_files[$i] =~ s/\.pm$//;
	}

	my $cgi = $session->cgi;

	my $controls = IRStats::UserInterface::Controls->new(session => $session);

	print "<form action=\"".$cgi->url."\" method=\"get\">\n";

	print "<input type='hidden' name='page' value='get_view2'/>\n";
	print $controls->eprints_control();
	#print $controls->start_date_control();
	#print $controls->end_date_control();
	print $controls->date_control();
	print $controls->view_control();

	print "<input type=\"submit\" value=\"Generate the Requested View\" />";

	print "</form>";
}

1;
