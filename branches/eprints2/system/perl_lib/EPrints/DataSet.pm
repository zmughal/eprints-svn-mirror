######################################################################
#
# EPrints::DataSet
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

B<EPrints::DataSet> - a dataset is a set of records in the eprints system with
the same metadata.

=head1 DESCRIPTION

This module describes an EPrint dataset.

An repository has one of each type of dataset:

cachemap, counter, user, archive, buffer, inbox, document, subject,
subscription, deletion, eprint, language, arclanguage, security,
license, access.

A normal dataset (eg. "user") has a package associated with it 
(eg. EPrints::DataObj::User) which must be a subclass of EPrints::DataObj 
and a number of SQL tables which are prefixed with the dataset name.
Most datasets also have a set of associated EPrints::MetaField's which
may be optional or compulsary depending on the type eg. books have editors
but posters don't but they are both EPrints.

Types and what fields are in them is configured in metadata-types.xml
for a given repository.

Datasets have some default fields plus additional ones configured
in ArchiveMetadataFieldsConfig.pm.

But there are some exceptions:

=over 4

=item cachemap, counter

Don't have a package, types or metadata fields associated.

=item archive, buffer, inbox, deletion

All have the same types, package and metadata fields as eprints, but
are filtered by eprint_status.

=item subject, history

Do not have types.

=item language, arclanguage

These don't have fields or SQL tables, they are used in metadata
field configuration as their types are part of the system - all known
languages & languages supported by this repository, respectively.

=item security

Does not have fields or SQL tables but does have types - these are the 
security options for a documenmt. A document already has a type - pdf/ps/html 
so the set of security settings belong to this dataset instead. A type with an 
id of an empty string is handled specially as it means publically available.

=back

EPrints::DataSet objects are cached by the related EPrints::Repository
object and usually obtained by calling.

$ds = $repository->get_dataset( "inbox" );

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{id}
#     The id of this dataset.
#
#  $self->{confid}
#     The config-id of this dataset, usual the same as {id} but is always
#     "eprints" for inbox,archive,buffer,deletion as they share the same
#     configuration.
#
#  $self->{repository}
#     A reference to the EPrints::Repository to which this dataset belongs.
#
#  $self->{fields}
#     An array of all the EPrints::MetaField's belonging to this dataset.
#
#  $self->{system_fields}
#     An array of the non-optional EPrints::MetaField's which are hard
#     coded into this dataset.
#
#  $self->{field_index}
#     A hash keyed on fieldname containing the fields in {fields}
#
#  $self->{types}
#     Magic for arclanguage and language, otherwise comes from 
#     metadata-types.xml. Contains a hash keyed by type. Each value is a
#     list of EPrints::MetaFields that may be edited by a user in the
#     order they should be presented with 'required' set as needed.
#
#  $self->{typesreq}
#     Reference to a hash indexed by typeid. Values are references to arrays
#     containing references to all requrired metafields for the type.
#
#  $self->{staff_types}
#     As for {types} but for fields which may be edited by an editor or
#     administrator.
#
#  $self->{pages} 
#     A reference to a hash indexed by typeid, the value of which is
#     another hash. That hash is indexed by pageid and it's values are
#     references to arrays of fields in the order they appear on that 
#     page.
#
#  $self->{staff_pages} 
#     Identical to {pages} except includes "staffonly" fields.
#
#  $self->{page_order} 
#     A reference to a hash indexed by typeid. The value of which is
#     a ref. to an array containing the order of the pages of fields
#     in that type.
# 
#  $self->{type_order}
#     A list of type-ids in the order they should be displayed.
#
#  $self->{default_order}
#     The default option for "order by?" in a search form.
#
#  $self->{type_field_order}
#     A hash keying typeid->[ list of field id's ] where the list is
#     the order of the fields in that type.
#
######################################################################

package EPrints::DataSet;

use EPrints;

use strict;

# filters is the filters to apply to this dataset before returning
# values.

# dataset_id_field is a field to write the dataset id to when an item
# is created. 

# These are both used by the virtual datasets inbox, buffer etc.

my $INFO = {
	cachemap => {
		sqlname => "cachemap"
	},
	counter => {
		sqlname => "counters"
	},
	user => {
		sqlname => "user",
		class => "EPrints::DataObj::User",
		import => 1,
	},
	archive => {
		sqlname => "eprint",
		class => "EPrints::DataObj::EPrint",
		confid => "eprint",
		import => 1,
		filters => [ { meta_fields => [ 'eprint_status' ], value => 'archive', describe=>0 } ],
		dataset_id_field => "eprint_status",
	},
	buffer => {
		sqlname => "eprint",
		class => "EPrints::DataObj::EPrint",
		confid => "eprint",
		import => 1,
		filters => [ { meta_fields => [ 'eprint_status' ], value => 'buffer', describe=>0 } ],
		dataset_id_field => "eprint_status",
	},
	inbox => {
		sqlname => "eprint",
		class => "EPrints::DataObj::EPrint",
		confid => "eprint",
		import => 1,
		filters => [ { meta_fields => [ 'eprint_status' ], value => 'inbox', describe=>0 } ],
		dataset_id_field => "eprint_status",
	},
	deletion => {
		sqlname => "eprint",
		class => "EPrints::DataObj::EPrint",
		confid => "eprint",
		import => 1,
		filters => [ { meta_fields => [ 'eprint_status' ], value => 'deletion', describe=>0 } ],
		dataset_id_field => "eprint_status",
	},
	eprint => {
		sqlname => "eprint",
		class => "EPrints::DataObj::EPrint"
	},
	document => {
		sqlname => "document",
		class => "EPrints::DataObj::Document",
		import => 1,
	},
	subject => {
		sqlname => "subject",
		class => "EPrints::DataObj::Subject",
		import => 1,
	},
	license => {
		sqlname => "license",
		class => "EPrints::DataObj::License",
		import => 1,
	},
#	permission => {
#		sqlname => "permission",
#		class => "EPrints::DataObj::Permission",
#		import => 1,
#	},
	history => {
		sqlname => "history",
		class => "EPrints::DataObj::History",
		import => 1,
	},
	subscription => {
		sqlname => "subscription",
		class => "EPrints::DataObj::Subscription",
		import => 1,
	},
	access => {
		sqlname => "access",
		class => "EPrints::DataObj::Access",
		import => 1,
	},
	# language and security are here so they can be used in
	# "datatype" fields.
	language => {},
	arclanguage => {},
	security => {}
};


######################################################################
=pod

=item $ds = EPrints::DataSet->new_stub( $id )

Creates a dataset object without any types or fields. Useful to
avoid problems with something a dataset does depending on loading
the dataset. It can still be queried about other things, such as
SQL table names. 

=cut
######################################################################

sub new_stub
{
	my( $class , $id ) = @_;

	if( !defined $INFO->{$id} )
	{
		# no repository info, so can't log.
		EPrints::abort( "Unknown dataset name: $id" );
	}
	my $self = {};
	bless $self, $class;

	$self->{id} = $id;
	$self->{confid} = $INFO->{$id}->{confid};
	$self->{confid} = $id unless( defined $self->{confid} );

	return $self;
}



######################################################################
=pod

=item $ds = EPrints::DataSet->new( $repository, $id, $typesconf )

Return the dataset specified by $id. It needs the information
in $typesconf and you probably should not call this directly
but get access to a dataset via the repository object as described
above.

Note that dataset know $repository and vice versa - which means they
will not get garbage collected.

=cut
######################################################################

sub new
{
	my( $class , $repository , $id , $typesconf, $cache ) = @_;
	
	my $self = EPrints::DataSet->new_stub( $id );

	$self->{repository} = $repository;

	$self->{fields} = [];
	$self->{system_fields} = [];
	$self->{field_index} = {};
	$self->{types} = {};
	$self->{typesreq} = {};
	# staff types is the same list, but includes fields
	# which are only shown during staff mode editing. 
	# eg. The "Editor" filter.
	$self->{staff_types} = {};
	$self->{type_order} = [];
	$self->{type_field_order} = {};

	if( $id eq "language" )
	{	
		foreach( EPrints::Config::get_languages() )
		{
			$self->{types}->{$_} = [];
			push @{$self->{type_order}},$_;
		}
		return $self;
	}
	if( $id eq "arclanguage" )
	{	
		foreach( @{$repository->get_conf( "languages" )} )
		{
			$self->{types}->{$_} = [];
			$self->{staff_types}->{$_} = [];
			push @{$self->{type_order}},$_;
		}
		return $self;
	}


	$self->{default_order} = $self->{repository}->
			get_conf( "default_order" , $self->{confid} );


	if( defined $cache->{$self->{confid}} )
	{
		foreach( "fields", "system_fields", "field_index",
			"types", "typesreq", "staff_types", "type_order",
			"pages", "staff_pages", "page_order" )
		{
			$self->{$_} = $cache->{$self->{confid}}->{$_};
		}
		return $self;
	}
			

	my $oclass = $self->get_object_class;
	if( defined $oclass )
	{
		foreach my $fielddata ( $oclass->get_system_field_info() )
		{
			my $field = EPrints::MetaField->new( dataset=>$self , %{$fielddata} );	
			push @{$self->{fields}}	, $field;
			push @{$self->{system_fields}} , $field;
			$self->{field_index}->{$field->get_name()} = $field;
		}

		if( $self->{confid} eq "eprint" )
		{
			if( $self->{repository}->get_conf( "submission_long_types" ) )
			{
				$self->{field_index}->{type}->set_property( 
					"input_style", "long" );
			}
		}
	}
	my $repository_fields = $repository->get_conf( "archivefields", $self->{confid} );
	if( $repository_fields )
	{
		foreach my $fielddata ( @{$repository_fields} )
		{
			my $field = EPrints::MetaField->new( dataset=>$self , %{$fielddata} );	
			push @{$self->{fields}}	, $field;
			$self->{field_index}->{$field->get_name()} = $field;
		}
	}

	if( defined $typesconf->{$self->{confid}} )
	{
		$self->{type_order} = $typesconf->{$self->{confid}}->{_order};
		foreach my $typeid ( keys %{$typesconf->{$self->{confid}}} )
		{
			next if( $typeid eq "_order" );

			my $typedata = $typesconf->{$self->{confid}}->{$typeid};

			$self->{type_field_order}->{$typeid} = $typedata->{field_order};
			if( !defined $self->{type_field_order}->{$typeid} )
			{
				$self->{type_field_order}->{$typeid} = [keys %{$typedata->{fields}}];
			}

			$self->{types}->{$typeid} = [];
			$self->{typesreq}->{$typeid} = [];
			$self->{staff_types}->{$typeid} = [];

			# System fields are now not part of the "type" fields
			# unless expicitly set.

			# foreach( @{$self->{system_fields}} )
			# {
			#	 push @{$self->{types}->{$typeid}}, $_;
			# }
		
			#cjg junk///?$self->{field_order}->{$typeid} = $typedata->{page_order};
#cjg the "sort" is to avoid it accidently looking right.
			foreach my $fname ( @{$self->{type_field_order}->{$typeid}} )
			{
				#shouldn't get any not in the type, but paranoia's ok...
				next unless defined $typedata->{fields}->{$fname}; 

				my $f = $typedata->{fields}->{$fname};
				if( !defined $self->{field_index}->{$f->{id}} )
				{
					EPrints::abort( 
$self->{repository}->get_id.": ".
'Could not find field "'.$f->{id}.'" in dataset "'.$id.'", '.
'although it is'."\n".'part of type: "'.$typeid.'"' );
				}

				my $field = $self->{field_index}->{$f->{id}};
				if( !defined $field )
				{
					$repository->log( "Unknown field: $_ in ".
						$self->{confid}."($typeid)" );
				}

				# set the required flag, but don't override a 
				# system level required.
				if( $field->get_property( "required" ) 
					|| $f->{required} )
				{
					push @{$self->{typesreq}->{$typeid}},
						$field;
				}

				unless( $f->{staffonly} ) 
				{
					push @{$self->{types}->{$typeid}}, 
						$field;
				}
				push @{$self->{staff_types}->{$typeid}}, $field;
			}

			$self->{pages}->{$typeid} = {};
			$self->{staff_pages}->{$typeid} = {};
			$self->{page_order}->{$typeid} = $typedata->{page_order};
			foreach my $page ( sort keys %{$typedata->{pages}} )
			{
				my @pagefields = @{$typedata->{pages}->{$page}};
				$self->{pages}->{$typeid}->{$page} = [];
				$self->{staff_pages}->{$typeid}->{$page} = [];

				foreach my $pagefield ( @pagefields )
				{
					my $f = $typedata->{fields}->{$pagefield};
					my $field = $self->{field_index}->{$f->{id}};

					unless( $f->{staffonly} ) 
					{
						push @{$self->{pages}->{$typeid}->{$page}}, 
							$field;
					}
					push @{$self->{staff_pages}->{$typeid}->{$page}}, 
							$field;
				}
			}
		}
	} 
	$cache->{$self->{confid}} = $self;

	# lock these metadata fields against being modified again.
	foreach my $field ( @{$self->{fields}} )
	{
		$field->final;
	}

	return $self;
}


######################################################################
=pod

=item $metafield = $ds->get_field( $fieldname )

Return a MetaField object describing the asked for field
in this dataset, or undef if there is no such field.

=cut
######################################################################

sub get_field
{
	my( $self, $fieldname ) = @_;


	# magic fields which can be searched but do
	# not really exist.
	if( $fieldname eq $EPrints::Utils::FULLTEXT )
	{
		if( !defined $self->{fulltext_field} )
		{
			$self->{fulltext_field} = EPrints::MetaField->new( 
				dataset=>$self , 
				name=>$fieldname,
				multiple=>1,
				type=>"fulltext" );
			$self->{fulltext_field}->set_property( "multiple",1 );
			$self->{fulltext_field}->final;
		}
		return $self->{fulltext_field};
	}
	if( $fieldname =~ m/^_/ )
	{
		my $field = EPrints::MetaField->new( 
			dataset=>$self , 
			name=>$fieldname,
			type=>"longtext" );
		return $field;
	}

	my $value = $self->{field_index}->{$fieldname};
	if (!defined $value) {
		$self->{repository}->log( 
			"dataset ".$self->{id}." has no field: ".
			$fieldname );
		return undef;
	}
	return $self->{field_index}->{$fieldname};
}

######################################################################
=pod

=item $bool = $ds->has_field( $fieldname )

True if the dataset has a field of that name.

=cut
######################################################################

sub has_field
{
	my( $self, $fieldname ) = @_;

	# magic fields which can be searched but do
	# not really exist.
	return 1 if( $fieldname =~ m/^_/ );
	
	return defined $self->{field_index}->{$fieldname};
}

######################################################################
=pod

=item $ordertype = $ds->default_order

Return the id string of the default order for this dataset. 

For example "bytitle" for eprints.

=cut
######################################################################

sub default_order
{
	my( $self ) = @_;

	return $self->{default_order};
}

#
# string confid()
#
#  returns the id string to be used to identify this dataset in the 
#  config and phrases ( in a nutshell "Archive", "Buffer" and "Inbox"
#  all return "eprint" because they all (must) have identical structure.


######################################################################
=pod

=item $confid = $ds->confid

Return the string to use when getting configuration for this dataset.

archive, buffer, inbox and deletion all return "eprint" as they must
have the same configuration.

=cut
######################################################################

sub confid
{
	my( $self ) = @_;
	return $self->{confid};
}


######################################################################
=pod

=item $id = $ds->id

Return the id of this dataset.

=cut
######################################################################

sub id
{
	my( $self ) = @_;
	return $self->{id};
}


######################################################################
=pod

=item $n = $ds->count( $session )

Return the number of records in this dataset.

=cut
######################################################################

sub count
{
	my( $self, $session ) = @_;

	if( defined $self->get_filters )
	{
		my $searchexp = EPrints::Search->new(
			allow_blank => 1,
			dataset => $self,
			session => $session );
		my $list = $searchexp->perform_search;
		return $list->count;
	}

	return $session->get_database->count_table( $self->get_sql_table_name() );
}
 

######################################################################
=pod

=item $tablename = $ds->get_sql_table_name

Return the name of the main SQL Table containing this dataset.
the other SQL tables names are based on this name.

=cut
######################################################################

sub get_sql_table_name
{
	my( $self ) = @_;

	my $table = $INFO->{$self->{id}}->{sqlname};

	return $table if defined $table;

	EPrints::abort( "Can't get a SQL table name for dataset: ".$self->{id} );
}



######################################################################
=pod

=item $tablename = $ds->get_sql_index_table_name

Return the name of the SQL table which contains the free text indexing
information.

=cut
######################################################################

sub get_sql_index_table_name
{
	my( $self ) = @_;
	return $self->get_sql_table_name()."__"."index";
}

######################################################################
=pod

=item $tablename = $ds->get_sql_grep_table_name

Reutrn the name of the SQL table which contains the strings to
be used with LIKE in a final pass of a search.

=cut
######################################################################

sub get_sql_grep_table_name
{
	my( $self ) = @_;
	return $self->get_sql_table_name()."__"."index_grep";
}

######################################################################
=pod

=item $tablename = $ds->get_sql_rindex_table_name

Reutrn the name of the SQL table which contains the reverse text
indexing information. (Used for deleting freetext indexes when
removing a record).

=cut
######################################################################

sub get_sql_rindex_table_name
{
	my( $self ) = @_;
	return $self->get_sql_table_name()."__"."rindex";
}

######################################################################
=pod

=item $tablename = $ds->get_ordervalues_table_name( $langid )

Return the name of the SQL table containing values used for ordering
this dataset.

=cut
######################################################################

sub get_ordervalues_table_name
{
	my( $self,$langid ) = @_;
	return $self->get_sql_table_name()."__"."ordervalues_".$langid;
}


######################################################################
=pod

=item $tablename = $ds->get_sql_sub_table_name( $field )

Returns the name of the SQL table which contains the information
on the "multiple" field. $field is an EPrints::MetaField belonging
to this dataset.

=cut
######################################################################

sub get_sql_sub_table_name
{
	my( $self , $field ) = @_;
	return $self->get_sql_table_name()."_".$field->get_sql_name();
}


######################################################################
=pod

=item $fields = $ds->get_fields( [$split_id] )

Returns a list of the EPrints::Metafields belonging to this dataset.

If $split_id is set then fields with the has_id property are split into
id_part and main_part. This is useful for database functions.

=cut
######################################################################

sub get_fields
{
	my( $self, $split_id ) = @_;

	my @fields = ();
	if( $split_id )
	{
		# Split "id" fields into component parts
		my $field;
		foreach $field ( @{ $self->{fields} } )
		{
			if( $field->get_property( "hasid" ) )
			{
				push @fields,$field->get_id_field();
				push @fields,$field->get_main_field();
			}
			else
			{
				push @fields,$field;
			}
		}
	}
	else
	{
		@fields = @{ $self->{fields} };
	}
	return @fields;
}


######################################################################
=pod

=item $field = $ds->get_key_field

Return the EPrints::MetaField representing the primary key field.
Always the first field.

=cut
######################################################################

sub get_key_field
{
	my( $self ) = @_;
	return $self->{fields}->[0];
}


######################################################################
=pod

=item $obj = $ds->make_object( $session, $data )

Return an object of the class associated with this dataset, always
a subclass of EPrints::DataObj.

$data is a hash of values for fields of a record in this dataset.

Return $data if no class associated with this dataset.

=cut
######################################################################

sub make_object
{
	my( $self , $session , $data ) = @_;

	my $class = $self->get_object_class;

	# If this table dosn't have an associated class, just
	# return the data.	

	if( !defined $class ) 
	{
		return $data;
	}

	return $class->new_from_data( 
		$session,
		$data,
		$self );
}

######################################################################
=pod

=item $obj = $ds->create_object( $session, $data )

Create a new object in the given dataset. Return the new object.

Return undef if the object could not be created.

If $data describes sub-objects too then those will also be created.

=cut
######################################################################

sub create_object
{
	my( $self , $session , $data ) = @_;

	my $class = $self->get_object_class;

	return $class->create_from_data( $session, $data, $self );
}

######################################################################
=pod

=item $class = $ds->get_object_class;

Return the perl class to which objects in this dataset belong.

=cut
######################################################################

sub get_object_class
{
	my( $self, $session ) = @_;

	return $INFO->{$self->{id}}->{class};
}

######################################################################
=pod

=item $obj = $ds->get_object( $session, $id );

Return the object from this dataset with the given id, or undefined.

=cut
######################################################################

sub get_object
{
	my( $self, $session, $id ) = @_;

	my $class = $self->get_object_class;

	if( !defined $class )
	{
		$session->get_repository->log(
				"Can't get_object for dataset ".
				$self->{confid} );
		return undef;
	}

	return $class->new( $session, $id, $self );
}

######################################################################
=pod

=item $types = $ds->get_types

Return a reference to a list of all types of this dataset (eg. 
eprint record types or types of user)

=cut
######################################################################

sub get_types
{
	my( $self ) = @_;

	return $self->{type_order};
}


######################################################################
=pod

=item $foo = $ds->get_type_names( $session )

Returns a reference to a hash table which maps the id's of types given
by get_types to printable names in the language of the session (utf-8
encoded). 

=cut
######################################################################

sub get_type_names
{
	my( $self, $session ) = @_;
		
	my %names = ();
	foreach( keys %{$self->{types}} ) 
	{
		$names{$_} = $self->get_type_name( $session, $_ );
	}
	return( \%names );
}


######################################################################
=pod

=item $name = $ds->get_type_name( $session, $type )

Return a utf-8 string containing a human-readable name for the
specified type.

=cut
######################################################################

sub get_type_name
{
	my( $self, $session, $type ) = @_;

	if( $self->{confid} eq "language"  || $self->{confid} eq "arclanguage" )
	{
		if( $type eq "?" )
		{
			return $session->phrase( "lib/dataset:no_language" );
		}
		return EPrints::Utils::tree_to_utf8(
			$session->render_language_name( $type ) );
	}

        return $session->phrase( $self->confid()."_typename_".$type );
}


######################################################################
=pod

=item $xhtml = $ds->render_type_name( $session, $type )

Return a piece of XHTML describing the name of the given type in the
language of the session.

=cut
######################################################################

sub render_type_name
{
	my( $self, $session, $type ) = @_;

	if( $self->{confid} eq "language"  || $self->{confid} eq "arclanguage" )
	{
		return $session->make_text( $self->get_type_name( $session, $type ) );
	}
        return $session->html_phrase( $self->confid()."_typename_".$type );
}

######################################################################
=pod

=item $xhtml = $ds->render_name( $session )

Return a piece of XHTML describing this dataset, in the language of
the current session.

=cut
######################################################################

sub render_name($$)
{
	my( $self, $session ) = @_;

        return $session->html_phrase( "dataset_name_".$self->id() );
}


######################################################################
=pod

=item @fields = $ds->get_type_fields( $type, [$staff] )

Return a list of EPrints::MetaField's which may be edited by a user
on a record of the given type. Or by a editor/admin if $staff is
true.

=cut
######################################################################

sub get_type_fields
{
	my( $self, $type, $staff ) = @_;

	my $fields = $self->{($staff?"staff_":"")."types"}->{$type};
	if( !defined $fields )
	{
		$self->{repository}->log( "Unknown type in get_type_fields ($type)" );
		return ();
	}
	return @{$fields};
}



######################################################################
=pod

=item @fields = $ds->get_required_type_fields( $type )

Return an array of the EPrints::MetaField's which are required for
the given type.

=cut
######################################################################

sub get_required_type_fields
{
	my( $self, $type ) = @_;

	return @{$self->{typesreq}->{$type}};	
}



######################################################################
=pod

=item $boolean = $ds->is_valid_type( $type )

Returns true if the specified $type is indeed a type in this dataset.

=cut
######################################################################

sub is_valid_type
{
	my( $self, $type ) = @_;
	return( defined $self->{types}->{$type} );
}


######################################################################
=pod

=item $ds->map( $session, $fn, $info )

Maps the function $fn onto every record in this dataset. See 
Search for a full explanation.

=cut
######################################################################

sub map
{
	my( $self, $session, $fn, $info ) = @_;

	my $searchexp = EPrints::Search->new(
		allow_blank => 1,
		dataset => $self,
		session => $session );
	$searchexp->perform_search();
	$searchexp->map( $fn, $info );
	$searchexp->dispose();
}


######################################################################
=pod

=item $repository = $ds->get_repository

Returns the EPrints::Repository to which this dataset belongs.

=cut
######################################################################
sub get_archive { return $_[0]->get_repository; }

sub get_repository
{
	my( $self ) = @_;
	
	return $self->{repository};
}


######################################################################
=pod

=item $ds->reindex( $session )

Recommits all the items in this dataset. This could take a real long 
time on a large set of records.

Really should not be called reindex anymore as it doesn't.

=cut
######################################################################

sub reindex
{
	my( $self, $session ) = @_;

	my $fn = sub {
		my( $session, $dataset, $item ) = @_;
		if( $session->get_noise() >= 2 )
		{
			print STDERR "Reindexing item: ".$dataset->id()."/".$item->get_id()."\n";
		}
		$item->commit();
	};

	$self->map( $session, $fn );
}

######################################################################
=pod

=item @ids = EPrints::DataSet::get_dataset_ids( get_dataset_ids )

Return a list of all dataset ids.

=cut
######################################################################

sub get_dataset_ids
{
	return keys %{$INFO};
}


######################################################################
=pod

=item @ids = EPrints::DataSet::get_sql_dataset_ids

Return a list of all dataset ids of datasets which are directly mapped
into SQL (not counters or cache which work a bit differently).

=cut
######################################################################

sub get_sql_dataset_ids
{
	return( qw/ eprint user document subscription subject license history access / );
}

######################################################################
=pod

=item $n = $ds->count_indexes

Return the number of indexes required for the main SQL table of this
dataset. Used to check it's not over 32 (the current maximum allowed
by MySQL)

Assumes things either have 1 or 0 indexes which might not always
be true.

=cut
######################################################################

sub count_indexes
{
	my( $self ) = @_;

	my $n = 0;
	foreach my $field ( $self->get_fields( 1 ) )
	{
		next if( $field->get_property( "multiple" ) );
		next if( $field->get_property( "multilang" ) );
		next unless( defined $field->get_sql_index );
		$n++;
	}
	return $n;
}
		
######################################################################
=pod

=item @ids = $dataset->get_item_ids( $session )

Return a list of the id's of all items in this set.

=cut
######################################################################

sub get_item_ids
{
	my( $self, $session ) = @_;

	if( defined $self->get_filters )
	{
		my $searchexp = EPrints::Search->new(
			allow_blank => 1,
			dataset => $self,
			session => $session );
		my $list = $searchexp->perform_search;
		return $list->get_ids;
	}
	return $session->get_database->get_values( $self->get_key_field, $self );
}


######################################################################
=pod

=item $boolean = $ds->field_required_in_type( $field, $type )

Return true if the field is required by in the specified type. Nb.
If the field is required generally but not specicially for this field
then this function returns TRUE.

=cut
######################################################################

sub field_required_in_type
{
	my( $self, $field, $type ) = @_;

	if( $field->get_property( "required" ) eq "yes" )
	{
		return 1;
	}

	foreach( @{$self->{typesreq}->{$type}} )
	{
		if( $_->get_name eq $field->get_name )
		{
			return 1;
		}
	}

	return 0;
}

######################################################################
=pod

=item @fields = $ds->get_page_fields( $type, $page, $staff )

Return an array of fields in the order they appear on page id $page
of type $type.

=cut
######################################################################

sub get_page_fields
{
	my( $self, $type, $page, $staff ) = @_;

	my $v = ($staff?"staff_":"")."pages";
	my $l = $self->{$v}->{$type}->{$page};
	return @{$l};
}

######################################################################
=pod

=item @pages = $ds->get_type_pages( $type );

Return an array of page ids in the order they should be displayed.

=cut
######################################################################

sub get_type_pages
{
	my( $self, $type ) = @_;

	my $l = $self->{page_order}->{$type};

	return () unless( defined $l );

	return @{$l};
}


######################################################################
# 
# $field_id = $ds->get_dataset_id_field
# 
# If this is a virtual dataset, return the id of a field in the object
# metadata which should be set to the id of this dataset when the
# object is created.
#
# Otherwise return undef.
#
######################################################################

sub get_dataset_id_field
{
	my( $self ) = @_;

	my $f = $INFO->{$self->{id}}->{dataset_id_field};

	return $f;
}

######################################################################
# 
# @filters = $ds->get_filters
# 
# Return an array of filters that must always be applied to searches
# on this dataset. Used for inbox, archive etc.
#
######################################################################

sub get_filters
{
	my( $self ) = @_;

	my $f = $INFO->{$self->{id}}->{filters};

	return () unless defined $f;

	return @{$f};
}



######################################################################
1;
######################################################################
=pod

=back

=cut

