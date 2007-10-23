package IRStats::CLI::extract_generic_eprints;

=head1 NAME

IRStats::CLI::extract_generic_eprints - create dummy metadata based on the current usage logs

=cut

our @ISA = qw( IRStats::CLI );

use Data::Dumper;
require LWP::UserAgent;

our $USER_AGENT = LWP::UserAgent->new;

use strict;

sub execute
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $data = {};
	my $phrases = {};

	$self->populate($data, $phrases);
	$self->write_to_files($data, $phrases);
}

sub populate
{
	my ($self, $data, $phrases) = @_;

	my $session = $self->{session};
	my $conf = $session->get_conf;
	my $database = $session->get_database;

	my $base_url = $conf->repository_url;
	$base_url =~ s/\/$//;

	my $table = $conf->database_main_stats_table;

	my $sth = $database->prepare("SELECT DISTINCT `eprint` FROM `$table`");
	$database->execute($sth);

	my $dataset = $data->{'eprint'} = {};
	while(my( $eprint_id ) = $sth->fetchrow_array)
	{
		my( $full_citation, $short_citation )
			= $self->get_citation( $eprint_id );
		$dataset->{$eprint_id} = {
			code => $eprint_id,
			short_citation => $short_citation,
			full_citation => $full_citation,
			url => "$base_url/$eprint_id/",
			eprint_ids => [$eprint_id],
		};
	}
}

sub write_to_files
{
	my ($self, $data, $phrases) = @_;
##Now write to the database

	my $session = $self->{session};
	my $conf = $session->get_conf;

	$session->log("Writing IRStats import files");

	my %files = (
		full_citation => 'set_member_full_citations_file',
		short_citation => 'set_member_short_citations_file',
		membership => 'set_membership_file',
		code => 'set_member_codes_file',
		url => 'set_member_urls_file',
		phrases => 'set_phrases_file',
	);

	foreach my $id (keys %files)
	{
		my $file = $files{$id};
		my $filename = $conf->get_path($file);
		open my $fh, ">", $filename or die "Error writing to $filename: $!";
		$files{$id} = $fh;
	}

	while(my( $name, $phrase ) = each %$phrases)
	{
		$phrase =~ s/[\r\n]+//g;
		print {$files{phrases}} "$name\t$phrase\n";
	}

	while(my( $set_id, $dataset ) = each %$data)
	{
		$session->log("--$set_id--");
		my $i = 0;
		while(my( $key, $datamember ) = each %$dataset)
		{
			next unless defined $datamember->{'code'}; #don't write corrupt data
			$i++;

			my $code = "ERROR - $i";
			my $short_citation = "Missing Short Citation";
			my $full_citation = "Missing Full Citation";
			my $url = "";
			my $id = $i;
			my $eprint_ids = [];
			
			#keep the eprint id, make the others numeric
			
			if( defined $datamember->{'code'} )
			{
				$code = $datamember->{'code'};
			}
			if( defined $datamember->{'short_citation'} )
			{
				$short_citation = $datamember->{'short_citation'};
			}
			if( defined $datamember->{'full_citation'} )
			{
				$full_citation = $datamember->{'full_citation'};
			}
			if( defined $datamember->{'url'} )
			{
				$url = $datamember->{'url'};
			}
			if( $set_id eq 'eprint' )
			{
				$id = $code;
			}
			if( defined $datamember->{'eprint_ids'} )
			{
				$eprint_ids = $datamember->{'eprint_ids'};
			}

			#make sure the citations don't have line breaks in them.....
			$full_citation =~ s/[\n\r]/ /g;
			$short_citation =~ s/[\n\r]/ /g;

			print { $files{full_citation} } $set_id, "\t", $id, "\t", $full_citation, "\n";
			print { $files{short_citation} } $set_id, "\t", $id, "\t", $short_citation, "\n";
			print { $files{membership} } $set_id, "\t", $id, "\t", join(',',@{$eprint_ids}), "\n";
			print { $files{code} } $set_id, "\t", $id, "\t", $code, "\n";
			print { $files{url} } $set_id, "\t", $id, "\t", $url, "\n";
		}
	}

	foreach(values %files)
	{
		close($_);
	}
}

sub get_citation
{
	my( $self, $eprint_id ) = @_;

	my $full_citation = "[Unknown eprint $eprint_id?]";
	my $short_citation = $full_citation;

	my $session = $self->{session};
	my $conf = $session->get_conf;
	my $database = $session->get_database;

	my $base_url = $conf->repository_url;
	$base_url =~ s/\/$//;

	my $url = "$base_url/$eprint_id/";

	$session->log("Retrieving $url");

	my $r = $USER_AGENT->get( $url );
#	sleep(rand(3));

	my $page = $r->content;
	if( $r->is_success and $page =~ /<title>(.+?)<\/title>/g )
	{
		$short_citation = $1;
		$short_citation =~ s/[\r\n]+/ /g;
	}
	
	if( $r->is_success and $page =~ /<span class=["']citation["']>/g )
	{
		my $start = pos($page) - length($&);
		my $depth = 1;
		do {
			if( $page =~ m/.*?(<span|<\/span\s*>)/cig )
			{
				if( lc($1) eq '<span' )
				{
					++$depth;
				}
				else
				{
					--$depth;
				}
			}
			else
			{
				$depth = 0;
			}
		} while( $depth > 0 );
		$full_citation = substr($page,$start,pos($page)-$start);
		$full_citation =~ s/[\r\n]+/ /g;

		$session->log("Full citation: $full_citation",3);
	}
	else
	{
		$session->log("Warning: didn't find a citation in ".$r->code." response");
	}

	return ($full_citation, $short_citation);
}

1;
