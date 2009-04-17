package IRStats::GUI::get_view;

our @ISA = qw( IRStats::GUI );

use strict;

sub generate
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $conf = $session->get_conf;

	my $cgi = $session->cgi;

	my $params = IRStats::Params->new($conf, $cgi);

	my $view_name = $params->get('view');

	if ($view_name !~ /CSV$/){
		$self->header;
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
