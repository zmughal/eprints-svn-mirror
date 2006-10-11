######################################################################
#
# EPrints::UserPage
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

B<EPrints::UserPage> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{foo}
#     undefined
#
######################################################################

######################################################################
#
#  View User Record
#
######################################################################
#
#  __LICENSE__
#
######################################################################

package EPrints::UserPage;

use EPrints::Session;
use EPrints::SearchExpression;
use EPrints::Utils;
use EPrints::User;


######################################################################
=pod

=item EPrints::UserPage::user_from_param()

undocumented

=cut
######################################################################

sub user_from_param
{

	my $username = &SESSION->param( "username" );
	my $userid = &SESSION->param( "userid" );

	if( !EPrints::Utils::is_set( $username ) && !EPrints::Utils::is_set( $userid ) )
	{
		&SESSION->render_error( &SESSION->html_phrase( 
				"lib/userpage:no_user" ) );
		return;
	}
	my $user;
	if( EPrints::Utils::is_set( $userid ) )
	{
		$user = EPrints::User->new( $userid );
	}
	else
	{
		$user = EPrints::User::user_with_username( $username );
	}


	if( !defined $user )
	{
		&SESSION->render_error( &SESSION->html_phrase( 
				"lib/userpage:unknown_user" ) );
		return;
	}

	return $user;
}


######################################################################
=pod

=item EPrints::UserPage::process( $staff )

undocumented

=cut
######################################################################

sub process
{
	my( $staff ) = trim_params(@_);

	my $user = EPrints::UserPage::user_from_param();
	return unless( defined $user );
	
	$userid = $user->get_value( "userid" );

	my( $page );

	$page = &SESSION->make_doc_fragment();

	my( $userdesc, $title );
	if( $staff )
	{
		( $userdesc, $title ) = $user->render_full();	
	}
	else
	{
		( $userdesc, $title ) = $user->render();	
	}
	$page->appendChild( $userdesc );

	$page->appendChild( &SESSION->render_ruler() );

	my $arc_ds = &ARCHIVE->get_dataset( "archive" );
	my $searchexp = new EPrints::SearchExpression( dataset => $arc_ds );

	$searchexp->add_field(
		$arc_ds->get_field( "userid" ),
		$userid );

	$searchexp->perform_search();
	my $count = $searchexp->count();
	$searchexp->dispose();

	my $url;
	if( $staff )
	{
		$url = &ARCHIVE->get_conf( "perl_url" )."/users/search/archive?userid=$userid&_action_search=1";
	}
	else
	{
		$url = &ARCHIVE->get_conf( "perl_url" )."/user_eprints?userid=$userid";
	}
	my $link = &SESSION->render_link( $url );	

	$page->appendChild( &SESSION->html_phrase( 
				"lib/userpage:number_of_records",
				n=>&SESSION->make_text( $count ),
				link=>$link ) );

	if( $staff && &SESSION->current_user()->has_priv( "edit-user" ) )
	{
		$page->appendChild( &SESSION->render_input_form(
			# no input fields so no need for a default
			buttons=>{
				_order => [ "edit", "delete" ],
				edit=>&SESSION->phrase( "lib/userpage:action_edit" ),
				delete=>&SESSION->phrase( "lib/userpage:action_delete" )
			},
			hidden_fields=>{
				userid=>$user->get_value( "userid" )
			},
			dest=>"edit_user"
		) );			
	}	
	

	&SESSION->build_page(
		&SESSION->html_phrase( "lib/userpage:title",
				name=>$user->render_description() ), 
		$page,
		"userpage" );
	&SESSION->send_page();
}


1;

######################################################################
=pod

=back

=cut

