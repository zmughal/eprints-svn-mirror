######################################################################
#
#  Site Data Validation Configuration
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
# __LICENSE__
#
######################################################################
#
#  Validation routines. EPrints does some validation itself, such as
#  checking for required fields, but you can add custom requirements
#  here.
#
#  All the validation routines should return a list of XHTML DOM 
#  objects, one per problem. An empty list means no problems.
#
#  $for_archive is a boolean flag (1 or 0) it is set to 0 when the
#  item is being validated as a submission and to 1 when the item is
#  being validated for submission to the actual archive. This allows
#  a stricter validation for editors than for submitters. A useful 
#  example would be that a deposit may have one of several format of
#  documents but the editor must ensure that it has a PDF before it
#  can be submitted into the main archive. If it doesn't have a PDF
#  file, then the editor will have to generate one.
#
#---------------------------------------------------------------------

######################################################################
#
# validate_field( $field, $value, $session, $for_archive ) 
#
######################################################################
# $field 
# - MetaField object
# $value
# - metadata value (see docs)
# $session 
# - Session object (the current session)
# $for_archive
# - boolean (see comments at the start of the validation section)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
# Validate a particular field of metadata, currently used on users
# and eprints.
#
# This description should make sense on its own (i.e. should include 
# the name of the field.)
#
# The "required" field is checked elsewhere, no need to check that
# here.
#
######################################################################

sub validate_field
{
	my( $field, $value, $session, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE

	# Check that embargo expiry date is in the future
	if( $field->get_name eq "date_embargo" && $value ne "public" )
	{
		my ($thisyear, $thismonth, $thisday) = EPrints::Utils::get_date( time );
		my ($year, $month, $day) = split( '-', $value );
		if( $year < $thisyear || ( $year == $thisyear && $month < $thismonth ) ||
			( $year == $thisyear && $month == $thismonth && $day <= $thisday ) )
		{
			push @problems,
				$session->html_phrase( "embargo:invalid_date",
				fieldname=>$field->render_name( $session ) );
		}
	}

	# Loop over actual individual values to check URLs, names and emails

	if( $field->is_type( "url", "name", "email" ) && EPrints::Utils::is_set( $value ) )
	{
		$value = [$value] unless( $field->get_property( "multiple" ) );
		foreach( @{$value} )
		{
			my $v = $_;
			# If a name field has an ID part then we are looking at a hash
			# with "main" and "id" parts. We just want the main part.
			$v = $v->{main} if( $field->get_property( "hasid" ) );

			# Check a URL for correctness
			if( $field->is_type( "url" ) && $v !~ /^\w+:/ )
			{
				push @problems,
					$session->html_phrase( "validate:missing_http",
					fieldname=>$field->render_name( $session ) );
			}

			# Check a name has a family part
			if( $field->is_type( "name" ) && !EPrints::Utils::is_set( $v->{family} ) )
			{
				push @problems,
					$session->html_phrase( "validate:missing_family",
					fieldname=>$field->render_name( $session ) );
			}

			# Check a name has a given part
			if( $field->is_type( "name" ) && !EPrints::Utils::is_set( $v->{given} ) )
			{
				push @problems,
					$session->html_phrase( "validate:missing_given",
					fieldname=>$field->render_name( $session ) );
			}

			# Check an email looks "ok". Just checks it has only one "@" and no
			# spaces.
			if( $field->is_type( "email" ) && $v !~ /^[^ \@]+\@[^ \@]+$/ )
			{
				push @problems,
					$session->html_phrase( "validate:bad_email",
					fieldname=>$field->render_name( $session ) );
			}
		}
	}


	return( @problems );
}

######################################################################
#
# validate_eprint_meta_page( $eprint, $session, $page, $for_archive ) 
#
######################################################################
# $field 
# - EPrint object
# $session 
# - Session object (the current session)
# $page
# - The id of the input-page being validated (from the metadata-types
#   config file.
# $for_archive
# - boolean (see comments at the start of the validation section)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
# Validate just the metadata of a page of input of an eprint. 
# The validate_field method will have been called on each field 
# first so only complex problems such as interdependancies need 
# to be checked here.
#
# This allows problems to be shown as they happen, rather than waiting
# for the end of the input process. eg. Use this to set dependancies
# between fields.
#
######################################################################

sub validate_eprint_meta_page
{
	my( $eprint, $session, $page, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE

	if( $page eq "core" )
	{
		# If we don't have creators (eg. for a book) then we 
		# must have editor(s). To disable that rule, remove the 
		# following block.	
		if( !$eprint->is_set( "creators" ) && 
			!$eprint->is_set( "editors" ) )
		{
			push @problems, $session->html_phrase( 
					"validate:need_creators_or_editors" );
		}
	}


	if( $page eq "pubinfo" )
	{
		# by default we insist that each item has a sub date OR 
		# and issue date. To disable that rule, remove the 
		# following block.	
		if( !$eprint->is_set( "date_sub" ) 
			&& !$eprint->is_set( "date_issue" ) )
		{
			push @problems, $session->html_phrase( 
						"validate:need_sub_or_issue" );
		}
	}

	return @problems;
}
######################################################################
#
# validate_eprint_meta( $eprint, $session, $for_archive ) 
#
######################################################################
# $eprint 
# - EPrint object
# $session 
# - Session object (the current session)
# $for_archive
# - boolean (see comments at the start of the validation section)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
# Validate just the metadata of an eprint. The validate_field method
# will have been called on each field first so only complex problems
# such as interdependancies need to be checked here.
#
# This function by default calls all the "page" validations, although
# you may want to conditionally disable that.
#
######################################################################

sub validate_eprint_meta
{
	my( $eprint, $session, $for_archive ) = @_;

	my @problems = ();

	# Check all per-page validations are OK.
	my @pages = $eprint->get_dataset->get_type_pages( 
			$eprint->get_value( "type" ) );
	foreach my $page ( @pages )
	{
		push @problems, validate_eprint_meta_page( 
					$eprint, 
					$session,
					$page,
					$for_archive );
	}

	# CHECKS IN HERE

	return @problems;
}

######################################################################
#
# validate_eprint( $eprint, $session, $for_archive ) 
#
######################################################################
# $field 
# - EPrint object
# $session 
# - Session object (the current session)
# $for_archive
# - boolean (see comments at the start of the validation section)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
# Validate the whole eprint, this is the last part of a full 
# validation so you don't need to duplicate tests in 
# validate_eprint_meta, validate_field or validate_document.
#
######################################################################

sub validate_eprint
{
	my( $eprint, $session, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE

	return( @problems );
}


######################################################################
#
# validate_document_meta( $document, $session, $for_archive ) 
#
######################################################################
# $document 
# - Document object
# $session 
# - Session object (the current session)
# $for_archive
# - boolean (see comments at the start of the validation section)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
# Validate a documents metadata.
#
######################################################################


sub validate_document_meta
{
	my( $document, $session, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE

	# "other" documents must have a description set
	if( $document->get_value( "format" ) eq "other" &&
	   !EPrints::Utils::is_set( $document->get_value( "formatdesc" ) ) )
	{
		push @problems, $session->html_phrase( 
					"validate:need_description" ,
					type=>$document->render_description() );
	}

	return( @problems );
}

######################################################################
#
# validate_document( $document, $session, $for_archive ) 
#
######################################################################
# $document 
# - Document object
# $session 
# - Session object (the current session)
# $for_archive
# - boolean (see comments at the start of the validation section)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
# Validate a document. validate_document_meta will be called auto-
# matically, so you don't need to duplicate any checks.
#
######################################################################


sub validate_document
{
	my( $document, $session, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE

	return( @problems );
}

######################################################################
#
# validate_user( $user, $session, $for_archive ) 
#
######################################################################
# $user 
# - User object
# $session 
# - Session object (the current session)
# $for_archive
# - boolean (see comments at the start of the validation section)
#
# returns: @problems
# - ARRAY of DOM objects (may be null)
#
######################################################################
# Validate a user, although all the fields will already have been
# checked with validate_field so only complex problems need to be
# tested.
#
######################################################################

sub validate_user
{
	my( $user, $session, $for_archive ) = @_;

	my @problems = ();

	# CHECKS IN HERE

	return( @problems );
}

1;
