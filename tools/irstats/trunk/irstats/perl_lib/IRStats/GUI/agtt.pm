package IRStats::GUI::agtt;

use strict;

our @ISA = qw( IRStats::GUI );

use IRStats::View::TopTenTable;

sub body
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $conf = $session->get_conf;
	my $cgi = $session->cgi;
	my $database = $session->get_database;

	my $start_date = $cgi->param('start_date');
	my $end_date = $cgi->param('end_date');
	my $set_id = $cgi->param('set');

	die "Requires set argument to render top tens for" unless $set_id;

	my $table = $conf->database_set_table_prefix . $set_id;

	unless( $database->has_table( $table ) )
	{
		die "Unknown set '$set_id'";
	}

	my $param_hash = {view => 'TopTenTable'};
	$param_hash->{end_date} = $end_date if ($end_date =~ /[0-9]{8}/);
	$param_hash->{start_date} = $start_date if ($start_date =~ /[0-9]{8}/);

	my $params = IRStats::Params->new($conf, $param_hash);

	my $group_ids = $database->get_all_sets_ids_in_class($set_id);

	foreach my $group_id (@{$group_ids})
	{
		print '<h3>' . $database->get_citation($group_id, $set_id, 'full') . "</h1>\n";
		$params->mask({eprints => $set_id."_".$database->get_code($group_id, $set_id)});
		print IRStats::View::TopTenTable->new($params, $database)->render();
		print '<hr>';
	}
}

1;
