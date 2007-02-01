#!/usr/bin/perl -w -I/opt/eprints2/perl_lib

use EPrints::EPrint;
use EPrints::Session;
use EPrints::Subject;

use Data::Dumper;

use strict;

my $notes = "";

my $session = new EPrints::Session( 1 , $ARGV[0] );
exit( 1 ) unless( defined $session );

my $path = $ARGV[0]."_ep3cfg";
mkdir( $path );
mkdir( "$path/cfg" );

my $archive = $session->get_archive;

mkdir( "$path/cfg/lang" );
mkdir( "$path/cfg/lang/en" );
mkdir( "$path/cfg/lang/en/phrases" );

write_phrases();

mkdir( "$path/cfg/workflows" );
mkdir( "$path/cfg/workflows/eprint" );
mkdir( "$path/cfg/workflows/user" );

write_workflow("eprint");
write_workflow("user");

mkdir( "$path/cfg/namedsets" );

write_namedsets();

mkdir( "$path/cfg/cfg.d" );

mk_eprint_fields();
mk_user_fields();

open( NOTES, ">$path/migration_notes.txt" );
print NOTES $notes;
close NOTES;

$session->terminate();
exit;

## FIELDS ##

sub namemunge
{
	my( $fdata ) = @_;

	my $name = "eprint.".$fdata->{name};

	if( !$fdata->{hasid} ) 
	{
		$notes.= "$name has no hasid, skipping cleverness\n";
		return;
	}

	if( !$fdata->{multiple} )
	{
		$notes.= "$name is not multiple, skipping cleverness\n";
		return;
	}

	if( $fdata->{type} ne "name" )
	{
		$notes.= "$name is not type=name, skipping cleverness\n";
		return;
	}


	$fdata->{type} = "compound";

	$fdata->{fields} = [
		{
			sub_name => "name",
			type     => "name",
			hide_honourific => $fdata->{hide_honourific},
			hide_lineage => $fdata->{hide_lineage},
			family_first => $fdata->{family_first},
		},
		{
			sub_name => "id",
			type     => "text",
			allow_null => 1,
			input_cols => $fdata->{input_id_cols},
        },
	];

	delete $fdata->{hasid};
	delete $fdata->{hide_honourific};
	delete $fdata->{hide_lineage};
	delete $fdata->{family_first};
	delete $fdata->{input_id_cols};

	$notes.= "Made $name into a compound field\n";          
}


sub mk_eprint_fields 
{
	my $archivefields = $archive->get_conf( "archivefields", "eprint" );
	my $outfields = [];
	my $ids = {};
	foreach my $fdata ( @{$archivefields} )
	{
		if( $fdata->{name} eq "fileinfo" )
		{
			$notes.= "removing eprint.fileinfo field.\n";
			next;
		}

		if( $fdata->{name} eq "authors" )
		{
			$notes.= "altering eprint.authors to be called creators\n";
			$fdata->{name} = "creators";
		}

		if( $fdata->{name} eq "date_effective" )
		{
			$notes.= "removing eprint.date_effective\n";
			next;
		}

		if( $fdata->{name} eq "date_sub" )
		{
			$notes.= "removing eprint.date_sub\n";
			next;
		}

		if( $fdata->{name} eq "date_issue" )
		{
			$notes.= "adding date_type\n";
			push @{$outfields}, {
            	'name' => 'date_type',
            	'type' => 'set',
            	'options' => [
                           	'published',
                           'submitted',
                           'completed',
                         ],
            	'input_style' => 'medium',
          	};
	
			$ids->{'date_type'} = 1;
			$fdata->{name} = "date";
			$notes.= "changing date_issue to date\n";
		}

		field_munge( $fdata );

		if( $fdata->{name} eq "creators" || $fdata->{name} eq "editors" )
		{
			namemunge( $fdata );
		}
			
		push @{$outfields}, $fdata;
		$ids->{$fdata->{name}} = 1;
	}

	if( !defined $ids->{'full_text_status'} )
	{
		push @{$outfields}, 
          {
            'name' => 'full_text_status',
            'type' => 'set',
            'options' => [
                           'public',
                           'restricted',
                           'none',
                         ],
            'input_style' => 'medium',
          };
		$notes.= "added field 'full_text_status'\n";
	}

	
	my $file = "$path/cfg/cfg.d/eprint_fields.pl";
	open( OUT, ">$file" ) || die "Can't write $file: $!";
	print OUT Data::Dumper->Dump(
				[$outfields],
				['$c->{fields}->{eprint}'] );
	close OUT;
}


sub mk_user_fields 
{
	my $archivefields = $archive->get_conf( "archivefields", "user" );
	my $outfields = [];
	foreach my $fdata ( @{$archivefields} )
	{
		field_munge( $fdata );
		push @{$outfields}, $fdata;
	}
	
	my $file = "$path/cfg/cfg.d/user_fields.pl";
	open( OUT, ">$file" ) || die "Can't write $file: $!";
	print OUT Data::Dumper->Dump(
				[$outfields],
				['$c->{fields}->{user}'] );
	close OUT;
}

sub field_munge
{
	my( $fdata ) = @_;

	if( defined $fdata->{render_opts} )
	{
		foreach my $k ( keys %{$fdata->{render_opts}} )
		{
			$fdata->{"render_".$k} = $fdata->{render_opts}->{$k};
		}
		delete $fdata->{render_opts};
	}


	if( $fdata->{type} eq "datatype" )
	{
		$fdata->{set_name} = $fdata->{datasetid};
		delete $fdata->{datasetid};
		if( $fdata->{set_name} eq "language" )
		{
			$fdata->{set_name} = "languages";
		}
		$fdata->{type} = "namedset";
	}

	if( defined $fdata->{multilang} )
	{
		if( $fdata->{multilang} )
		{
			die "multilang not yet handled, sorry!";
		}
		delete $fdata->{multilang};
	}
}


### NAMED SETS ###

sub write_namedsets
{
	# document, security, user, eprint

	foreach my $dsid ( qw/ document security user eprint / )
	{
		my $dataset = $archive->get_dataset( $dsid );
		my $types = $dataset->get_types;
		my $file = "$path/cfg/namedsets/$dsid";
		open( FILE, ">$file" ) || die "can't write $file: $!";
		print FILE "# Imported via migration-tool from EPrints 2\n\n";
		foreach( @{$types} ) { print FILE "$_\n"; }
		close FILE;
	}
}

### WORKFLOWS ###

sub write_workflow
{
	my( $dsid ) = @_;

	my $dataset = $archive->get_dataset( $dsid );

	my $types = $dataset->get_types;

	my $dstype = "type";
	$dstype = "usertype" if( $dsid eq "user" );

	my $xml = 
'<?xml version="1.0" encoding="utf-8"?>

<workflow xmlns="http://eprints.org/ep3/workflow" xmlns:epc="http://eprints.org/ep3/control">

  <flow>
';
	if( $dsid eq "eprint" )
	{
		$xml.='
    <stage ref="type"/>
    <stage ref="files"/>
';
	}

	my %pages;
	
	foreach my $type ( @$types )
	{
		$xml.= "    <epc:if test=\"$dstype = '$type'\">\n";
		foreach my $page ( $dataset->get_type_pages( $type ) )
		{
			$pages{$page} = 1;
			$xml.= "      <stage ref=\"$page\" />\n";
		}
		$xml.= "    </epc:if>\n";
	}
	$xml.="  </flow>\n\n";

	foreach my $page ( keys %pages )
	{
		$xml .= "  <stage name=\"$page\">\n";

		foreach my $type ( @$types )
		{
			my @fields = skooge( "workflow $dsid, stage $page, type $type", $dataset->get_type_fields( $type ) );
			my @stafffields = skooge( "workflow $dsid, stage $page, type $type", $dataset->get_type_fields( $type, 1 ) );
			
			my $smap = {};
			foreach( @stafffields ) { $smap->{$_->get_name} = $_; }
			next unless( scalar @fields || scalar @stafffields );
			$xml .= "    <epc:if test=\"$dstype = '$type'\">\n";
			foreach my $field ( @fields )
			{
				$xml .= "      <component><field ref=\"".$field->get_name."\" ";
				if( $field->get_property( "required" ) )
				{
					$xml .= "required=\"yes\" ";
				}
				$xml .= "/></component>\n";
				delete $smap->{$field->get_name};
			}
			if( scalar keys %{$smap} )
			{
				$xml.= "      <epc:if test=\"\$STAFF_ONLY = 'TRUE'\">\n";
				foreach my $field ( values %{$smap} )
				{
					$xml .= "        <component><field ref=\"".$field->get_name."\" ";
					if( $field->get_property( "required" ) )
					{
						$xml .= "required=\"yes\" ";
					}
					$xml .= "/></component>\n";
				}
				$xml.= "      </epc:if>\n";
			}
		    $xml.= "    </epc:if>\n";

 		}

		$xml .= "  </stage>\n\n";
	}

	if( $dsid eq "eprint" )
	{
		$xml.='

  <stage name="type">
    <component><field ref="type" required="yes" /></component>
  </stage>

  <stage name="files">
    <component type="XHTML"><epc:phrase ref="Plugin/InputForm/Component/Upload:help" /></component>
    <component type="Upload">
      <field ref="format" />
      <field ref="formatdesc" />
      <field ref="security" />
      <field ref="license" />
      <field ref="date_embargo" />
<!--  <field ref="language" /> -->
    </component>
  </stage>

';
	}

	$xml .= "</workflow>\n\n";

	my $file = "$path/cfg/workflows/$dsid/default.xml";
	open( FILE, ">$file" ) || die "could not write $file: $!";
	print FILE $xml;
	close FILE;

}


sub skooge 
{
	my( $place, @fields ) = @_;

	my @out = ();

	foreach my $field ( @fields )
	{
		my $name =$field->get_name;
		if( $name eq "date_sub" )
		{
			$notes.= "Removing date_sub from $place\n";
			next;
		}
		if( $name eq "date_effective" )
		{
			$notes.= "Removing date_effective from $place\n";
			next;
		}
		if( $name eq "date_issue" )
		{
			$notes.= "Renaming date_issue to date in $place\n";
			my %data = %{$field};
			$data{name} = "date";
			$field = EPrints::MetaField->new(%data);
			push @out, $field;
	
			$notes.= "Adding date_type\n";
			push @out, EPrints::MetaField->new(            
				'name' => 'date_type',
            	'type' => 'set',
            	'options' => [
                           'published',
                           'submitted',
                           'completed',
                         ],
            	'input_style' => 'medium',
				dataset=>$field->get_dataset,
            );

			next;
		}



		push @out, $field;
	}

	return @out;
}

## PHRASES ##

sub write_phrases
{

	my $phrases = $session->{lang}->{archivedata};
	
	my $sets = {};
	foreach my $phraseid ( sort keys %{$phrases} )
	{
		my $id = "unknown";
	
		if( $phraseid =~ m/^eprint_field(name|help|opt)_/ ) { $id = "eprint_fields"; }
		if( $phraseid =~ m/^eprint_radio_/ ) { $id = "eprint_fields"; }
		if( $phraseid =~ m/^user_field(name|help|opt)_/ ) { $id = "user_fields"; }
		if( $phraseid =~ m/^user_radio_/ ) { $id = "user_fields"; }
		if( $phraseid =~ m/^document_typename_/ ) { $id = "document_formats"; }
		if( $phraseid =~ m/^security_typename_/ ) { $id = "document_security"; }
		if( $phraseid =~ m/^eprint_typename_/ ) { $id = "eprint_types"; }
		if( $phraseid =~ m/^eprint_optdetails_type_/ ) { $id = "eprint_types"; }
		if( $phraseid =~ m/^ordername_eprint_/ ) { $id = "eprint_order"; }
		if( $phraseid =~ m/^ordername_user_/ ) { $id = "user_order"; }
		if( $phraseid =~ m/^viewname_eprint_/ ) { $id = "views"; }
		if( $phraseid =~ m/^user_typename_/ ) { $id = "user_fields"; }
		if( $phraseid =~ m/^metapage_title_/ ) { $id = "workflow"; }
		
		push @{$sets->{$id}}, $phraseid;
	}
	
	foreach my $fileid ( keys %{$sets} )
	{
		my $file = "$path/cfg/lang/en/phrases/$fileid.xml";
		open( FILE, ">$file" ) || die "Could not write to $file: $!";
		print FILE <<END;
<?xml version="1.0" encoding="iso-8859-1" standalone="no" ?>
<!DOCTYPE phrases SYSTEM "entities.dtd">
                                                                                           
<epp:phrases xmlns="http://www.w3.org/1999/xhtml" xmlns:epp="http://eprints.org/ep3/phrase" xmlns:epc="http://eprints.org/ep3/control">

END

		my %extras = ();
		if( $fileid eq "eprint_fields" )
		{
			$extras{eprint_fieldname_creators_name} = 'Creators Name';
			$extras{eprint_fieldhelp_creators_name} = '';
			$extras{eprint_fieldname_date} = 'Date';
			$extras{eprint_fieldhelp_date} = 'The date this EPrint was completed, submitted to a publisher, published or submitted for a Ph.D.';
			$extras{eprint_fieldname_date_type} = 'Date Type';
			$extras{eprint_fieldhelp_date_type} = 'The event to which the date applies.';
			$extras{eprint_fieldopt_date_type_published} = 'Published';
			$extras{eprint_fieldopt_date_type_submitted} = 'Submitted';
			$extras{eprint_fieldopt_date_type_completed} = 'Completed';
			$extras{eprint_fieldname_full_text_status} = 'Full Text Status';
			$extras{eprint_fieldhelp_full_text_status} = '';
			$extras{eprint_fieldopt_full_text_status_public} = 'Public';
			$extras{eprint_fieldopt_full_text_status_none} = 'None';
			$extras{eprint_fieldopt_full_text_status_restricted} = 'Restricted';
		}

		if( $fileid eq "document_security" )
		{
			$extras{security_typename_public} = "Anyone";
		}

		if( $fileid eq "workflow" )
		{
			$extras{metapage_title_type} = 'Type';
			$extras{metapage_title_files} = 'Upload';
		}

		foreach my $phraseid ( sort @{$sets->{$fileid}} )
		{
			next if $phraseid eq "security_typename_";

			my $phrase = $phrases->{$phraseid};
			my $xml = $phrase->toString;
			$xml =~ s/ep:phrase/epp:phrase/g;
			$xml =~ s/ep:pin/epc:pin/g;
			$xml =~ s/pin ref="/pin name="/g;
			$xml =~ s/phrase ref="/phrase id="/g;
			print FILE "    $xml\n";
			delete $extras{$phraseid};
		}

		if( scalar keys %extras )
		{
			print FILE "\n\n<!-- The following phrases were added automatically by migration script. -->\n\n";
			foreach my $phraseid ( sort keys %extras )
			{
				print FILE "    <epp:phrase id=\"$phraseid\">".$extras{$phraseid}."</epp:phrase>\n";
			}
		}
		

		print FILE "\n</epp:phrases>\n";
		close FILE;
	}
}


