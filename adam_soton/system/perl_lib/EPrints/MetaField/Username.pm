######################################################################
#
# EPrints::MetaField::Username;
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

B<EPrints::MetaField::Username> - Reference to an object with an "int" type of ID field.

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Username;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Text );
}

use EPrints::MetaField::Text;

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;

	$defaults{text_index} = 0;

	$defaults{fromform} = 'EPrints::MetaField::Username::fromform';
	$defaults{toform} = 'EPrints::MetaField::Username::toform';

	return %defaults;
}

sub get_basic_input_elements
{
	my( $self, $session, $value, $basename, $staff ) = @_;

	my $ex = $self->SUPER::get_basic_input_elements( $session, $value, $basename, $staff );

	my $desc = $self->render_single_value( $session, $value );

	push @{$ex->[0]}, {el=>$desc, style=>"padding: 0 0.5em 0 0.5em;"};

	return $ex;
}

sub render_single_value
{
	my( $self, $session, $value ) = @_;

	if( !defined $value )
	{
		return $session->make_doc_fragment;
	}

	my $object = EPrints::DataObj::User::user_with_username( $session, $value );

	if( defined $object )
	{
		return $object->render_citation;
	}

	my $ds = $session->get_repository->get_dataset( 'user' );

	return $session->html_phrase( 
		"lib/metafield/username:not_found",
			id=>$session->make_text($value),
			objtype=>$session->html_phrase(
		"general:dataset_object_".$ds->confid));
}

sub get_user
{
	my( $self, $session, $value ) = @_;

	return EPrints::DataObj::User->new( $session, $value )
}


sub get_input_elements
{   
	my( $self, $session, $value, $staff, $obj, $basename ) = @_;

	my $input = $self->SUPER::get_input_elements( $session, $value, $staff, $obj, $basename );

	my $buttons = $session->make_doc_fragment;
	$buttons->appendChild( 
		$session->render_internal_buttons( 
			$self->{name}."_null" => $session->phrase(
				"lib/metafield/username:lookup" )));

	push @{ $input->[0] }, {el=>$buttons};

	return $input;
}


sub fromform
{
	my ( $value, $session, $object, $basename ) = @_;

	if (ref $value eq 'ARRAY')
	{
		foreach my $username (@{$value})
		{
			$username = EPrints::MetaField::Username::convert_from_form($session, $username);
		}
	}
	else
	{
		$value = EPrints::MetaField::Username::convert_from_form($session, $value);
	}

	return $value;
}

sub convert_from_form
{
	my($session, $value ) = @_;

	return undef unless defined $value;

	my $user = EPrints::DataObj::User::user_with_username( $session, $value );

	return $user->get_id if defined $user;
	return '@' . $value; #error code to store
}

sub toform
{
	my ($value, $session) = @_;

	if (ref $value eq 'ARRAY')
	{
		foreach my $userid (@{$value})
		{
			$userid = EPrints::MetaField::Username::convert_to_form($session, $userid);
		}
	}
	else
	{
		$value = EPrints::MetaField::Username::convert_to_form($session, $value);
	}

	return $value;
}

sub convert_to_form
{
	my( $session, $userid ) = @_;

	if ($userid =~ m/^@/)
	{
		return $'; #stored bad username
	}

	my $user = EPrints::DataObj::User->new( $session, $userid );

	return $user->get_value('username') if defined $user;

	return "User with user id $userid not found";
}

######################################################################
1;
