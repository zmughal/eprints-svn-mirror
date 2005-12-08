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

This module is a base class which is inherited by EPrints::EPrint, 
EPrints::User, EPrints::Subject and EPrints::Document.

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
use strict;


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

sub _equal
{
	my( $a, $b ) = @_;

	# both undef is equal
	return 1 if( (!defined $a || $a eq '') && (!defined $b || $b eq '') );
	# one xor other undef is not equal
	return 0 if( !defined $a || !defined $b );

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
		return 0 if( scalar @akeys != scalar @bkeys );
		for(my $i=0; $i<scalar @akeys; ++$i )
		{
			return 0 unless ( $akeys[$i] eq $bkeys[$i] );
			return 0 unless _equal( $a->{$akeys[$i]}, $b->{$bkeys[$i]} );
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

	if( !exists $self->{data}->{$fieldname} )
	{
		$self->{session}->get_archive->log(
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

$no_xmlns=>1 : do not include a xmlns attribute in the 
outer element. (This assumes this chunk appears in a larger tree 
where the xmlns is already set correctly.

$showempty=>1 : fields with no value are shown.

$version=>"code" : pick what version of the EPrints XML format
to use "1" or "2"

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
		$self->{session}->get_archive->log(
			 "to_xml: unknown version: ".$opts{version} );
		#error
		return;
	}
	$attrs{'xmlns'}=$ns unless( $opts{no_xmlns} );
	my $r = $self->{session}->make_element( "record", %attrs );
	
	$r->appendChild( $self->{session}->make_text( "\n" ) );
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

	my $plugin_id = "output/".$out_plugin_id;
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

######################################################################
=pod

=back

=cut
######################################################################

# Things what could maybe go here maybe...

# commit 

# remove

# new

# new_from_data

# validate

# render

1; # for use success
