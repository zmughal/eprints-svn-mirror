######################################################################
#
# EPrints::DataObj::Shelf
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

B<EPrints::DataObj::Shelf> - Single shelf.

=head1 DESCRIPTION

A shelf is a sub class of EPrints::DataObj.

Each one belongs to one and only one user, although one user may own
multiple shelves.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  From DataObj.
#
######################################################################

package EPrints::DataObj::Shelf;

@ISA = ( 'EPrints::DataObj' );

use EPrints;

use strict;


######################################################################
=pod

=item $field_config = EPrints::DataObj::Shelf->get_system_field_info

Return an array describing the system metadata of the saved search.
dataset.

=cut
######################################################################

sub get_system_field_info
{
	my( $class ) = @_;

	return 
	( 
		{ name=>"shelfid", type=>"int", required=>1, import=>0, can_clone=>1, },

		{ name=>"rev_number", type=>"int", required=>1, can_clone=>0 },

		{ name=>"userid", type=>"itemref", datasetid=>"user", required=>1 },

		{ name=>"adminids", type=>"username", multiple=>1, input_cols => 20 },

		{ name=>"editorids", type=>"username", multiple =>1, input_cols => 20 },

		{ name=>"readerids", type=>"username", multiple =>1, input_cols => 20 },

		{ name=>"title", type=>"text" },

		{ name=>"description", type=>"longtext" },

		{ name=>"public", type=>"boolean", input_style=>"radio" },

                { name=>"items", type=>"itemref", datasetid=>"eprint", multiple=>1, required=>1 },

		{ name=>"datestamp", type=>"time", required=>0, import=>0,
			render_res=>"minute", render_style=>"short", can_clone=>0 },
		
		{ name=>"lastmod", type=>"time", required=>0, import=>0,
			render_res=>"minute", render_style=>"short", can_clone=>0 },
	

	);
}


######################################################################
=pod

=item $shelf = EPrints::DataObj::Shelf->new( $session, $id )

Return new Saved Search object, created by loading the Saved Search
with id $id from the database.

=cut
######################################################################

sub new
{
	my( $class, $session, $id ) = @_;

	return $session->get_database->get_single( 	
		$session->get_repository->get_dataset( "shelf" ),
		$id );
}

######################################################################
=pod

=item $shelf = EPrints::DataObj::Shelf->new_from_data( $session, $data )

Construct a new EPrints::DataObj::Shelf object based on the $data hash 
reference of metadata.

=cut
######################################################################

sub new_from_data
{
	my( $class, $session, $known ) = @_;

	return $class->SUPER::new_from_data(
			$session,
			$known,
			$session->get_repository->get_dataset( "shelf" ) );
}


######################################################################
# =pod
# 
# =item $shelf = EPrints::DataObj::Shelf->create( $session, $userid )
# 
# Create a new saved search. entry in the database, belonging to user
# with id $userid.
# 
# =cut
######################################################################

sub create
{
	my( $class, $session, $userid ) = @_;

	return EPrints::DataObj::Shelf->create_from_data( 
		$session, 
		{userid => $userid},
		$session->get_repository->get_dataset( "shelf" ) );
}

######################################################################
# =pod
#
# =item $dataobj = EPrints::DataObj->create_from_data( $session, $data, $dataset )
#
# Create a new object of this type in the database.
#
# $dataset is the dataset it will belong to.
#
# $data is the data structured as with new_from_data.
#
# =cut
######################################################################

sub create_from_data
{
        my( $class, $session, $data, $dataset ) = @_;

        my $new_shelf = $class->SUPER::create_from_data( $session, $data, $dataset );

        $session->get_database->counter_minimum( "shelfid", $new_shelf->get_id );

        return $new_shelf;
}

######################################################################
=pod

=item $defaults = EPrints::DataObj::Shelf->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=cut
######################################################################

sub get_defaults
{
	my( $class, $session, $data ) = @_;

	my $id = $session->get_database->counter_next( "shelfid" );

	$data->{shelfid} = $id;
	$data->{rev_number} = 1;
	$data->{public} = "FALSE";

	if (not defined $data->{userid})
	{
		$data->{userid} = $session->current_user->get_id;
	}

	#administrator gets defaulted to creators
	$data->{adminids} = [$data->{userid}];


#	$session->get_repository->call(
#		"set_shelf_defaults",
#		$data,
#		$session );

	return $data;
}	


######################################################################
=pod

=item $success = $shelf->remove

Remove the saved search.

=cut
######################################################################

sub get_user
{
	my( $self ) = @_;

	return EPrints::User->new( 
		$self->{session},
		$self->get_value( "userid" ) );
}

sub has_owner
{
	my( $self, $possible_owner ) = @_;

	if( $possible_owner->get_value( "userid" ) == $self->get_value( "userid" ) )
	{
		return 1;
	}

	return 0;
}

sub has_admin
{
	my( $self, $possible_admin ) = @_;

	my $possible_adminid = $possible_admin->get_value('userid');

	foreach my $adminid (@{$self->get_value('adminids')})
	{
		return 1 if $possible_adminid == $adminid;
	}

	if ($self->{session}->get_repository->can_call('is_shelf_administrator'))
	{
		return $self->{session}->get_repository->call('is_shelf_administrator', $self, $possible_admin);
	}

	return 0;
}

sub has_editor
{
	my( $self, $possible_editor ) = @_;

	my $possible_editorid = $possible_editor->get_value('userid');

	foreach my $editorid (@{$self->get_value('editorids')})
	{
		return 1 if $possible_editorid == $editorid;
	}

	return $self->has_admin($possible_editor); #admins are always editors 
}

sub has_reader
{
	my( $self, $possible_reader ) = @_;

	my $possible_readerid = $possible_reader->get_value('userid');

	foreach my $readerid (@{$self->{readerids}})
	{
		return 1 if $possible_readerid == $readerid;
	}

	return $self->has_editor($possible_reader); #editors are always readers
}

sub get_url
{
	my( $self , $staff ) = @_;

	return undef if( $self->get_value("public") ne "TRUE" );

	return $self->{session}->get_repository->get_conf( "http_cgiurl" )."/shelf?shelfid=".$self->get_id;
}

sub get_item_ids
{
	my ( $self ) = @_;

	return $self->get_value('items');
}

sub remove_items
{
	my ($self, @items_to_delete) = @_;

	my $items = $self->get_value('items');

	my $items_to_delete;
	foreach my $item_to_delete (@items_to_delete)
	{
		$items_to_delete->{$item_to_delete} = 1;
	}

	my $new_items = [];
	foreach my $item (@{$items})
	{
		next if $items_to_delete->{$item};
		push @{$new_items}, $item;
	} 

	$self->set_value('items', $new_items);
	$self->commit;
}

sub get_items
{
	my ($self) = @_;

	my $session = $self->{session};

        my $ds = $session->get_repository->get_dataset( 'eprint' );

	my $items = [];

	return $items unless $self->is_set('items');

	foreach my $eprintid (@{$self->get_value('items')})
	{
		push @{$items},  $ds->get_object( $session, $eprintid );
	}

        return $items;
}

######################################################################
=pod

=item $success = $saved_search->commit( [$force] )

Write this object to the database.

If $force isn't true then it only actually modifies the database
if one or more fields have been changed.

=cut
######################################################################

sub commit
{
	my( $self, $force ) = @_;

	if( !$self->is_set( "datestamp" ) )
	{
		$self->set_value(
				"datestamp" ,
				EPrints::Time::get_iso_timestamp() );
	}

	if( !defined $self->{changed} || scalar( keys %{$self->{changed}} ) == 0 )
	{
		# don't do anything if there isn't anything to do
		return( 1 ) unless $force;
	}
	if( $self->{non_volatile_change} )
	{
		$self->set_value( "rev_number", ($self->get_value( "rev_number" )||0) + 1 );
		$self->set_value ("lastmod", EPrints::Time::get_iso_timestamp ());
	}

	my $shelf_ds = $self->{session}->get_repository->get_dataset( "shelf" );
	$self->tidy;
	my $success = $self->{session}->get_database->update(
		$shelf_ds,
		$self->{data} );

	$self->queue_changes;

	return( $success );
}


######################################################################
=pod

=item $success = $shelf->remove

Remove this shelf from the database. 

=cut
######################################################################

sub remove
{
        my( $self ) = @_;

        my $success = 1;

        # remove user record
        my $shelf_ds = $self->{session}->get_repository->get_dataset( "shelf" );
        $success = $success && $self->{session}->get_database->remove(
                $shelf_ds,
                $self->get_value( "shelfid" ) );

        return( $success );
}



sub render_export_bar
{
        my ($self) = @_;

	my $shelfid = $self->get_id;
	my $session = $self->{session};

	my $user = $session->current_user;

        my %opts = (
                        type=>"Export",
                        can_accept=>"list/eprint",
                        is_visible=>"all",
        );

	
	if (defined $user)
	{
		my $usertype = $user->get_value('usertype');
		if ($usertype eq 'admin' or $usertype eq 'editor')
		{
			$opts{is_visible} = 'staff';
		}
	}

        my @plugins = $session->plugin_list( %opts );

        if( scalar @plugins == 0 )
        {
                return $session->make_doc_fragment;
        }

        my $export_url = $session->get_repository->get_conf( "perl_url" )."/exportshelf";

        my $feeds = $session->make_doc_fragment;
        my $tools = $session->make_doc_fragment;
        my $options = {};
        foreach my $plugin_id ( @plugins )
        {
                $plugin_id =~ m/^[^:]+::(.*)$/;
                my $id = $1;
                my $plugin = $session->plugin( $plugin_id );
                my $dom_name = $plugin->render_name;
                if( $plugin->is_feed || $plugin->is_tool )
                {
                        my $type = "feed";
                        $type = "tool" if( $plugin->is_tool );
                        my $span = $session->make_element( "span", class=>"ep_search_$type" );

                        my $fn = 'shelf_' . $shelfid; #use title of shelf?
                        my $url = $export_url."/".$shelfid."/$id/$fn".$plugin->param("suffix");

                        my $a1 = $session->render_link( $url );
                        my $icon = $session->make_element( "img", src=>$plugin->icon_url(), alt=>"[$type]", border=>0 );
                        $a1->appendChild( $icon );
                        my $a2 = $session->render_link( $url );
                        $a2->appendChild( $dom_name );
                        $span->appendChild( $a1 );
                        $span->appendChild( $session->make_text( " " ) );
                        $span->appendChild( $a2 );

                        if( $type eq "tool" )
                        {
                                $tools->appendChild( $session->make_text( " " ) );
                                $tools->appendChild( $span );
                        }
                        if( $type eq "feed" )
                        {
                                $feeds->appendChild( $session->make_text( " " ) );
                                $feeds->appendChild( $span );
                        }
                }
                else
                {
                        my $option = $session->make_element( "option", value=>$id );
                        $option->appendChild( $dom_name );
                        $options->{EPrints::XML::to_string($dom_name, undef, 1 )} = $option;
                }
        }

        my $select = $session->make_element( "select", name=>"format" );
        foreach my $optname ( sort keys %{$options} )
        {
                $select->appendChild( $options->{$optname} );
        }
        my $button = $session->make_doc_fragment;
        $button->appendChild( $session->render_button(
                        name=>"_action_export_redir",
                        value=>$session->phrase( "lib/searchexpression:export_button" ) ) );
        $button->appendChild(
                $session->render_hidden_field( "shelfid", $shelfid ) );

        my $form = $session->render_form( "GET", $export_url );
        $form->appendChild( $session->html_phrase( "Update/Views:export_section",
                                        feeds => $feeds,
                                        tools => $tools,
                                        menu => $select,
                                        button => $button ));

        return $form;
}


sub get_control_url
{
        my( $self ) = @_;

        return $self->{session}->get_repository->get_conf( "http_cgiurl" )."/users/home?screen=Shelf::View&shelfid=".$self->get_value( "userid" );
}


=pod

=back

=cut

1;
