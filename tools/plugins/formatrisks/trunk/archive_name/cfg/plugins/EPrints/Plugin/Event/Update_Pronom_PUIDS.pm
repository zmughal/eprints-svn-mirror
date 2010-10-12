#######################################################
###                                                 ###
###  Preserv2/EPrints FormatsRisks Main Processor   ###
###                                                 ###
#######################################################
###                                                 ###
###     Developed by David Tarrant and Tim Brody    ###
###                                                 ###
###          Released under the GPL Licence         ###
###           (c) University of Southampton         ###
###                                                 ###
###        Install in the following location:       ###
###                  eprints/tools/                 ###
###                                                 ###
#######################################################

package EPrints::Plugin::Event::Update_Pronom_PUIDS;

@ISA = qw( EPrints::Plugin::Event );

use strict;
use warnings;

sub full_classification
{
	my ( $self ) = @_;
		
	my $session = $self->{session};

	my $dataset = $session->get_repository->get_dataset( "file" );
	
	return unless( $session->get_repository->get_conf( "invocation", "droid" ) );

	my $max_age = $session->get_repository->get_conf( "pronom", "max_age" );
	$max_age = 0 unless defined $max_age;
	
	my $output_file = $session->get_repository->get_conf( "htdocs_path" ) . "/en/droid_classification_ajax.xml";
	my $complete = 1;
	if (-e $output_file) {
		$complete = 0;
		open (MYFILE, $output_file);
		while (<MYFILE>) {
			my ($line) = $_;
			chomp($line);
			if ((substr $line, 0,8) eq "complete") {
				$complete = 1;	
			}
		}
	}
	if ($complete > 0) {
		unlink($output_file);
	} else {
		exit();
	}
	open(MYFILE, ">$output_file");
	print MYFILE sprintf("Processing...");
	close(MYFILE);
	
	my @date = gmtime(time() - $max_age);
	my $expired_date = sprintf("%04d-%02d-%02dT%02d:%02d:%02d",
		$date[5]+1900,
		$date[4]+1,
		@date[3,2,1,0],
	);
	
	my $list = $dataset->search(
		filters => [
			{ meta_fields => [qw( datasetid )], value => "document" },
			{ meta_fields => [qw( pronomid )], value => "" , match => "EX" },
		],
	);
	my $list2 = $dataset->search(
		filters => [
			{ meta_fields => [qw( datasetid )], value => "document" },
			{ meta_fields => [qw( classification_date )], value => "-$expired_date" },
		],
	);
	if ($list->count gt 0 and $list2->count gt 0) {
		$list->union($list2);
	} elsif ($list->count eq 0 and $list2->count gt 0) {
		$list = $list2;
	} elsif ($list->count eq 0) {
		finalise($self);
		exit(1);
	}
	my $total = 0;
	$list->map( sub {
		my( $session, $dataset, $file ) = @_;

		my $document = $file->get_parent();
		return unless valid_document( $document );
		++$total;	
	});

	my $count = 1;

	$list->map( sub {
		open(MYFILE, ">$output_file");
		print MYFILE sprintf("Processing %d of %d [file %8s]\r", $count, $total, $_[2]->get_id);
		close(MYFILE);
		
		my $ret = &update_pronom_identity( @_ );
		if (defined $ret) {
			++$count;
		}
	
		if ($count % 20 == 0) {
			finalise($self);
		}

	} );

	finalise($self);
	
}	
	
sub finalise 
{
	my ( $self ) = @_;
	
	my $session = $self->{session};

	my $output_file = $session->get_repository->get_conf( "htdocs_path" ) . "/en/droid_classification_ajax.xml";
			
	my $pronom_data = $session->get_repository->get_dataset("pronom")->get_object($session, "Unclassified");
	if (!defined $pronom_data)
	{
		$pronom_data = $session->get_repository->get_dataset("pronom")->create_object($session,{pronomid=>"Unclassified",name=>"Unclassified Objects"});
	}
	
	reset_pronom_cache($session);
	
	open(MYFILE, ">$output_file");
	print MYFILE ("Updating Risk Scores");
	close(MYFILE);
	update_risk_scores( $session );
	
	open(MYFILE, ">$output_file");
	print MYFILE ("Updating File Counts");
	close(MYFILE);
	update_file_count( $session );
	
	open(MYFILE, ">$output_file");
	print MYFILE ("complete");
	close(MYFILE);
}

sub valid_document
{
	my ( $document ) = @_;

	return undef unless $document;
	my $eprint = $document->get_parent();
	return undef unless $eprint;
	my $eprint_status = $eprint->get_value('eprint_status');
	return undef unless ($eprint_status eq "buffer" or $eprint_status eq "archive");
	return undef if ($document->has_related_objects( EPrints::Utils::make_relation( "issmallThumbnailVersionOf" )));
	return undef if ($document->has_related_objects( EPrints::Utils::make_relation( "ismediumThumbnailVersionOf" )));
	return undef if ($document->has_related_objects( EPrints::Utils::make_relation( "ispreviewThumbnailVersionOf" )));
	return undef if ($document->has_related_objects( EPrints::Utils::make_relation( "isIndexCodesVersionOf" )));
	
	return 1;
}

sub update_pronom_identity
{
		my( $session, $dataset, $file ) = @_;

		my $document = $file->get_parent();
		return unless valid_document( $document );

		my $fh = $file->get_local_copy();
		return unless defined $fh;

		my $droid_file_list = File::Temp->new( SUFFIX => ".xml");
		my $file_list_xml = $session->make_doc_fragment();
		my $file_collection = $session->make_element("FileCollection", xmlns=>"http://www.nationalarchives.gov.uk/pronom/FileCollection");
		my $identification_file = $session->make_element("IdentificationFile", IdentQuality=>"Not yet run");
		$identification_file->appendChild($session->render_data_element(4,"FilePath",$fh));
		$file_collection->appendChild($identification_file);
		$file_list_xml->appendChild($file_collection);
		print $droid_file_list EPrints::XML::to_string($file_list_xml);
		
		my $droid_xml = File::Temp->new( SUFFIX => ".xml");
		my $sig = $session->get_repository->get_conf( "droid_sig_file" );
		$session->get_repository->exec( "droid",
				SOURCE => $droid_file_list,
				TARGET => substr("$droid_xml",0,-4), # droid always adds .xml
				SIGFILE => "$sig", 
				);

		if ( -e $droid_xml ) {
			my $doc = EPrints::XML::parse_xml("$droid_xml");
		
			my $PUID_node = ($doc->getElementsByTagName( "PUID" ))[0];
			my $PUID;
			my $name;
			my $version;
			my $mimetype;
			if (defined $PUID_node)
			{
				$PUID = EPrints::Utils::tree_to_utf8($PUID_node);
				my $classification_date_node = ($doc->getElementsByTagName( "DateCreated" ))[0];
				my $classification_date = EPrints::Utils::tree_to_utf8($classification_date_node);
				my $classification_status_node = ($doc->getElementsByTagName( "Status" ))[0];
				my $classification_status = EPrints::Utils::tree_to_utf8($classification_status_node);
				$file->set_value( "pronomid", $PUID );
				$file->set_value( "classification_quality", $classification_status );
				$file->set_value( "classification_date", $classification_date );
				$file->commit;
				my $name_node = ($doc->getElementsByTagName( "Name" ))[0];
				$name = defined $name_node ?
					EPrints::Utils::tree_to_utf8($name_node) :
					"";
				my $version_node = ($doc->getElementsByTagName( "Version" ))[0];
				$version = defined $version_node ?
					EPrints::Utils::tree_to_utf8($version_node) :
					"";
				my $mimetype_node = ($doc->getElementsByTagName( "MimeType" ))[0];
				$mimetype = defined $mimetype_node ?
					EPrints::Utils::tree_to_utf8($mimetype_node) :
					"";
			} 
			else 
			{
				$PUID = "UNKNOWN";
				my $classification_date_node = ($doc->getElementsByTagName( "DateCreated" ))[0];
				my $classification_date = EPrints::Utils::tree_to_utf8($classification_date_node);
				my $classification_status = "No Match in Pronom";
				$file->set_value( "pronomid", $PUID );
				$file->set_value( "classification_quality", $classification_status );
				$file->set_value( "classification_date", $classification_date );
				$file->commit;
				$name = "UNKNWON (DROID found no classification match)";
				$mimetype = "";
			}	
			my $pronom_data = $session->get_repository->get_dataset("pronom")->get_object($session, $PUID);
			if (defined $pronom_data)
			{
				$pronom_data->set_value("name", $name);
				$pronom_data->set_value("version", $version);
				$pronom_data->set_value("mime_type", $mimetype);
				$pronom_data->commit;
			}
			else
			{
				$pronom_data = $session->get_repository->get_dataset("pronom")->create_object($session,{pronomid=>$PUID,name=>$name,version=>$version,mime_type=>$mimetype});
			}
			EPrints::XML::dispose($doc);
		}
		return 1;
}


sub update_risk_scores
{
	
	my( $session ) = @_;

	my $doc;
	my $risks_url;
	my $available;
	my $soap_error = "";
	my $unstable = $session->get_repository->get_conf( "pronom_unstable" );

	my $risk_xml = "http://www.eprints.org/services/pronom_risk.xml";
	
	eval 
	{
		$doc = EPrints::XML::parse_url($risk_xml);
	};
	if ($@) 
	{
		$risks_url = "http://nationalarchives.gov.uk/pronom/preservationplanning.asmx";
		$available = 1;
	} 
	else 
	{
		my $node; 
		if ($unstable eq 1) 
		{
			$node = ($doc->getElementsByTagName( "risks_unstable" ))[0];
		} 
		else 
		{
			$node = ($doc->getElementsByTagName( "risks_stable" ))[0];
		}
		$available = ($node->getElementsByTagName( "available" ))[0];
		$available = EPrints::Utils::tree_to_utf8($available);
		if ($available eq 1) 
		{
			$risks_url = ($node->getElementsByTagName( "base_url" ))[0];
			$risks_url = EPrints::Utils::tree_to_utf8($risks_url);
		} 
		else 
		{
			$risks_url = "";
		}
	}
	my @SOAP_ERRORS;
	use SOAP::Lite
		on_fault => sub { my($soap, $res) = @_;
			if( ref( $res ) ) {
				chomp( my $err = $res->faultstring );
				push( @SOAP_ERRORS, "SOAP FAULT: $err" );
			}
			else 
			{
				chomp( my $err = $soap->transport->status );
				push( @SOAP_ERRORS, "TRANSPORT ERROR: $err" );
			}
			return SOAP::SOM->new;
		};
	
	if (!($risks_url eq "")) 
	{
		$soap_error = "";
		my $dataset = $session->get_repository->get_dataset( "pronom" );
		$dataset->map($session, sub 
				{
				my $record = $_[2];
				my $format = $record->get_value("pronomid");
				unless ($format eq "UNKNOWN" || $format eq "Unclassified") 
				{
				my $soap_data = SOAP::Data->name( 'PUID' )->attr({xmlns => 'http://pp.pronom.nationalarchives.gov.uk'});
				my $soap_value = SOAP::Data->value( SOAP::Data->name('Value' => $format) );
				my $soap = SOAP::Lite 
				-> on_action(sub { 'http://pp.pronom.nationalarchives.gov.uk/getFormatRiskIn' } )
				-> proxy($risks_url)
				-> call ($soap_data => $soap_value);
#					-> method (SOAP::Data->name('PUID' => \SOAP::Data->value( SOAP::Data->name('Value' => $format) ))->attr({xmlns => 'http://pp.pronom.nationalarchives.gov.uk'}) );

				my $result = $soap->result();

				foreach my $error (@SOAP_ERRORS) 
				{
				if ($soap_error eq "" && !($error eq "")) 
				{
				$soap_error = $error;
				}
				}
				if ($soap_error eq "") 
				{
					$record->set_value("risk_score",$result);
					$record->commit;
				}
				else 
				{
					print STDERR ("Format Risk Analysis Failed for format ".$format.": \n" . $soap_error . "\n");
					$record->set_value("risk_score",0);
					$record->commit;
				}
				}

				} );
	}
}

sub update_file_count
{
	
	my( $session ) = @_;

	my $dataset = $session->get_repository->get_dataset( "eprint" );

	my $format_files = {};

	$dataset->map( $session, sub {
		my( $session, $dataset, $eprint ) = @_;
		
		foreach my $doc ($eprint->get_all_documents)
		{
			foreach my $file (@{($doc->get_value( "files" ))})
			{
				my $puid = $file->get_value( "pronomid" );
				$puid = "" unless defined $puid;
				push @{ $format_files->{$puid} }, $file->get_id;
			}
		}
	} );
	foreach my $format (keys %{$format_files})
	{
		my $count = $#{$format_files->{$format}}+1;
		my $pronom_data = $session->get_repository->get_dataset("pronom")->get_object($session, $format);
		if (!defined $pronom_data)
		{
			$pronom_data = $session->get_repository->get_dataset("pronom")->get_object($session, "Unclassified");
		}
		$pronom_data->set_value("file_count",$count);
		$pronom_data->commit;
	}
}

sub reset_pronom_cache
{
	my( $session ) = @_;

	my $dataset = $session->get_repository->get_dataset( "pronom" );
        $dataset->map( $session, sub {
                my( $session, $dataset, $pronoms ) = @_;

                foreach my $pronom_data ($pronoms)
                {
			$pronom_data->set_value("file_count",0);
			$pronom_data->commit;
                }
        } );	

}

1;