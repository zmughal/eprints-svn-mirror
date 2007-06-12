######################################################################
#
# RAE-specific configuration options
#
######################################################################
#
# This file is part of the EPrints RAE module developed by the 
# Institutional Repositories and Research Assessment (IRRA) project,
# funded by JISC within the Digital Repositories programme.
#
# http://irra.eprints.org/
#
# The EPrints RAE module is free software; you can redistributet 
# and/or modify it under the terms of the GNU General Public License 
# as published by the Free Software Foundation; either version 2 of 
# the License, or (at your option) any later version.

# The EPrints RAE module is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty 
# OF MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
######################################################################

# Measures of esteem fields
$c->{rae}->{fields}->{moe} = [ 
	{ name => "memberships", type => "longtext" },
	{ name => "pubs", type => "longtext" },
	{ name => "confs", type => "longtext" },
	{ name => "awards", type => "longtext" },
	{ name => "funding", type => "longtext" },
	{ name => "impacts", type => "longtext" },
	{ name => "contribs", type => "longtext" },
	{ name => "output", type => "longtext" },
	{ name => "other", type => "longtext" },
];

# Qualify selection fields
$c->{rae}->{fields}->{qualify} = [
	{ name => "full_text", type => "boolean" },
	{ name => "external", type => "boolean" },
	{ name => "confidential", type => "boolean" },
	{ name => "interdis", type => "boolean" },
	{ name => "foreign_lang", type => "boolean" },
	{ name => "scholar", type => "boolean" },
	{ name => "details", type => "longtext" },
	{ name => "self_rating", type => "set", options => [0, 1, 2, 3, 4] },
	{ name => "ext_rating", type => "set", options => [0, 1, 2, 3, 4] },
	{ name => "int_rating", type => "set", options => [0, 1, 2, 3, 4] },
];

# The id of the search (as defined in ArchiveConfig.pm) used on
# the item selection page
$c->{rae}->{selection_search} = "advanced";

# The (user) field to group by on the reporting page
$c->{rae}->{group_reports_by} = "dept";

# List of fields, in order, for each RA2 output type
# See http://www.rae.ac.uk/datacoll/subs/RAE2008RA2DescriptionFieldsGuideV2.xls (August 2006)
# Special tokens:
#   opt_foo - field foo is "optional if available" (otherwise field will be treated as required by RA2)
#   eprinturl - official URL or EPrint URL
#   year - year part of date
#   monthyear - month and year parts of date
$c->{rae}->{ra2_fields_for_type} =
{
	# Authored book
	A => [ "year", "title", "", "pages", "publisher", "", "isbn", "", "", "eprinturl", "opt_id_number" ],
	# Edited book
	B => [ "year", "title", "", "pages", "publisher", "", "isbn", "", "", "eprinturl", "opt_id_number" ],
	# Chapter in book
	C => [ "year", "title", "book_title", "pagerange", "publisher", "editors", "isbn", "", "", "eprinturl", "opt_id_number" ],
	# Journal article
	D => [ "", "title", "volume", "pagerange", "publication", "", "issn", "monthyear", "", "eprinturl", "opt_id_number" ],
	# Conference contribution
	E => [ "", "title", "event_title", "opt_pages", "", "", "opt_issn", "monthyear", "", "eprinturl", "opt_id_number" ],
	# Patent / published patent application
	F => [ "", "title", "id_number", "", "", "", "", "date", "", "eprinturl", "" ],
	# Software
	G => [ "", "title", "", "", "publisher", "", "", "date", "", "eprinturl", "" ],
	# Internet Publications
	H => [ "", "title", "", "", "opt_publisher", "", "opt_issn", "date", "", "eprinturl", "opt_id_number" ],
	# Performance
	I => [ "", "title", "event_location", "", "", "", "", "", "", "eprinturl", "" ],
	# Composition
	J => [ "", "title", "", "", "", "", "", "date", "", "eprinturl", "" ],
	# Design
	K => [ "", "title", "", "", "", "", "", "date", "", "eprinturl", "" ],
	# Artefact
	L => [ "", "title", "event_location", "", "", "", "", "date", "", "eprinturl", "" ],
	# Exhibition
	M => [ "", "title", "event_location", "", "", "", "", "", "", "eprinturl", "" ],
	# Research report for external body
	N => [ "", "title", "", "pages", "opt_publisher", "", "", "date", "", "eprinturl", "opt_id_number" ],
	# Confidential report (for external body)
	O => [ "", "title", "", "pages", "", "", "", "date", "", "", "" ],
	# Devices and products
	P => [ "", "title", "", "", "", "", "", "date", "", "eprinturl", "" ],
	# Digital or visual media
	Q => [ "", "title", "", "", "opt_publisher", "", "", "date", "", "eprinturl", "" ],
	# Scholarly edition
	R => [ "year", "abstract", "title", "opt_pages", "opt_publisher", "editors", "opt_isbn", "date", "", "eprinturl", "opt_id_number" ],
	# Research datasets and databases
	S => [ "", "title", "", "", "", "", "", "date", "", "eprinturl", "opt_id_number" ],
	# Other form of assessable output
	T => [ "", "title", "", "", "", "", "", "date", "", "eprinturl", "opt_id_number" ],
};

# Populate the "Available Items" search for the given user
$c->{rae_default_selection_search} = sub {

	my ( $session, $searchexp, $user ) = @_;

	print STDERR "in default search setup\n";

	my $dataset = $session->get_archive->get_dataset( "archive" );

	$searchexp->add_field( $dataset->get_field( "creators_name" ), $user->get_value( "name" )->{family}, "IN", "ALL" );
	$searchexp->add_field( $dataset->get_field( "date" ), "2001-" );
};

# Return a list of problems with the given item as selected by the given user
# $info is a hashref of qualifying metadata the user entered for this selection
# $others is a reference to an array of all users who have selected this item
$c->{rae_problems_with_selection} = sub { 
	my ( $session, $user, $item, $info, $others ) = @_;

	my @problems;	

	# Check item exists
	if( !defined $item )
	{
		push @problems, $session->html_phrase( "rae/report:problem_null_item" );
		return \@problems;
	}

	# Check required RA2 fields are present
	my $ra2_type = $session->get_archive->call( "rae_get_ra2_type", $item );
	if( !defined $ra2_type )
	{
		push @problems, $session->html_phrase( "rae/report:problem_no_ra2_map", type => $item->render_value( "type" ) );
	}
	else
	{
		my @missing_fields;
		my @missing_opt_fields;
		my $ra2_fields = $session->get_archive->get_conf( "rae", "ra2_fields_for_type", $ra2_type );
		foreach my $f ( @$ra2_fields )
		{
			my $ra2_field = $f;

			next if $ra2_field eq "";
			next if $ra2_field eq "eprinturl"; # every item has a URL

			my $target = \@missing_fields;
			$target = \@missing_opt_fields if $ra2_field =~ s/^opt_//; # optional
		
			if( $ra2_field eq "year" )
			{
				push @$target, "date" if !$item->is_set( "date" );
			}
			elsif( $ra2_field eq "monthyear" )
			{
				my $date = $item->get_value( "date" );
				push @$target, "month" if $date !~ /^[0-9]{4}-[0-9]{2}/;
			}
			elsif( $ra2_field eq "pages" ) # maybe derive pages from pagerange

			{
				if( !$item->is_set( "pages" ) && !$item->is_set( "pagerange" ) )
				{
					push @$target, "pages";
				}
			}
			elsif( $ra2_field eq "volume" )
			{
				push @$target, "volume" if !$item->is_set( "volume" );
				push @$target, "number" if !$item->is_set( "number" );
			}
			else
			{
				push @$target, $ra2_field if !$item->is_set( $ra2_field );
			}
		}
		if( scalar( @missing_fields ) )
		{
			my $f = join ( ", ", @missing_fields );
			push @problems, $session->html_phrase( 
				"rae/report:problem_missing_required_fields",
				fields => $session->make_text( $f ),
				resolve_link => $session->render_link( $item->get_url( 1 ), target=>"_blank" ) ); 
		}
		if( scalar( @missing_opt_fields ) )
		{
			my $f = join ( ", ", @missing_opt_fields );
			push @problems, $session->html_phrase( 
				"rae/report:problem_missing_optional_fields",
				fields => $session->make_text( $f ),
				resolve_link => $session->render_link( $item->get_url( 1 ), target=>"_blank" ) ); 
		}
	}

	# Check no other users have selected this item
	my @names;
	foreach my $otherid ( @$others )
        {
		next if $otherid == $user->get_id;
                my $other = EPrints::User->new( $session, $otherid );
                if( defined $other )
                {
                        push @names, EPrints::Utils::tree_to_utf8( $other->render_description );
                }
		else
		{
			push @names, $session->phrase( "rae:unknown_user", id => $otherid );
		}
        }
        if( scalar( @names ) > 0 )
        {
		my $perl_url = $session->get_archive->get_conf("perl_url");
		my $link = $session->render_link( $perl_url . "/users/rae/select?role=" . $user->get_id, target=>"_blank" );	
	
		push @problems, $session->html_phrase( "rae/report:problem_multiple_users",
                        names => $session->make_text( join(", ", @names) ),
			resolve_link => $link );
        }

	# Check item has full text
	my @docs = $item->get_all_documents();
	if( scalar( @docs ) == 0 )
	{
		push @problems, $session->html_phrase( "rae/report:problem_no_doc",
			type => $session->make_text( $item->get_value( "type" ) ),
			resolve_link => $session->render_link( $item->get_url( 1 ), target=>"_blank" ) ); 
	}

	return \@problems;
};

# Print CSV header row(s)
# RA2 Output - see http://www.rae.ac.uk/datacoll/import/excel/RAE2008Data.xls (March 2006)
# TODO PendingPublication should be before URL
# TODO Year before OutputType
$c->{rae_print_csv_header} = sub {
	my ( $session ) = @_;
	print $session->get_archive->call( "_rae_escape_csv", qw(
		Institution
		UnitOfAssessment
		MultipleSubmission
		HESAStaffIdentifier
		StaffIdentifier
		OutputNumber
		OutputId
		OutputType
		Year
		LongTitle
		ShortTitle
		Pagination
		Publisher
		Editors
		ISBN
		PublicationDate
		EndDate
		URL
		DOI
		PendingPublication
		OtherDetails
		InterestConflicts
		DatesConflictExplanation
		EnglishAbstract
		ResearchGroup
		IsInterdisciplinary
		IsSensitive
		IsDuplicate
		NumberOfAdditionalAuthors
		CoAuthor1
		CoAuthor1External
		CoAuthor2
		CoAuthor2External
		CoAuthor3
		CoAuthor3External
	) );
};


# Print CSV row for item as selected by user
# $info is a hashref of qualifying metadata the user entered for this selection
$c->{rae_print_csv_row} = sub {

	print STDERR "PRINTING CSV ROW\n\n";

	my ( $session, $user, $item, $info, $output_number ) = @_;

	my @row;

	# Check for valid item
	if( !defined( $item ) )
	{
		print "Undefined item\n";
		return;
	} 

	my $ra2_type = $session->get_archive->call( "rae_get_ra2_type", $item );
	if( !$ra2_type )
	{
		print "Could not map type \"" . $item->get_type . "\" to RAE type\n";
		return;
	}

	# Institution
	push @row, ""; # Add Institution id here

	# UnitOfAssessment
	push @row, "";
	# push @row, $user->get_value( "rae_unit" ); # Part of user metadata?

	# MultipleSubmission
	push @row, "";

	# HESAStaffIdentifier
	push @row, "";
	
	# StaffIdentifier
	push @row, $user->get_value( "username" );

	# OutputNumber - "for administrative convenience of referencing only"
	push @row, $output_number;

	# OutputId
	push @row, $item->get_id;

	# OutputType
	push @row, $ra2_type;

	# Year LongTitle ShortTitle Pagination Publisher Editors ISBN PublicationDate EndDate URL DOI
	my $ra2_fields = $session->get_archive->get_conf( "rae", "ra2_fields_for_type", $ra2_type );
	foreach my $f ( @$ra2_fields )
	{
		my $field = $f;
		$field =~ s/^opt_//;

		if( $field eq "year" )
		{
			my $date = $item->get_value( "date" );
			$date =~ /^([0-9]{4})/;
			push @row, $1;
			next;
		}
		elsif( $field eq "monthyear" )
		{		
			my $date = $item->get_value( "date" );
			$date =~ /^([0-9]{4})(\-([0-9]{2}))?/;
			if ( $3 )
			{
				push @row, "$1-$3";
			}
			else
			{
				push @row, $1;
			}
			next;
		}
		elsif( $field eq "pages" )
		{
			my $pg = "";
			if( $item->is_set( "pages" ) )
			{
				$pg = $item->get_value( "pages" );
			}
			elsif( $item->is_set( "pagerange" ) )
			{
				my $pr = $item->get_value( "pagerange" );
				if( $pr =~ /^([0-9]+)\-([0-9]+)$/ )
				{
					$pg = ($2 - $1) + 1
				}
			}
			push @row, $pg;
		}
		elsif( $field eq "eprinturl" )
		{
			if( $item->is_set( "official_url" ) )
			{
				push @row, $item->get_value( "official_url" );
			}
			else
			{
				push @row, $item->get_url;
			}
		}
		elsif( $field eq "volume" )
		{
			my $vn = "";
			if( $item->is_set( "volume" ) )
			{
				$vn = EPrints::Utils::tree_to_utf8( $item->render_value( "volume" ) );
			}
			if( $item->is_set( "number" ) )
			{
				$vn .= "(" . EPrints::Utils::tree_to_utf8( $item->render_value( "number" ) ) . ")";
			}
			push @row, $vn;
			
		}
		elsif( $field eq "" )
		{
			push @row, "";
		}
		else
		{
			if( $item->is_set( $field ) )
			{
				push @row, EPrints::Utils::tree_to_utf8( $item->render_value( $field ) );
			}
			else
			{
				push @row, "";
			}
		}
	}

	# PendingPublication
	$item->get_value( "ispublished" ) ne "pub" ? push @row, "false" : push @row, "true";

	# OtherDetails
	defined $info->{details} ? push @row, $info->{details} : push @row, "";

	# InterestConflicts
	push @row, "";

	# DatesConflictExplanation
	push @row, "";

	# EnglishAbstract - only needed for non-english publications
	push @row, "";

	# ResearchGroup
	push @row, "";

	# IsInterdisciplinary
	defined $info->{interdis} ? push @row, lc $info->{interdis} : push @row, "false";

	# IsSensitive
	defined $info->{confidential} ? push @row, lc $info->{confidential} : push @row, "false";

	# IsDuplicate
	push @row, "";

	my @co_authors;
	for( @{ $item->get_value( "creators" ) } )
	{
		my $co_author = $_;
		# Skip author who selected publication
		next if defined $co_author->{id} && $co_author->{id} eq $user->get_value( "email" );
		push @co_authors, $co_author;
	}

	# NumberOfAdditionalAuthors
	push @row, scalar @co_authors;

	# CoAuthor1 CoAuthor1External CoAuthor2 CoAuthor2External CoAuthor3 CoAuthor3External
	for( 0..2 )
	{
		if( defined $co_authors[$_] )
		{
			push @row, EPrints::Utils::make_name_string( $co_authors[$_]->{name}, 1 ), "";
		}
		else
		{
			push @row, "", "";
		}
	}

	print $session->get_archive->call( "_rae_escape_csv", @row );

};

# Print CSV footer row(s)
# $rows is the number of times rae_print_csv_row has been called
$c->{rae_print_csv_footer} = sub {
	my ( $rows ) = @_;
};

# Helper function: format a list of values as CSV
$c->{_rae_escape_csv} = sub
{
	my( @values ) = @_;

	foreach( @values )
	{
		s/([\\\"])/\\$1/g;
	}
	return '"' . join( '","', @values ) . '"' ."\n";
};

# Can the given user can assume the given role?
$c->{rae_can_user_assume_role} = sub
{	
	my ( $session, $user, $role ) = @_;

	return 1 if $user->has_priv( "staff-view" );
	return 0;
};

# Return a list of (id, name) pairs representing the user roles the
# given user can assume
$c->{rae_roles_for_user} = sub
{
	my ( $session, $user ) = @_;

	return ();
};

# Given an eprint, work out corresponding RA2 type
$c->{rae_get_ra2_type} = sub
{
	my( $item ) = @_;

	my $type = $item->get_type;
	my $ra2_type;

	if( $type eq "book" )
	{
		$ra2_type = "A"; # Authored book
		$ra2_type = "B" if !$item->is_set( "creators" ); # Edited book
	}
	$ra2_type = "C" if $type eq "book_section"; # Chapter in book
	$ra2_type = "D" if $type eq "article"; # Journal article
	$ra2_type = "E" if $type eq "conference_item"; # Conference contribution
	$ra2_type = "F" if $type eq "patent"; # Patent / published patent application

	return $ra2_type;
};

1;
