package EPrints::Plugin::Event::Migration;

@ISA = qw( EPrints::Plugin::Event );

use strict;

sub migrate
{
	my( $self, $format, $plan_id, %migration_info) = @_;

	if( !defined $format )
	{
		Carp::carp "Expected format argument";
		return 0;
	}
	

	my $result = $self->_find_and_migrate($format,$plan_id,%migration_info);

	#return $self->_migrate( $format, $migration_info );
}

sub _find_and_migrate
{
	my ( $self, $format, $plan_id, %migration_info) = @_;
	
	my $pres_plan = EPrints::DataObj::Preservation_Plan->new(
                                $self->{session},
                                $plan_id
                        );

#print STDERR "PLAN " . $pres_plan->get_id() . "\n\n";
	
	my $session = $self->{session};
	my $dataset = $self->{session}->get_repository->get_dataset( "file" );

	my $searchexp = EPrints::Search->new(
			session => $session,
			dataset => $dataset,
			filters => [
			{ meta_fields => [qw( datasetid )], value => "document" },
			{ meta_fields => [qw( pronomid )], value => "$format", match => "EX" },
			],
			);
	my $list = $searchexp->perform_search;
	my $ret = 0;
	my $i = 0;
	$list->map( sub { 
			my $file = $_[2];
			my $parent_doc = $file->get_parent;
#print STDERR "REACHED SAFETY LIMIT\n\n", return if $i++ > 0;
			foreach my $dataobj (@{($parent_doc->get_related_objects( EPrints::Utils::make_relation( "hasMigratedVersion" ) ))})
			{
#print STDERR "$dataobj\n";
				if( $dataobj->has_object_relations( $pres_plan, EPrints::Utils::make_relation( "isMigrationResultOf" ) ) )
				{
#print STDERR "ALREADY MIGRATED\n\n";
					return;
				}
			}
			$ret = $self->_migrate_file($file, $pres_plan, %migration_info);
		} );

	return $ret;
}

sub _migrate_file {
	
	my ( $self, $file, $pres_plan, %migration_info ) = @_;	

#print STDERR "GOT HERE WITH PLAN_ID " . $plan_id . "\n\n";

	my ($suffix,$tool,$parameters);

	my $session = $self->{session};

	foreach my $key (keys %migration_info) {
		my $value = $migration_info{$key};
		if ($key eq "targetFormat") {
			$suffix = $value;	
		}
		if ($key eq "toolIdentifier") {
			$tool = $value;
		}
		if ($key eq "parameters") {
			$parameters = $value;
		}
#print STDERR "INDEXER OUT: " . $key . " = " . $value . "\n\n";
	}

	my $full_filename = $file->get_value("filename");
	$full_filename =~ s/(\.[a-zA-Z0-9]+)?$/.$suffix/;
#print STDERR "FILENAME " . $full_filename . "\n\n";
#print STDERR "SUFFIX " . $suffix . "\n\n";

	my $parent_doc = $file->get_parent();
	my $eprint = $parent_doc->get_parent();
	
#print STDERR $file->get_local_copy() . " IS PART OF EPRINT : " . $eprint->get_id() . "\n\n";

        my $src_path = $file->get_local_copy;
        my $temp_path = File::Temp->new(UNLINK => 0, SUFFIX=>".".$suffix);

        my $doc_type = "public";
        
	my $doc_data = {
                parent => $eprint,
                eprintid => $eprint->get_id(),
                main => $full_filename,
                format => $session->call( 'guess_doc_type', $session, $full_filename ),
                formatdesc => 'Migrated (Preservation) from Document ID: ' . $parent_doc->get_id() . ' (' . $parent_doc->get_type . ')',
                relation => [{
                        type => EPrints::Utils::make_relation( "isVersionOf" ),
                        uri => $parent_doc->internal_uri(),
			},{
                        type => EPrints::Utils::make_relation( "isMigratedVersionOf" ),
                        uri => $parent_doc->internal_uri(),
	                },{
                        type => EPrints::Utils::make_relation( "isMigrationResultOf" ),
                        uri => $pres_plan->internal_uri(),
                	}]
                };

        my $doc_ds = $session->get_repository->get_dataset( 'document' );
        my $new_doc = $doc_ds->create_object( $session, $doc_data );

        $new_doc->commit;

        $parent_doc->add_object_relations(
                $new_doc,
                EPrints::Utils::make_relation( "hasVersion" ) => undef,
                EPrints::Utils::make_relation( "hasMigratedVersion" ) => undef,
        );

        $parent_doc->commit;	
	
	my $program = $self->_lookup_tool($tool);
	my $cmd = $session->get_conf( 'executables',$program );
	
	my $full_file_path = $file->get_local_copy();
	$parameters =~ s/\%INFILE\%/${full_file_path}/;
	$parameters =~ s/\%OUTFILE\%/${temp_path}/;

	$cmd = $cmd." ". $parameters;
#print STDERR "COMMAND " . $cmd . "\n\n";
        system( $cmd );

        unless( -e $temp_path )
        {
#print STDERR "\n\nLooks like it failed to generate a new file.";
                next;
        }

        my $filesize = -s "$temp_path";

	$new_doc->upload( $temp_path, $full_filename, undef , $filesize );
	$new_doc->commit;

        unlink ( $temp_path );

	return 1;
}

sub _lookup_tool {

	my ( $self, $uri ) = @_;

	#FIXME - THIS ROUTINE SHOULD LOOK THIS VALUE UP IN SOME SORT OF LINKED DATA REGISTRY
	
	if ($uri eq "http://dbpedia.org/data/ImageMagick") {
		return "convert";
	}
	
	return "convert";

}

1;
