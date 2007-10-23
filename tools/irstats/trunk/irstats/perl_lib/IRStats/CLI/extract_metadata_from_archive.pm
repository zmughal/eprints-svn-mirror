package IRStats::CLI::extract_metadata_from_archive;

=head1 NAME

IRStats::CLI::extract_metadata_from_archive - extract metadata from an eprints 2 archive

=cut

our @ISA = qw( IRStats::CLI );

# Iterate over fields in a dataset

use EPrints::Session;
use Data::Dumper;

use strict;
use warnings;

sub execute
{
	my( $self ) = @_;

	eval "use EPrints";
	$self->{eprints_version} = $@ ? 2 : 3;

	my $session = $self->{session};

	my $conf = $session->get_conf;
	my $database = $session->get_database;

	my $repository = $conf->repository;

	# Start session
	my $eprints = new EPrints::Session( 1, $repository );
	die "Unable to connect to $repository" unless( defined $eprints );

	my $data = {};
	my $phrases = {};
	$self->populate($data, $phrases, $eprints);
	$eprints->terminate();
	$self->write_to_files($data, $phrases);
}

sub populate
{
	my ($self, $data, $phrases, $session) = @_;

	my $s = $self->{session};

	my $conf = $s->get_conf;

	$s->log("Reading eprint ids");

	my @eprintIDs;
	# get a list of all the eprints in the repository
	for(qw( archive buffer inbox deletion ))
	{
		my $dataset = $session->get_archive->get_dataset( $_ );
		push @eprintIDs, @{$dataset->get_item_ids( $session )};
	}

#	splice @eprintIDs, 100;

	$s->log("Reading eprint citations and groups");

	my $dataset = $session->get_archive->get_dataset( 'archive' );

	my %field_sets; # the sets to export
	my %field_ids; # the id to use if we need to hide the code
	foreach my $field_name ($conf->set_ids)
	{
		if( !$dataset->has_field( $field_name ) )
		{
			die "$field_name is not a valid field in the repository ".$conf->repository;
		}
		my $field = $field_sets{$field_name} = $dataset->get_field( $field_name );
		$field_ids{$field_name} = 0;
		$phrases->{"set_$field_name"} = EPrints::XML::to_string($field->render_name($session),"utf-8");
		$s->log("Adding field '".$phrases->{"set_$field_name"}."' as set");
	}

	my $i = 0;
	foreach my $eprintID (@eprintIDs)
	{
		print STDERR "[".$i++."/".@eprintIDs."]\r" if $s->verbose > 1;

		my $eprint = $dataset->get_object( $session, $eprintID );
		next if( !defined $eprint );
		$data->{eprint}->{$eprintID} = {
			full_citation => EPrints::XML::to_string( $eprint->render_citation_link(), "utf-8" ),
			short_citation => $eprint->get_value('title'),
			url => $eprint->get_url(),
			code => $eprintID,
			eprint_ids => [$eprintID]
		};

		while(my( $field_name, $field ) = each %field_sets)
		{
			my $values = $eprint->get_value( $field_name );
			next unless EPrints::Utils::is_set( $values );
			my $multiple = 1;
			if( ref($values) ne 'ARRAY' )
			{
				$values = [$values];
				$multiple = 0;
			}
			my $codes = [];
			my $hide_code = 0; # should we hide the code?
			my $code_field;
			if( $conf->is_set( $field_name . "_code_field" ) )
			{
				my $id_field = $conf->get_value( $field_name . "_code_field" );
				$codes = $eprint->get_value( $id_field );
				$codes = [$codes] unless $multiple;
				$code_field = $dataset->get_field( $id_field );
			}
			elsif( $conf->is_set( $field_name . "_id_field" ) )
			{
				my $id_field = $conf->get_value( $field_name . "_id_field" );
				$codes = $eprint->get_value( $id_field );
				$codes = [$codes] unless $multiple;
				$hide_code = 1;
				$code_field = $dataset->get_field( $id_field );
			}
			else
			{
				@$codes = @$values;
				$code_field = $field;
			}
			for(my $i = 0; $i < @$values; $i++)
			{
				my $value = $values->[$i];
				my $code = $codes->[$i];
				if( not defined $code )
				{
					$s->log( "Warning! Ignoring set member due to missing code for '$value' (offset $i) in eprint $eprintID while processing $field_name set.", 2 );
					next;
				}
				# eprints-2 style identity (e.g. email address)
				elsif( ref($code) eq 'HASH' and defined $code->{id} )
				{
					$code = $code->{id};
				}
				# The code is complex, so lets render it to get the 'code'
				elsif( ref($code) eq 'HASH' )
				{
					$code = EPrints::XML::to_string( $code_field->render_value( $session, $multiple ? [$code] : $value ));
				}
				if( not exists $data->{$field_name}->{$code} )
				{
					my $full_citation = EPrints::XML::to_string( $field->render_value( $session, $multiple ? [$value] : $value ), "utf-8");
					my $short_citation = ref($value) eq 'HASH' ?
						$full_citation :
						uc($value);
					my $code_value = $hide_code ?
						++$field_ids{$field_name} :
						$code;

					$data->{$field_name}->{$code} = {
						full_citation => $full_citation,
						short_citation => $short_citation,
						code => $code_value,
						eprint_ids => [$eprintID],
					};
				}
				else
				{
					push @{$data->{$field_name}->{$code}->{eprint_ids}}, $eprintID;
				}
			}
		}
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

1;
