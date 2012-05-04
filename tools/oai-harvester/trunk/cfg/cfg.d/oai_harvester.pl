# EPrints Services/sf2
# OAI-PMH Harvester Configuration

# Required fields for Plugin::Import::OAIPMH 
@{ $c->{fields}->{eprint} } = ( @{ $c->{fields}->{eprint} }, (

	# The OAI Identifier of the item when it was imported
          {
           'name' => 'oai_identifier',
           'type' => 'text',
           'render_value' => sub {
                        my( $session, $field, $value ) = @_;

                        my $id = $value;
                        return $session->make_doc_fragment() unless( EPrints::Utils::is_set( $value ) );

                        if( $id =~ /^oai\:idei\.fr:(\d+)$/ )
                        {
                                my $link = $session->make_element( "a", href=> "http://idei.fr/neeo.php?a=$1" );
                                $link->appendChild( $session->make_text( "http://idei.fr/neeo.php?a=$1" ) );
                        }

                        return $session->make_text( $value );
                },
          },

	# the 'datestamp' field, as present in the OAI Record header
          {
           'name' => 'oai_lastmod',
           'type' => 'text',
          },

	# the setSpec's for this record (also present in the OAI header)
          {
           'name' => 'oai_set',
           'type' => 'text',
           'multiple' => 1,
          },

) );

#
# Stub OAI Harvesting
#
# called this way:
#
# my $plugin = $session->plugin( 'Import::OAIPMH::MyMetadataFormat' ) or die( 'no plugin' );
#
# my $list = $plugin->input_conf( 'stub' );
# my $stats = $plugin->{stats};
# print "\nItems created: ".$stats->{created};
#
#
# $c->{oai_harvester}->{stub} = {
#	url => 'http://oaiserver.com/oaiscript',	# compulsory
#	set => 'set_to_harvest',			# optional
#	from => '2001-01-01',				# optional, format is YYYY-MM-DD
#	'until' => '2011-12-31',			# optional
#	metadataPrefix => 'oai_dc',			# optional, should be set by the OAIPMH/* plugin
#	default_values => sub {				# optional, gives a chance to set default values
#		my( $session, $epdata, $header ) = @_;
#
#		$epdata->{userid} = 1234;
#		$epdata->{eprint_status} = 'archive';
#
#		# $epdata->{FIELDNAME} = VALUE;
#		
#	},
# };
#


