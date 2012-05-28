$c->add_dataset_field( "document", {
	name => "readme",
	type => "longtext",
	virtual => 1,
	fromform => sub {
		my( $value, $repo, $doc, $basename ) = @_;

		utf8::encode( $value ); # bytes

		# get around a bug where $obj is the parent eprint and not $doc
		if( !$doc->isa( "EPrints::DataObj::Document" ) )
		{
			$basename =~ /doc(\d+)/;
			my $eprint = $doc;
			$doc = $repo->dataset( "document" )->dataobj( $1 );
			EPrints->abort if $doc->value( "eprintid" ) != $eprint->id;
		}

		my $readme = $doc->search_related( "isReadmeOf" )->item( 0 );
		my $readme_file = $readme->stored_file( "README.txt" ) if defined $readme;
		if( defined $readme )
		{
			if( !EPrints::Utils::is_set( $value ) )
			{
				$readme->remove;
			}
			elsif( !defined $readme_file )
			{
				$readme_file = $readme->create_subdataobj( "files", {
					filename => "README.txt",
					filesize => length($value),
					mime_type => "text/plain",
					_content => \$value,
				});
				$readme->set_value( "main", "README.txt" );
				$readme->commit;
			}
			else
			{
				my $eof = 0;
				$readme_file->set_file( sub { !$eof++ ? $value : "" }, length($value) );
				$readme_file->commit;
			}
		}
		else
		{
			my $eprint = $doc->parent;
			$readme_file = $eprint->create_subdataobj( "documents", {
				content => "readme",
				main => "README.txt",
				format => "other",
				mime_type => "text/plain",
				files => [{
					filename => "README.txt",
					filesize => length($value),
					mime_type => "text/plain",
					_content => \$value,
				}],
			});
			$readme_file->add_relation( $doc, "isVolatileVersionOf" );
			$readme_file->add_relation( $doc, "isReadmeOf" );
			$readme_file->commit;
		}

		undef;
	},
	# toform doesn't pass object
	render_input => sub {
		my( $self, $repo, $value, $dataset, $staff, $hidden_fields, $doc, $basename ) = @_;

		my $readme = $doc->search_related( "isReadmeOf" )->item( 0 );
		my $readme_file = $readme->stored_file( "README.txt" ) if defined $readme;
		if( defined $readme_file )
		{
			$value = "";
			$readme_file->get_file( sub { $value .= $_[0]; 1 } );
		}

		utf8::decode( $value );

		$_[2] = $value;
		return $self->render_input_field_actual( @_[1..$#_] );
	},
});

$c->add_dataset_field( "document", {
	name => "experiment_stage",
	type => "namedset",
	set_name => "experiment_stage",
	input_rows => 1,
});
