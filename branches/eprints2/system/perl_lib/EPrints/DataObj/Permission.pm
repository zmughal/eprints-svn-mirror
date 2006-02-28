######################################################################
#
# EPrints::DataObj::Permission
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

B<EPrints::DataObj::Permission> - Class and methods relating to the permission tree.

=head1 DESCRIPTION

This class represents a single node in the permission tree. It also
contains a number of methods for handling the entire tree.

EPrints::DataObj::Permission is a subclass of EPrints::DataObj

=over 4

=cut

package EPrints::DataObj::Permission;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;

# Root permission specifier
$EPrints::DataObj::Permission::root_permission = "ROOT";

######################################################################
=pod

=item $thing = EPrints::DataObj::Permission->get_system_field_info

Return an array describing the system metadata of the Permission dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"permissionid", type=>"text", required=>1 },

		{ name=>"name", type=>"text", required=>1, multilang=>1 },

		{ name=>"roleid", type=>"text", required=>0, multiple=>1 },

		{ name=>"groupid", type=>"text", required=>0, multiple=>1 },

	);
}



######################################################################
=pod

=item $permission = EPrints::DataObj::Permission->new( $session, $permissionid )

Create a new permission object given the id of the permission. The values
for the permission are loaded from the database.

=cut
######################################################################

sub new
{
	my( $class, $session, $permissionid ) = @_;

	if( $permissionid eq $EPrints::DataObj::Permission::root_permission )
	{
		my $data = {
			permissionid => $EPrints::DataObj::Permission::root_permission,
			name => {},
			parents => [],
			ancestors => [ $EPrints::DataObj::Permission::root_permission ],
			depositable => "FALSE" 
		};
		my $langid;
		foreach $langid ( @{$session->get_repository->get_conf( "languages" )} )
		{
			$data->{name}->{$langid} = EPrints::XML::to_string( $session->get_repository->get_language( $langid )->phrase( "lib/permission:top_level", {}, $session ) );
		}

		return EPrints::DataObj::Permission->new_from_data( $session, $data );
	}

	return $session->get_db()->get_single( 
			$session->get_repository->get_dataset( "permission" ), 
			$permissionid );

}



######################################################################
=pod

=item $permission = EPrints::DataObj::Permission->new_from_data( $session, $data )

Construct a new permission object from a hash reference containing
the relevant fields. Generally this method is only used to construct
new Permissions coming out of the database.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $data ) = @_;

	my $self = {};
	
	$self->{data} = $data;
	$self->{dataset} = $session->get_repository->get_dataset( "permission" ); 
	$self->{session} = $session;
	bless $self, $class;

	return( $self );
}



######################################################################
=pod

=item $success = $permission->commit( [$force] )

Commit this permission to the database, but only if any fields have 
changed since we loaded it.

If $force is set then always commit, even if there appear to be no
changes.

=cut
######################################################################

sub commit 
{
	my( $self, $force ) = @_;

	my @ancestors = $self->_get_ancestors();
	$self->set_value( "ancestors", \@ancestors );

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}
	$self->set_value( "rev_number", ($self->get_value( "rev_number" )||0) + 1 );	

	my $rv = $self->{session}->get_db()->update(
			$self->{dataset},
			$self->{data} );
	
	$self->queue_changes;

	# Need to update all children in case ancesors have changed.
	# This is pretty slow esp. For a top level permission, but permission
	# changes will be rare and only done by admin, so mnya.
	my $child;
	foreach $child ( $self->children() )
	{
		$rv = $rv && $child->commit();
	}
	return $rv;
}


######################################################################
=pod

=item $success = $permission->remove

Remove this permission from the database.

=cut
######################################################################

sub remove
{
	my( $self ) = @_;
	
	if( scalar $self->children() != 0 )
	{
		return( 0 );
	}

	#cjg Should we unlink all eprints linked to this permission from
	# this permission?

	return $self->{session}->get_db()->remove(
		$self->{dataset},
		$self->{data}->{permissionid} );
}


######################################################################
=pod

=item EPrints::DataObj::Permission::remove_all( $session )

Static function.

Remove all permissions from the database. Use with care!

=cut
######################################################################

sub remove_all
{
	my( $session ) = @_;

	my $ds = $session->get_repository->get_dataset( "permission" );
	my @permissions = $session->get_db()->get_all( $ds );
	foreach( @permissions )
	{
		my $id = $_->get_value( "permissionid" );
		$session->get_db()->remove( $ds, $id );
	}
	return;
}

	
######################################################################
=pod

=item $permission = EPrints::DataObj::Permission::create( $session, $id, $name, $parents, $depositable )

Creates a new permission in the database. $id is the ID of the permission,
$name is a multilang data structure with the name of the permission in
one or more languages. eg. { en=>"Trousers", en-us=>"Pants}. $parents
is a reference to an array containing the ID's of one or more other
permissions (don't make loops!). If $depositable is true then eprints may
belong to this permission.

=cut
######################################################################

sub create
{
	my( $session, $id, $name, $parents, $depositable ) = @_;

	my $actual_parents = $parents;
	$actual_parents = [ $EPrints::DataObj::Permission::root_permission ] if( !defined $parents );

	my $data = 
		{ "permissionid"=>$id,
		  "name"=>$name,
		  "parents"=>$actual_parents,
		  "ancestors"=>[],
		  "depositable"=>($depositable ? "TRUE" : "FALSE" ) };

	return EPrints::User->create_from_data( 
		$session, 
		$data,
		$session->get_repository->get_dataset( "permission" ) );
}

######################################################################
=pod

=item $dataobj = EPrints::DataObj::Permission->create_from_data( $session, $data, $dataset )

Returns undef if a bad (or no) permissionid is specified.

Otherwise calls the parent method in EPrints::DataObj.

=cut
######################################################################

sub create_from_data
{
	my( $class, $session, $data, $dataset ) = @_;
                           
	my $id = $data->{permissionid};                                                                                       
	unless( valid_id( $id ) )
	{
		EPrints::Config::abort( <<END );
Error. Can't create new permission. 
The value '$id' is not a valid permission identifier.
Permission id's may not contain whitespace.
END
	}

	my $permission = $class->SUPER::create_from_data( $session, $data, $dataset );

	return unless( defined $permission );
	
	# regenerate ancestors field
	$permission->commit;

	return $permission;
}

######################################################################
# 
# $defaults = EPrints::DataObj::Subscription->get_defaults( $session, $data )
#
# Return default values for this object based on the starting data.
# 
######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;

	$data->{"rev_number"} = 1;

	return $data;
}

######################################################################
# 
# @permission_ids = $permission->_get_ancestors
#
# Get the ancestors of a given permission.
#
######################################################################

sub _get_ancestors
{
	my( $self ) = @_;

	my %ancestors;
	$ancestors{$self->{data}->{permissionid}} = 1;

	foreach my $parent ( $self->get_parents() )
	{
		foreach( $parent->_get_ancestors() )
		{
			$ancestors{$_} = 1;
		}
	}

	return keys %ancestors;
}


######################################################################
=pod

=item $child_permission = $permission->create_child( $id, $name, $depositable )

Similar to EPrints::DataObj::Permission::create, but this creates the new permission
as a child of the current permission.

=cut
######################################################################

sub create_child
{
	my( $self, $id, $name, $depositable ) = @_;
	
	return( EPrints::DataObj::Permission::create( $self->{session},
	                                  $id,
	                                  $name,
	                                  $self->{permissionid},
	                                  $depositable ) );
}


######################################################################
=pod

=item @children = $permission->children

Return a list of EPrints::DataObj::Permission objects which are direct children
of the current permission.

=cut
######################################################################

sub children #cjg should be get_children()
{
	my( $self ) = @_;

	my $searchexp = EPrints::Search->new(
		session=>$self->{session},
		dataset=>$self->{dataset},
		custom_order=>"name" );

	$searchexp->add_field(
		$self->{dataset}->get_field( "parents" ),
		$self->get_value( "permissionid" ) );

	my $searchid = $searchexp->perform_search();
	my @children = $searchexp->get_records();
	$searchexp->dispose();

	return( @children );
}




######################################################################
=pod

=item @parents = $permission->get_parents

Return a list of EPrints::DataObj::Permission objects which are direct parents
of the current permission.

=cut
######################################################################

sub get_parents
{
	my( $self ) = @_;

	my @parents = ();
	foreach( @{$self->{data}->{parents}} )
	{
		push @parents, new EPrints::DataObj::Permission( $self->{session}, $_ );
	}
	return( @parents );
}


######################################################################
=pod

=item $boolean = $permission->can_post( [$user] )

Determines whether the given user can post in this permission.

Currently there is no way to configure permissions for certain users,
so this just returns the true or false depending on the "depositable"
flag.

=cut
######################################################################

sub can_post
{
	my( $self, $user ) = @_;

	# Depends on the permission	
	return( $self->{data}->{depositable} eq "TRUE" ? 1 : 0 );
}



######################################################################
=pod

=item $xhtml = $permission->render_with_path( $session, $topsubjid )

Return the name of this permission including it's path from $topsubjid.

$topsubjid must be an ancestor of this permission.

eg. 

Library of Congress > B Somthing > BC Somthing more Detailed

=cut
######################################################################

sub render_with_path
{
	my( $self, $session, $topsubjid ) = @_;

	my @paths = $self->get_paths( $session, $topsubjid );

	my $v = $session->make_doc_fragment();

	my $first = 1;
	foreach( @paths )
	{
		if( $first )
		{
			$first = 0;	
		}	
		else
		{
			$v->appendChild( $session->html_phrase( 
				"lib/metafield:join_permission" ) );
			# nb. using one from metafield!
		}
		my $first = 1;
		foreach( @{$_} )
		{
			if( !$first )
			{
				$v->appendChild( $session->html_phrase( 
					"lib/metafield:join_permission_parts" ) );
			}
			$first = 0;
			$v->appendChild( $_->render_description() );
		}
	}
	return $v;
}


######################################################################
=pod

=item @paths = $permission->get_paths( $session, $topsubjid )

This function returns all the paths from this permission back up to the
specified top permission.

@paths is an array of array references. Each of the inner arrays
is a list of permission id's describing a path down the tree from
$topsubjid to $session.

=cut
######################################################################

sub get_paths
{
	my( $self, $session, $topsubjid ) = @_;

	if( $self->get_value( "permissionid" ) eq $topsubjid )
	{
		# empty list, for the top level we care about
		return ([]);
	}
	if( $self->get_value( "permissionid" ) eq $EPrints::DataObj::Permission::root_permission )
	{
		return ([]);
	}
	my( @paths ) = ();
	foreach( @{$self->{data}->{parents}} )
	{
		my $subj = new EPrints::DataObj::Permission( $session, $_ );
		push @paths, $subj->get_paths( $session, $topsubjid );
	}
	foreach( @paths )
	{
		push @{$_}, $self;
	}
	return @paths;
}


######################################################################
#
# ( $tags, $labels ) = get_postable( $session, $user )
#
#  Returns a list of the permissions that can be posted to by $user. They
#  are returned in a tuple, the first element being a reference to an
#  array of tags (for the ordering) and the second being a reference
#  to the hash mapping tags to full names. [STATIC]
#
######################################################################


######################################################################
=pod

=item $permission_pairs = $permission->get_permissions ( [$postable_only], [$show_top_level], [$nes_tids], [$no_nest_label] )

Return a reference to an array. Each item in the array is a two 
element list. 

The first element in the list is an indenifier string. 

The second element is a utf-8 string describing the permission (in the 
current language), including all the items above it in the tree, but
only as high as this permission.

The permissions which are returned are this item and all its children, 
and childrens children etc. The order is it returns 
this permission, then the first child of this permission, then children of 
that (recursively), then the second child of this permission etc.

If $postable_only is true then filter the results to only contain 
permissions which have the "depositable" flag set to true.

If $show_top_level is not true then the pair representing the current
permission is not included at the start of the list.

If $nest_ids is true then each then the ids retured are nested so
that the ids of the children of this permission are prefixed with this 
permissions id and a colon, and their children are prefixed by their 
nested id and a colon. eg. L:LC:LC003 rather than just "LC003"

if $no_nest_label is true then the permission label only contains the
name of the permission, not the higher level ones.

A default result from this method would look something like this:

  [
    [ "D", "History" ],
    [ "D1", "History: History (General)" ],
    [ "D111", "History: History (General): Medieval History" ]
 ]

=cut
######################################################################

sub get_permissions 
{
	my( $self, $postableonly, $showtoplevel, $nestids, $nonestlabel ) = @_; 

#cjg optimisation to not bother getting labels?
	$postableonly = 0 unless defined $postableonly;
	$showtoplevel = 1 unless defined $showtoplevel;
	$nestids = 0 unless defined $nestids;
	$nonestlabel = 0 unless defined $nonestlabel;
	my( $permissionmap, $rmap ) = EPrints::DataObj::Permission::get_all( $self->{session} );
	return $self->_get_permissions2( $postableonly, !$showtoplevel, $nestids, $permissionmap, $rmap, "", !$nonestlabel );
}

######################################################################
# 
# $permissions = $permission->_get_permissions2( $postableonly, $hidenode, $nestids, $permissionmap, $rmap, $prefix )
#
# Recursive function used by get_permissions.
#
######################################################################

sub _get_permissions2
{
	my( $self, $postableonly, $hidenode, $nestids, $permissionmap, $rmap, $prefix, $cascadelabel ) = @_; 

	my $postable = ($self->get_value( "depositable" ) eq "TRUE" ? 1 : 0 );
	my $id = $self->get_value( "permissionid" );

	my $desc = $self->render_description;
	my $label = EPrints::Utils::tree_to_utf8( $desc );
	EPrints::XML::dispose( $desc );

	my $subpairs = [];
	if( (!$postableonly || $postable) && (!$hidenode) )
	{
		if( $prefix ne "" ) { $prefix .= ":"; }
		$prefix.=$id;
		push @{$subpairs},[ ($nestids?$prefix:$id), $label ];
	}
	$prefix = "" if( $hidenode );
	foreach my $kid ( @{$rmap->{$id}} )# cjg sort on labels?
	{
		my $kidmap = $kid->_get_permissions2( 
				$postableonly, 0, $nestids, $permissionmap, $rmap, $prefix, $cascadelabel );
		if( !$cascadelabel )
		{
			push @{$subpairs}, @{$kidmap};
			next;
		}
		foreach my $pair ( @{$kidmap} )
		{
			my $label = ($hidenode?"":$label.": ").$pair->[1];
			push @{$subpairs}, [ $pair->[0], $label ];
		}
	}

	return $subpairs;
}

######################################################################
=pod

=item $label = EPrints::DataObj::Permission::permission_label( $session, $permission_id )

Return the full label of a permission, including parents. Returns
undef if the permission id is invalid.

The returned string is encoded in utf8.

=cut
######################################################################

sub permission_label
{
	my( $session, $permission_tag ) = @_;
	
	my $label = "";
	my $tag = $permission_tag;

	while( $tag ne $EPrints::DataObj::Permission::root_permission )
	{
		my $ds = $session->get_repository->get_dataset();
		my $data = $session->{database}->get_single( $ds, $tag );
		
		# If we can't find it, the tag must be invalid.
		if( !defined $data )
		{
			return( undef );
		}

		$tag = $data->{parent};

		if( $label eq "" )
		{
			$label = $data->{name};
		}
		else
		{
			#cjg lang ": "
			$label = $data->{name} . ": " . $label;
		}
	}
	
	return( $label );
}


# cjg CACHE this per, er, session?
# commiting a permission should erase the cache

######################################################################
=pod

=item ( $permission_map, $reverse_map ) = EPrints::DataObj::Permission::get_all( $session )

Get all the permissions for the current archvive of $session.

$permission_map is a reference to a hash. The keys of the hash are
the id's of the permissions. The values of the hash are the 
EPrint::Permission object relating to that id.

$reverse_map is a reference to a hash. Each key is the id of a
permission. Each value is a reference to an array. The array contains
a EPrints::DataObj::Permission objects, one for each child of the permission 
with the id. The array is sorted by the labels for the permissions,
in the current language.

=cut
######################################################################

sub get_all
{
	my( $session ) = @_;
	
	# Retrieve all of the permissions
	my @permissions = $session->get_db()->get_all( 
		$session->get_repository->get_dataset( "permission" ) );

	return( undef ) if( scalar @permissions == 0 );

	my( %permissionmap );
	my( %rmap );
	my $permission;
	foreach $permission (@permissions)
	{
		$permissionmap{$permission->get_value("permissionid")} = $permission;
		# iffy non oo bit here.
		# guess it's ok within the same class... (maybe)
		# works fine, just a bit naughty
		foreach( @{$permission->{data}->{parents}} )
		{
			$rmap{$_} = [] if( !defined $rmap{$_} );
			push @{$rmap{$_}}, $permission;
		}
	}
	my $namefield = $session->get_repository->get_dataset(
		"permission" )->get_field( "name" );
	foreach( keys %rmap )
	{
		#cjg note the OO busting speedup hack.
		@{$rmap{$_}} = sort {   
my $av = $namefield->most_local( $session, $a->{data}->{name} );
my $bv = $namefield->most_local( $session, $b->{data}->{name} );
$av = "" unless defined $av;
$bv = "" unless defined $bv;
$av cmp $bv;
			} @{$rmap{$_}};
	}
	
	return( \%permissionmap, \%rmap );
}






######################################################################
#
# @eprints  = $permission->posted_eprints( $dataset )
#
# Deprecated. This method is no longer used by eprints, and may be 
# removed in a later release.
# 
# Return all the eprints which are in this permission (or below it in
# the tree, its children etc.) It searches all fields of type permission.
# 
# $dataset is the dataset to return eprints from.
# 
######################################################################

sub posted_eprints
{
	my( $self, $dataset ) = @_;

	my $searchexp = new EPrints::Search(
		session => $self->{session},
		dataset => $dataset,
		satisfy_all => 0 );

	my $n = 0;
	my $field;
	foreach $field ( $dataset->get_fields() )
	{
		next unless( $field->is_type( "permission" ) );
		$n += 1;
		$searchexp->add_field(
			$field,
			$self->get_value( "permissionid" ) );
	}

	if( $n == 0 )
	{
		# no actual permission fields
		return();
	}

	my $searchid = $searchexp->perform_search;
	my @data = $searchexp->get_records;
	$searchexp->dispose();

	return @data;
}

######################################################################
=pod

=item $count = $permission->count_eprints( $dataset )

Return the number of eprints in the dataset which are in this permission
or one of its decendants. Search all fields of type permission.

=cut
######################################################################

sub count_eprints
{
	my( $self, $dataset ) = @_;

	# Create a search expression
	my $searchexp = new EPrints::Search(
		satisfy_all => 0, 
		session => $self->{session},
		dataset => $dataset );

	my $n = 0;
	my $field;
	foreach $field ( $dataset->get_fields() )
	{
		next unless( $field->is_type( "permission" ) );
		$n += 1;
		$searchexp->add_field(
			$field,
			$self->get_value( "permissionid" ) );
	}

	if( $n == 0 )
	{
		# no actual permission fields
		return( 0 );
	}

	my $searchid = $searchexp->perform_search;
	my $count = $searchexp->count;
	$searchexp->dispose();

	return $count;

}

######################################################################
=pod

=item $boolean = EPrints::DataObj::Permission::valid_id( $id )

Return true if the string is an acceptable identifier for a permission.

This does not check all possible illegal values, yet.

=cut
######################################################################

sub valid_id
{
	my( $id ) = @_;

	return 0 if( m/\s/ ); # no whitespace

	return 1;
}


# Permissions don't have a URL.
#
# sub get_url
# {
# }

# Permissions don't have a type.
#
# sub get_type
# {
# }

#deprecated

######################################################################
=pod

=item $subj->render()

undocumented

=cut
######################################################################

sub render
{
	EPrints::abort( "permissions can't be rendered. Use render_description instead." ); 
}

1;

######################################################################
=pod

=back

=cut

