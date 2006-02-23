######################################################################
#
# EPrints::Dataset 
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=head1 NAME

B<EPrints::DataObj> - Base class for records in EPrints.

=head1 DESCRIPTION

This module is a base class which is inherited by EPrints::DataObj::EPrint, 
EPrints::User, EPrints::DataObj::Subject and EPrints::DataObj::Document and several
other classes.

It is ABSTRACT, its methods should not be called directly.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{data}
#     A reference to a hash containing the metadata of this
#     record.
#
#  $self->{session}
#     The current EPrints::Session
#
#  $self->{dataset}
#     The EPrints::DataSet to which this record belongs.
#
######################################################################

package EPrints::DataObj;

use MIME::Base64 ();

use strict;


######################################################################
=pod

=item $sys_fields = EPrints::DataObj->get_system_field_info

ABSTRACT.

Return an array describing the system metadata of the this 
dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	EPrints::abort( "Abstract EPrints::DataObj->get_system_field_info method called" );
}

######################################################################
=pod

=item $dataobj = EPrints::DataObj->new( $session, $id, [$dataset] )

ABSTRACT.

Return new data object, created by loading it from the database.

$dataset is used by EPrint->new to save searching through all four
tables that it could be in.

=cut
######################################################################

sub new
{
	my( $class, $session, $id ) = @_;

}

######################################################################
=pod

=item $dataobj = EPrints::DataObj->new_from_data( $session, $data, $dataset )

ABSTRACT.

Construct a new EPrints::DataObj object based on the $data hash 
reference of metadata.

Used to create an object from the data retrieved from the database.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

}

######################################################################
=pod

=item $dataobj = EPrints::DataObj->create( $session, @default_data )

ABSTRACT.

Create a new object of this type in the database. 

The syntax for @default_data depends on the type of data object.

=cut
######################################################################

sub create
{
	my( $class, $session, @defaunt_data ) = @_;

}


######################################################################
=pod

=item $dataobj = EPrints::DataObj->create_from_data( $session, $data, $dataset )

Create a new object of this type in the database. 

$dataset is the dataset it will belong to. 

$data is the data structured as with new_from_data.

This will create sub objects also.

=cut
######################################################################

sub create_from_data
{
	my( $class, $session, $data, $dataset ) = @_;

	$data = EPrints::Utils::clone( $data );

	my $defaults = $class->get_defaults( $session, $data );

	foreach my $k ( keys %{$defaults} )
	{
		next if defined $data->{$k};
		$data->{$k} = $defaults->{$k};
	}

	my $ds_id_field = $dataset->get_dataset_id_field;
	if( defined $ds_id_field )
	{
		$data->{$ds_id_field} = $dataset->id;
	}

	$session->get_db->add_record( $dataset, $data );
                                                                                                                  
	my $keyfield = $dataset->get_key_field;
	my $kfname = $keyfield->get_name;
	my $id = $data->{$kfname};
                                                                                                                  
	my $obj = $dataset->get_object( $session, $id );
                                                                                                                  
	return undef unless( defined $obj );

	# queue all the fields for indexing.                                                          
	$obj->queue_all;
                                                                                                                  
	return $obj;
}
                                                                                                                  

######################################################################
=pod

=item $defaults = EPrints::User->get_defaults( $session, $data )

Return default values for this object based on the starting data.

Should be subclassed.

=cut
######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;

	return {};
}

######################################################################
=pod

=item $success = $dataobj->remove

ABSTRACT

Remove this data object from the database. 

Also removes any sub-objects or related files.

Return true if successful.

=cut
######################################################################

sub remove
{
	my( $self ) = @_;

}


######################################################################
=pod

=item $success = $dataobj->commit( [$force] )

ABSTRACT.

Write this object to the database.

If $force isn't true then it only actually modifies the database
if one or more fields have been changed.

Commit may also log the changes, depending on the type of data 
object.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;
	
}




######################################################################
=pod

=item $value = $dataobj->get_value( $fieldname, [$no_id] )

Get a the value of a metadata field. If the field is not set then it returns
undef unless the field has the property multiple set, in which case it returns 
[] (a reference to an empty array).

If $no_id is true and the field has an ID part then only the main part is
returned.

=cut
######################################################################

sub get_value
{
	my( $self, $fieldname, $no_id ) = @_;
	
	my $field = EPrints::Utils::field_from_config_string( $self->{dataset}, $fieldname );

	if( !defined $field )
	{
		EPrints::Config::abort( "Attempt to get value from not existant field: ".$self->{dataset}->id()."/$fieldname" );
	}

	my $r = $field->get_value( $self );

	unless( EPrints::Utils::is_set( $r ) )
	{
		if( $field->get_property( "multiple" ) )
		{
			return [];
		}
		else
		{
			return undef;
		}
	}

	return $r unless( $no_id );

	return $r unless( $field->get_property( "hasid" ) || $field->get_property( "mainpart" ) );

	# Ok, we need to strip out the {id} parts. It's easy if
	# this isn't multiple
	return $r->{main} unless( $field->get_property( "multiple" ) );

	# It's a multiple field, then. Strip the ids from each.
	my $r2 = [];
	foreach( @$r ) { push @{$r2}, $_->{main}; }
	return $r2;
}

sub get_value_raw
{
	my( $self, $fieldname ) = @_;

	return $self->{data}->{$fieldname};
}

######################################################################
=pod

=item $dataobj->set_value( $fieldname, $value )

Set the value of the named metadata field in this record.

=cut 
######################################################################

sub set_value
{
	my( $self , $fieldname, $value ) = @_;

	if( !defined $self->{changed}->{$fieldname} )
	{
		# if it's already changed once then we don't
		# want to fiddle with it again

		if( !_equal( $self->{data}->{$fieldname}, $value ) )
		{
			$self->{changed}->{$fieldname} = $self->{data}->{$fieldname};
		}
	}

	$self->{data}->{$fieldname} = $value;
}

# internal function
# used to see if two data-structures are the same.

sub _equal
{
	my( $a, $b ) = @_;

	# both undef is equal
	if( !EPrints::Utils::is_set($a) && !EPrints::Utils::is_set($b) )
	{
		return 1;
	}

	# one xor other undef is not equal
	if( !EPrints::Utils::is_set($a) || !EPrints::Utils::is_set($b) )
	{
		return 0;
	}

	# simple value
	if( ref($a) eq "" )
	{
		return( $a eq $b );
	}

	if( ref($a) eq "ARRAY" )
	{
		# different lengths?
		return 0 if( scalar @{$a} != scalar @{$b} );
		for(my $i=0; $i<scalar @{$a}; ++$i )
		{
			return 0 unless _equal( $a->[$i], $b->[$i] );
		}
		return 1;
	}

	if( ref($a) eq "HASH" )
	{
		my @akeys = sort keys %{$a};
		my @bkeys = sort keys %{$b};

		# different sizes?
		# return 0 if( scalar @akeys != scalar @bkeys );
		# not testing as one might skip a value, the other define it as
		# undef.

		my %testk = ();
		foreach my $k ( @akeys, @bkeys ) { $testk{$k} = 1; }

		foreach my $k ( keys %testk )
		{	
			return 0 unless _equal( $a->{$k}, $b->{$k} );
		}
		return 1;
	}

	print STDERR "Warning: can't compare $a and $b\n";
	return 0;
}

######################################################################
=pod

=item @values = $dataobj->get_values( $fieldnames )

Returns a list of all the values in this record of all the fields specified
by $fieldnames. $fieldnames should be in the format used by browse views - slash
seperated fieldnames with an optional .id suffix to indicate the id part rather
than the main part. 

For example "author.id/editor.id" would return a list of all author and editor
ids from this record.

=cut 
######################################################################

sub get_values
{
	my( $self, $fieldnames ) = @_;

	my %values = ();
	foreach my $fieldname ( split( "/" , $fieldnames ) )
	{
		my $field = EPrints::Utils::field_from_config_string( 
					$self->{dataset}, $fieldname );
		my $v = $self->{data}->{$field->get_name()};
		if( $field->get_property( "multiple" ) )
		{
			foreach( @{$v} )
			{
				$values{$field->which_bit( $_ )} = 1;
			}
		}
		else
		{
			$values{$field->which_bit( $v )} = 1;
		}
	}

	return keys %values;
}


######################################################################
=pod

=item $session = $dataobj->get_session

Returns the EPrints::Session object to which this record belongs.

=cut
######################################################################

sub get_session
{
	my( $self ) = @_;

	return $self->{session};
}


######################################################################
=pod

=item $data = $dataobj->get_data

Returns a reference to the hash table of all the metadata for this record keyed 
by fieldname.

=cut
######################################################################

sub get_data
{
	my( $self ) = @_;
	
	return $self->{data};
}


######################################################################
=pod

=item $dataset = $dataobj->get_dataset

Returns the EPrints::DataSet object to which this record belongs.

=cut
######################################################################

sub get_dataset
{
	my( $self ) = @_;
	
	return $self->{dataset};
}


######################################################################
=pod 

=item $bool = $dataobj->is_set( $fieldname )

Returns true if the named field is set in this record, otherwise false.

=cut
######################################################################

sub is_set
{
	my( $self, $fieldname ) = @_;

	if( !$self->{dataset}->get_field( $fieldname ) )
	{
		$self->{session}->get_repository->log(
			 "is_set( $fieldname ): Unknown field" );
	}

	return EPrints::Utils::is_set( $self->{data}->{$fieldname} );
}


######################################################################
=pod

=item $id = $dataobj->get_id

Returns the value of the primary key of this record.

=cut
######################################################################

sub get_id
{
	my( $self ) = @_;

	my $keyfield = $self->{dataset}->get_key_field();

	return $self->{data}->{$keyfield->get_name()};
}

######################################################################
=pod


=item $xhtml = $dataobj->render_value( $fieldname, [$showall] )

Returns the rendered version of the value of the given field, as appropriate
for the current session. If $showall is true then all values are rendered - 
this is usually used for staff viewing data.

=cut
######################################################################

sub render_value
{
	my( $self, $fieldname, $showall ) = @_;

	my $field = $self->{dataset}->get_field( $fieldname );	
	
	return $field->render_value( $self->{session}, $self->get_value($fieldname), $showall );
}


######################################################################
=pod

=item $xhtml = $dataobj->render_citation( [$style], [$url] )

Renders the record as a citation. If $style is set then it uses that citation
style from the citations config file. Otherwise $style defaults to the type
of this record. If $url is set then the citiation will link to the specified
URL.

=cut
######################################################################

sub render_citation
{
	my( $self , $style , $url ) = @_;

	unless( defined $style )
	{
		$style=$self->get_type();
	}

	my $stylespec = $self->{session}->get_citation_spec(
					$self->{dataset},
					$style );

	EPrints::Utils::render_citation( $self , $stylespec , $url );
}


######################################################################
=pod

=item $xhtml = $dataobj->render_citation_link( [$style], [$staff] )

Renders a citation (as above) but as a link to the URL for this item. For
example - the abstract page of an eprint. If $staff is true then the 
citation links to the staff URL - which will provide more a full staff view 
of this record.

=cut
######################################################################

sub render_citation_link
{
	my( $self , $style , $staff ) = @_;

	my $url = $self->get_url( $staff );
	
	my $citation = $self->render_citation( $style, $url );

	return $citation;
}


######################################################################
=pod

=item $xhtml = $dataobj->render_description

Returns a short description of this object using the default citation style
for this dataset.

=cut
######################################################################

sub render_description
{
	my( $self ) = @_;

	my $stylespec = $self->{session}->get_citation_spec(
					$self->{dataset} );
				
	my $r =  EPrints::Utils::render_citation( $self , $stylespec );

	return $r;
}

######################################################################
=pod

=item ($xhtml, $title ) = $dataobj->render

Return a chunk of XHTML DOM describing this object in the normal way.
This is the public view of the record, not the staff view.

=cut
######################################################################

sub render
{
	my( $self ) = @_;

	return( $self->render_description, $self->render_description );
}

######################################################################
=pod

=item ($xhtml, $title ) = $dataobj->render_full

Return an XHTML table in DOM describing this record. All values of
all fields are listed. This is the staff view.

=cut
######################################################################

sub render_full
{
	my( $self ) = @_;

	my $unspec_fields = $self->{session}->make_doc_fragment;
	my $unspec_first = 1;

	# Show all the fields
	my $table = $self->{session}->make_element( "table",
					border=>"0",
					cellpadding=>"3" );

	my @fields = $self->get_dataset->get_fields;
	foreach my $field ( @fields )
	{
		next unless( $field->get_property( "show_in_html" ) );

		my $name = $field->get_name();
		if( $self->is_set( $name ) )
		{
			$table->appendChild( $self->{session}->render_row(
				$field->render_name( $self->{session} ),	
				$self->render_value( $field->get_name(), 1 ) ) );
			next;
		}

		# unspecified value, add it to the list
		if( $unspec_first )
		{
			$unspec_first = 0;
		}
		else
		{
			$unspec_fields->appendChild( 
				$self->{session}->make_text( ", " ) );
		}
		$unspec_fields->appendChild( 
			$field->render_name( $self->{session} ) );


	}

	$table->appendChild( $self->{session}->render_row(
			$self->{session}->html_phrase( "lib/dataobj:unspecified" ),
			$unspec_fields ) );

	return $table;
}




######################################################################
=pod

=item $url = $dataobj->get_url( [$staff] )

Returns the URL for this record, for example the URL of the abstract page
of an eprint. If $staff is true then this returns the URL to the staff 
page for this item, which will show the full record and offer staff edit
options.

=cut
######################################################################

sub get_url
{
	my( $self , $staff ) = @_;

	return "EPrints::DataObj::get_url should have been over-ridden.";
}


######################################################################
=pod

=item $type = $dataobj->get_type

Returns the type of this record - type of user, type of eprint etc.

=cut
######################################################################

sub get_type
{
	my( $self ) = @_;

	return "EPrints::DataObj::get_type should have been over-ridden.";
}

######################################################################
=pod

=item $xmlfragment = $dataobj->to_xml( %opts )

Convert this object into an XML fragment. 

%opts are:

no_xmlns=>1 : do not include a xmlns attribute in the 
outer element. (This assumes this chunk appears in a larger tree 
where the xmlns is already set correctly.

showempty=>1 : fields with no value are shown.

version=>"code" : pick what version of the EPrints XML format
to use "1" or "2"

embed=>1 : include the data of a file, not just it's URL.

=cut
######################################################################

sub to_xml
{
	my( $self, %opts ) = @_;

	$opts{version} = "2" unless defined $opts{version};

	my $frag = $self->{session}->make_doc_fragment;
	$frag->appendChild( $self->{session}->make_text( "  " ) );
	my %attrs = ();
	my $ns = EPrints::XML::namespace( 'data', $opts{version} );
	if( !defined $ns )
	{
		$self->{session}->get_repository->log(
			 "to_xml: unknown version: ".$opts{version} );
		#error
		return;
	}

	$attrs{'xmlns'}=$ns unless( $opts{no_xmlns} );
	my $tl = "record";
	if( $opts{version} == 2 ) { $tl = $self->{dataset}->confid; }	
	my $r = $self->{session}->make_element( $tl, %attrs );
#$r->appendChild( $self->{session}->make_text( "x\nx" ) );
	foreach my $field ( $self->{dataset}->get_fields() )
	{
		next unless( $field->get_property( "export_as_xml" ) );

		unless( $opts{show_empty} )
		{
			next unless( $self->is_set( $field->get_name() ) );
		}

		if( $opts{version} eq "2" )
		{
			$r->appendChild( $field->to_xml( 
				$self->{session}, 
				$self->get_value( $field->get_name() ),
				1 ) ); # no xmlns on inner elements
		}
		if( $opts{version} eq "1" )
		{
			$r->appendChild( $field->to_xml_old( 
				$self->{session}, 
				$self->get_value( $field->get_name() ),
				1 ) ); # no xmlns on inner elements
		}
	}

	if( $opts{version} eq "2" )
	{
		if( $self->{dataset}->confid eq "user" )
		{
			my $subscriptions = $self->{session}->make_element( "subscriptions" );
			$subscriptions->appendChild( $self->{session}->make_text( "\n" ) );
			foreach my $subscription ( $self->get_subscriptions )
			{
				$subscriptions->appendChild( $self->{session}->make_text( "  " ) );
				$subscriptions->appendChild( $subscription->to_xml( %opts ) );
			}	
			$r->appendChild( $self->{session}->make_text( "\n  " ) );
			$r->appendChild( $subscriptions );
			$subscriptions->appendChild( $self->{session}->make_text( "  " ) );
			$r->appendChild( $self->{session}->make_text( "\n" ) );
		}

		if( $self->{dataset}->confid eq "eprint" )
		{
			my $docs = $self->{session}->make_element( "documents" );
			$docs->appendChild( $self->{session}->make_text( "\n" ) );
			foreach my $doc ( $self->get_all_documents )
			{
				$docs->appendChild( $self->{session}->make_text( "  " ) );
				$docs->appendChild( $doc->to_xml( %opts ) );
			}	
			$r->appendChild( $self->{session}->make_text( "\n  " ) );
			$r->appendChild( $docs );
			$docs->appendChild( $self->{session}->make_text( "  " ) );
			$r->appendChild( $self->{session}->make_text( "\n" ) );
		}

		if( $self->{dataset}->confid eq "document" )
		{
			my $files = $self->{session}->make_element( "files" );
			$files->appendChild( $self->{session}->make_text( "\n" ) );
			my %files = $self->files;
			foreach my $filename ( keys %files )
			{
				my $file = $self->{session}->make_element( "file" );

				$file->appendChild( 
					$self->{session}->render_data_element( 
						6, 
						'filename',
						$filename ) );
				$file->appendChild( 
					$self->{session}->render_data_element( 
						6, 
						'filesize',
						$files{$filename} ) );
				$file->appendChild( 
					$self->{session}->render_data_element( 
						6, 
						'url',
						$self->get_url($filename) ) );
				if( $opts{embed} )
				{
					my $fullpath = $self->local_path."/".$filename;
					open( FH, $fullpath ) || die "fullpath '$fullpath' read error: $!";
					my $data = join( "", <FH> );
					close FH;
					my $data_el = $self->{session}->make_element( 'data', encoding=>"base64" );
					$data_el->appendChild( $self->{session}->make_text( MIME::Base64::encode($data) ) );
					$file->appendChild( $data_el );
				}
				$files->appendChild( $self->{session}->make_text( "    " ) );
				$files->appendChild( $file );
				$file->appendChild( $self->{session}->make_text( "\n    " ) );
				$files->appendChild( $self->{session}->make_text( "\n" ) );
			}
			$r->appendChild( $self->{session}->make_text( "\n  " ) );
			$r->appendChild( $files );
			$files->appendChild( $self->{session}->make_text( "  " ) );
			$r->appendChild( $self->{session}->make_text( "\n" ) );
		}	
	}

	$r->appendChild( $self->{session}->make_text( "  " ) );
	$frag->appendChild( $r );
	$frag->appendChild( $self->{session}->make_text( "\n" ) );

	return $frag;
}

######################################################################
=pod

=item $plugin_output = $detaobj->export( $plugin_id, %params )

Apply an output plugin to this items. Return the results.

=cut
######################################################################

sub export
{
	my( $self, $out_plugin_id, %params ) = @_;

	my $plugin_id = "Output::".$out_plugin_id;
	my $plugin = $self->{session}->plugin( $plugin_id );

	unless( defined $plugin )
	{
		EPrints::Config::abort( "Could not find plugin $plugin_id" );
	}

	my $req_plugin_type = "dataobj/".$self->{dataset}->confid;

	unless( $plugin->can_accept( $req_plugin_type ) )
	{
		EPrints::Config::abort( 
"Plugin $plugin_id can't process $req_plugin_type data." );
	}
	
	
	return $plugin->output_dataobj( $self, %params );
}

######################################################################
=pod

=item $dataobj->queue_changes

Add all the changed fields into the indexers todo queue.

=cut
######################################################################

sub queue_changes
{
	my( $self ) = @_;

	foreach my $fieldname ( keys %{$self->{changed}} )
	{
		my $field = $self->{dataset}->get_field( $fieldname );

		next unless( $field->get_property( "text_index" ) );

		$self->{session}->get_db->index_queue( 
			$self->{dataset}->id,
			$self->get_id,
			$fieldname );
	}	
}

######################################################################
=pod

=item $dataobj->queue_all

Add all the fields into the indexers todo queue.

=cut
######################################################################

sub queue_all
{
	my( $self ) = @_;

	my @fields = $self->{dataset}->get_fields;
	foreach my $field ( @fields )
	{
		next unless( $field->get_property( "text_index" ) );

		$self->{session}->get_db->index_queue( 
			$self->{dataset}->id,
			$self->get_id,
			$field->get_name );
	}	
}

######################################################################
=pod

=item @roles = $dataobj->user_roles( $user )

Return any roles $user might have on $dataobj.

=cut
######################################################################

sub user_roles
{
	my( $self, $user ) = @_;

	return ();
}


######################################################################
=pod

######################################################################
=pod

=back

=cut
######################################################################

1; # for use success
