package IRStats::CLI::update_metadata;

=head1 NAME

IRStats::CLI::extract_metadata_from_archive - extract metadata from an eprints 3 archive

=cut

our @ISA = qw( IRStats::CLI );

# Iterate over fields in a dataset

use EPrints;
use Data::Dumper;

use strict;
use warnings;

sub execute
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $conf = $session->get_conf;
	my $database = $session->get_database;

	my $repository = $conf->repository;

	my $data = {};
	my $phrases = {};
	$self->populate($data, $phrases);

	$database->check_tables;

	$self->write_to_database($data);
	$self->write_phrases( $phrases );
}

sub populate
{
	my ($self, $data, $phrases) = @_;

	my $eprints_session = $self->{session}->get_eprints_session;
	my $session = $self->{session};

	my $conf = $session->get_conf;

	$session->log("Reading eprint ids");

	my @eprintIDs;
	# get a list of all the eprints in the repository
	my $dataset = $eprints_session->get_archive->get_dataset( 'eprint' );
	push @eprintIDs, @{$dataset->get_item_ids( $eprints_session )};

	$session->log("Reading eprint citations and groups");

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
		$phrases->{"set_$field_name"} = EPrints::XML::to_string($field->render_name($eprints_session),"utf-8");
		$session->log("Adding field '".$phrases->{"set_$field_name"}."' as set");
	}

	my $i = 0;
	foreach my $eprintID (@eprintIDs)
	{
		print STDERR "[".$i++."/".@eprintIDs."]\r" if $session->verbose > 1;
#		last if $i > 200; $i++;


		my $eprint = $dataset->get_object( $eprints_session, $eprintID );
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
					$session->log( "Warning! Ignoring set member due to missing code for '$value' (offset $i) in eprint $eprintID while processing $field_name set.", 2 );
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
					$code = EPrints::XML::to_string( $code_field->render_value( $eprints_session, $multiple ? [$code] : $value ));
				}
				if( not exists $data->{$field_name}->{$code} )
				{
					my $full_citation = EPrints::XML::to_string( $field->render_value( $eprints_session, $multiple ? [$value] : $value ), "utf-8");
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


sub write_phrases
{
	my( $self, $phrases ) = @_;
##Now write to the database

	my $session = $self->{session};

	my $conf = $session->get_conf;
	my $database = $session->get_database;

	$session->log("IMPORTING PHRASES");

	my $table_name = $conf->database_table_prefix . "phrases";

	while(my($id,$phrase) = each %$phrases)
	{
		$database->do("DELETE FROM $table_name WHERE phrase_id=?", $id);
		$database->insert_row( $table_name, {
			phrase_id => $id,
			phrase => $phrase,
		});
	}
}

sub write_to_database
{
	my( $self, $data ) = @_;
##Now write to the database

	my $session = $self->{session};

	my $conf = $session->get_conf;
	my $database = $session->get_database;

	$session->log("IMPORTING GROUPS: " . join(', ',keys %{$data}));

	while(my( $set_id, $dataset ) = each %$data)
	{
		$session->log("--$set_id--");

		my $table = $conf->database_set_table_prefix . $set_id;
		my $citation_table = $conf->database_set_table_prefix . $set_id . $conf->database_set_table_citation_suffix;
		my $code_table = $conf->database_set_table_prefix . $set_id .  $conf->database_set_table_code_suffix;

		my $new_table = $table . "_new";
		my $new_citation_table = $citation_table . "_new";
		my $new_code_table = $code_table . "_new";

		$database->check_set_table( $set_id );
		$database->drop_tables( $new_table, $new_citation_table, $new_code_table );
		$database->check_set_table( $set_id, "_new" );

		my $i = 0; #internal ID

		while(my( $set_member_id, $datamember ) = each %$dataset)
		{
			$i++;

			my $code = "ERROR";
			my $short_citation = "Missing Short Citation";
			my $full_citation = "Missing Full Citation";
			my $url = "";

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
			#Make sure we remove duplicate ID numbers
			my %seen = ();
			foreach my $item (@{$datamember->{'eprint_ids'}}) {
				    $seen{$item}++;
			}
			$set_member_id = $i unless ($set_id eq 'eprint'); #swap to numeric ID unless it's an eprint

			foreach (keys %seen)
			{
				$database->insert_row($new_table, {
					set_member_id => $set_member_id,
					eprint_id => $_
				});
			}
			$database->insert_row($new_citation_table, {
				set_member_id => $set_member_id,
				short_citation => $short_citation,
				full_citation => $full_citation,
				url => $url
			});
			$database->insert_row($new_code_table, {
				set_member_id => $set_member_id,
				set_member_code => $code
			});

		}

		for($table, $citation_table, $code_table)
		{
			$database->drop_tables( $_."_old" ); # interupted previous run
			$database->rename_tables( $_ => $_."_old", $_."_new" => $_ );
			$database->drop_tables( $_."_old" );
		}
	}
}

1;
