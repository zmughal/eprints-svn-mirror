package EPrints::Plugin::Import::OAIPMH;

use strict;
use warnings;

use EPrints::Plugin::Import;

our @ISA = qw/ EPrints::Plugin::Import /;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = 'OAI-PMH Importer (abstract class)';
	$self->{visible} = "none";
	$self->{produce} = [ 'list/eprint', 'dataobj/eprint' ];

	$self->{import_documents} = 1;

	return $self unless( defined $self->{session} );

	unless( EPrints::Utils::require_if_exists( "HTTP::OAI" ) )
	{
		$self->{disable} = 1;
		return $self;
	}

	# will keep some stats about how many items got deleted/updated/created
	$self->{stats}->{deleted} = 0;
	$self->{stats}->{updated} = 0;
	$self->{stats}->{created} = 0;

	return $self;
}

# define your conf in cfg.d/oai_harvester.pl
# configuration may get over-written eg. the 'from'/'until' arguments
sub input_conf
{
	my( $self, $conf_id, %extra_conf ) = @_;
	
	return undef unless( defined $conf_id );

	my $conf = $self->{session}->config( 'oai_harvester', $conf_id );	
	return undef unless( defined $conf );

	foreach( keys %extra_conf )
	{
		$conf->{$_} = $extra_conf{$_};
	}

	return $self->input_url( %$conf );
}

# MAIN METHOD:
# will harvest a URL with a metadataPrefix, will cope with the operations:
# - create: no records exist in the repository -> create a new one
# - update: updates an existing record if the datestamp in the OAI answer is later than the one on the existing record
# - delete: moves item flags as 'deleted' in OAI to the 'deletion' dataset (
#
# OPTIONS:
# 
# url *
# metadataPrefix *
# set
# from
# until
#
# RETURNS
# should return a dataobj/eprint or list/eprint
sub input_url
{
	my( $self, %opts ) = @_;

	my $session = $self->{session};

	unless( defined $opts{url} )
	{
		$session->log( "Missing parameter 'url' when calling input_url" );
		return undef;
	}

	$self->{harvester} = HTTP::OAI::Harvester ->new(
		'baseURL' => $opts{url}
	);
	return undef unless( defined $self->{harvester} );

	my %oai_opts;
	$oai_opts{metadataPrefix} = $self->{metadataPrefix} unless( defined $opts{metadataPrefix} );

	foreach( 'metadataPrefix', 'set', 'from', 'until' )
	{
		next unless( defined $opts{$_} );
		$oai_opts{$_} = $opts{$_};
	}

	# keep a copy for ourselves!
	$self->{oai} = \%oai_opts;

	# retrieve all identifiers
	my $lr = $self->{harvester}->ListIdentifiers( %oai_opts );
	
	$self->{oai}->{default_values} = $opts{default_values};

	my @eprint_ids;

	while( my $header = $lr->next )
	{
		my $id = $header->identifier;
		my $oai_date = $header->datestamp;

		# attempt to retrieve an existing EPrint object, given an OAI identifier
		my $eprint = $self->get_eprint( $id );

		if( $header->is_deleted() )
		{	
			# move item to deletion if OAI flagged it as 'deleted'
			if( defined $eprint )
			{
				$self->delete_eprint( $eprint );
				$self->{stats}->{deleted}++;
			}

			# otherwise, ignore the non-existing item

			next;
		}

		if( defined $eprint )
		{
			# potential update if eprint.oai_lastmod < oai_lastmod
			my $ep_date = $eprint->get_value( "oai_lastmod" );
			next unless( $self->cmp_dates( $ep_date, $oai_date ) );

			# OK, update record!
			my $epid = $self->update_eprint( $eprint, $header );
			if( defined $epid )
			{
				push @eprint_ids, $epid;
				$self->{stats}->{updated}++;
			}
		}
		else
		{	
			# create a new object
			my $epid = $self->create_eprint( $header );
			if( defined $epid )
			{
				push @eprint_ids, $epid;
				$self->{stats}->{created}++;
			}

			# debug/dev/test
			# last;
		}

	}
	
	return EPrints::List->new( 
		ids => \@eprint_ids, 
		session => $session, 
		dataset => $self->{session}->dataset( 'eprint' ) 
	);
}

sub delete_eprint
{
	my( $self, $eprint ) = @_;

	unless( $eprint->move_to_deletion )
	{
		$self->{session}->log( "OAI-PMH Importer: Failed to move eprint '".$eprint->get_id."' to deletion." );
		return;
	}

	return $eprint->commit;		# TODO do we need to commit?
}

# very similar to create_eprint actually, probably worth merging the two
sub update_eprint
{
	my( $self, $eprint, $header ) = @_;

	# get metadata, update record

	my $record = $self->get_record( $header->identifier )->next;

	if( $record->is_error )
	{	
		$self->{session}->log( 'OAI-PMH Error (GetRecord): '.$record->message );
		return undef;
	}

	my $xml = $record->metadata->dom;

	my $md;
	for($xml->documentElement->childNodes)
	{
		$md = $_, last if $_->nodeType == 1;
	}
	return undef unless defined $md;

	my $epdata = $self->xml_to_epdata( $md );
	return undef unless( EPrints::Utils::is_set( $epdata ) );

	$epdata->{oai_identifier} = $header->identifier;
	$epdata->{oai_lastmod} = $header->datestamp;
	$self->set_default_values( $epdata, $header );

	# to help Plugin::Import::epdata_to_dataobj (it'll update the fields for us!). note scoping and 'local'.
	{
		$epdata->{eprintid} = $eprint->get_id;
		local $self->{update} = 1;
		local $self->{session}->{config}->{enable_import_ids} = 1;

		$eprint = $self->epdata_to_dataobj( $self->{session}->dataset( 'eprint' ), $epdata );
	}

	$self->import_documents( $eprint, $xml );

	$eprint->commit;

	return $eprint->get_id;
}

sub create_eprint
{
	my( $self, $header ) = @_;

	my $record = $self->get_record( $header->identifier )->next;

	if( $record->is_error )
	{	
		$self->{session}->log( 'OAI-PMH Error (GetRecord): '.$record->message );
		return undef;
	}

	my $xml = $record->metadata->dom;

	my $md;
	for($xml->documentElement->childNodes)
	{
		$md = $_, last if $_->nodeType == 1;
	}
	return undef unless defined $md;

	my $epdata = $self->xml_to_epdata( $md );
	return undef unless( EPrints::Utils::is_set( $epdata ) );

	# set default values for epdata
	$epdata->{oai_identifier} = $header->identifier;
	$epdata->{oai_lastmod} = $header->datestamp;
	$self->set_default_values( $epdata, $header );

	# re-using Plugin::Import::epdata_to_dataobj generic method to turn epdata into a data object
	my $eprint = $self->epdata_to_dataobj( $self->{session}->dataset( 'eprint' ), $epdata );
	return undef unless( defined $eprint );

	$self->import_documents( $eprint, $xml );

	$eprint->commit;

	return $eprint->get_id;
}

# gives a chance to import documents from a remote location (sometimes the URL of the full-text is present in the XML, but this depends on the XML format used)
# by default, do nothing
sub import_documents
{
	my( $self, $eprint, $xml ) = @_;
}

sub xml_to_epdata
{
	my( $self, $xml ) = @_;
	EPrints::abort( 'Plugin::Import::OAIPMH::xml_to_epdata should be sub-classed!' );
	return undef;
}



# HELPER METHODS BELOW

sub create_document
{
        my( $self, $url, $eprint ) = @_;

        return unless( defined $url );

        my $doc_data = { eprintid => $eprint->get_id, format => 'other' };

        my $doc_ds = $self->{session}->get_repository->get_dataset( 'document' );
        my $document = $doc_ds->create_object( $self->{session}, $doc_data );
        if( !defined $document )
        {
                print STDERR "\nFailed to create document (from '$url')!!";
                return;
        }

        $url = URI::Escape::uri_unescape( $url );
        my $success = $document->upload_url( $url );
        if( !$success )
        {
                $document->remove();
                print STDERR "\n(1) Download of document failed (from '$url')";
                return;
        }

        my $main = $document->get_value( "main" );
        unless( defined $main && length $main )
        {
                my $endfile = $url;
                $endfile =~ s/.*\///;
                $document->set_main( $endfile );
		$document->commit;
		$main = $document->get_main;
        }

# do extra checks that the 'main' file exists:
        my %files = $document->files;
        if( scalar(keys %files) && defined $main )
        {
                my $guess_mime =  $self->{session}->get_repository->call( 'guess_doc_type',
                        $self->{session},
                        $main );

                $document->set_value( 'format', $guess_mime );
        }
        else
        {
                # we tried to download something but then there are no files on the disk so we can remove the document safely:
		print STDERR "\n(2) Download of document failed (from '$url')";
                $document->remove();
        }

        $document->commit;

        return $document;
}

sub get_eprint
{
	my( $self, $oai_id ) = @_;

        my $session = $self->{session};

        my $ds = $session->dataset( "eprint" );

        my $searchexp = EPrints::Search->new(
                session => $session,
                dataset => $ds
	);

        $searchexp->add_field(
                $ds->get_field( "oai_identifier" ),
                "$oai_id",
                "EQ",
                "ANY" );

        my $list = $searchexp->perform_search;
	return undef unless( $list->count > 0 );

        my @eprints = $list->get_records(0,1);
        return $eprints[0];
}

# return 1 if( $date2 > $date1 )
sub cmp_dates
{
        my( $self, $date1, $date2 ) = @_;

        return 1 unless( defined $date2 && defined $date1 );

        my @d1 = split /[- :TZ]/, $date1;
        my @d2 = split /[- :TZ]/, $date2;

        # 6 = yyyy + mm + dd + hh + mm + ss
        for(my $i = 0; $i < 6; $i++ )
        {
                next unless( defined $d1[$i] || defined $d2[$i] );
                return 1 if( $d2[$i] > $d1[$i] );
        }

        return 0;
}

sub get_record
{
	my( $self, $id ) = @_;

	return $self->{harvester}->GetRecord(
		identifier => $id,
		metadataPrefix => $self->{oai}->{metadataPrefix},
	);
}

sub set_default_values
{
	my( $self, $epdata, $header ) = @_;

	my $default_values_fn = $self->{oai}->{default_values};

	if( defined $default_values_fn && ref( $default_values_fn ) eq 'CODE' )
	{
		# set automatic values declared in the local configuration

		eval { 
			&$default_values_fn( $self->{session}, $epdata, $header );
		};

		if( $@ )
		{
			$self->{session}->log( ref($self).": Failed to run 'default_values' method." );
			return 0;
		}
		return 1;
	}
	
	return 0;
}

# @conditions in the format:
# { name => 'attribute_name', value => 'attribute_value' }
sub get_node_content
{
        my( $self, $node, $nodename, @conditions ) = @_;

        my $values = $self->get_node_content_multiple( $node, $nodename, @conditions );

        return EPrints::Utils::is_set( $values ) ? $values->[0] : undef;
}

sub get_node_content_multiple
{
        my( $self, $node, $nodename, @conditions ) = @_;

        my @values;
        my @tmpnodes = $node->getElementsByTagName( "$nodename" );
        return if( !scalar(@tmpnodes) );
        return unless( defined $tmpnodes[0]);

        foreach my $tnode (@tmpnodes)
        {
                my $keep_node = 1;
                foreach my $cond (@conditions)
                {
                        my $attr_name = $cond->{name};
                        my $attr_value = $cond->{value};
                        unless( defined $attr_name && defined $attr_value )
                        {
                                $keep_node = 0;
                                last;
                        }

                        my $node_attr_value = $tnode->getAttribute( $attr_name );

                        if( !defined $node_attr_value || ( $node_attr_value ne $attr_value ) )
                        {
                                $keep_node = 0;
                        }
                }
                next unless( $keep_node );

                my $text = $tnode->textContent;
                next unless( EPrints::Utils::is_set( $text ) );
                push @values, $text;
        }

        return \@values;
}

1;
