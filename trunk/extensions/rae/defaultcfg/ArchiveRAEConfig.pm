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

sub get_rae_conf {

my $c = ();

# Measures of esteem fields
$c->{fields}->{moe} = [ 
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
$c->{fields}->{qualify} = [
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
$c->{selection_search} = "advanced";

# The (user) field to group by on the reporting page
$c->{group_reports_by} = "dept";

return $c;
}

# Populate the "Available Items" search for the given user
sub rae_default_selection_search {

	my ( $session, $searchexp, $user ) = @_;

	my $dataset = $session->get_archive->get_dataset( "archive" );

	$searchexp->add_field( $dataset->get_field( "creators" ), $user->get_value( "name" )->{family}, "IN", "ALL" );
	$searchexp->add_field( $dataset->get_field( "date_effective" ), "2001-" );
};

# Return a list of problems with the given item as selected by the given user
# $values is a hashref of qualifying metadata the user entered for this selection
# $others is a reference to an array of all users who have selected this item
sub rae_problems_with_selection { 
	my ( $session, $user, $item, $values, $others ) = @_;

	my @problems;	

	# Example: check no other users have selected this item
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
		my $link = $session->render_link( $perl_url . "/users/rae/select?role=" . $user->get_id );	
	
		push @problems, $session->html_phrase( "rae/report:problem_multiple_users",
                        names => $session->make_text( join(", ", @names) ),
			resolve_link => $link );
        }

	# Check item exists
	if( !defined $item )
	{
		push @problems, $session->html_phrase( "rae/report:problem_null_item" );
		return \@problems;
	}
	
	# Example: check item has full text
	my @docs = $item->get_all_documents();
	if( scalar( @docs ) == 0 )
	{
		push @problems, $session->html_phrase( "rae/report:problem_no_doc",
			type => $session->make_text( $item->get_value( "type" ) ),
			resolve_link => $session->render_link( $item->get_url( 1 ) ) ); 
	}

	# Example: if this item is an article, check it has an ISSN
	if( $item->get_type eq "article" )
	{
		if( !$item->is_set( "issn" ) )
		{
			push @problems, $session->html_phrase( "rae/report:problem_no_issn",
				resolve_link => $session->render_link( $item->get_url( 1 ) ) ); 
		}
	}

	return \@problems;
};

# Print CSV header row(s)
sub rae_print_csv_header {
	print _rae_escape_csv( "Dept", "Username", "Surname", "First Name", "Score", "Publication", "Paper" );
};


# Print CSV row for item as selected by user
# $values is a hashref of qualifying metadata the user entered for this selection
sub rae_print_csv_row {
	my ( $session, $user, $item, $values ) = @_;

	my $name = $user->get_value( "name" );

	my $book = "";
	my $citation;
	if( defined $item )
	{
		if( $item->get_type eq "article" )
		{
			$book = $item->get_value( "publication" );
		}
		elsif( $item->get_type eq "conference_item" )
		{
			$book = $item->get_value( "event_title" );
		}
		elsif( $item->get_type eq "book_section" )
		{
			$book = $item->get_value( "book_title" );
		}
		$citation = EPrints::Utils::tree_to_utf8( $item->render_citation );
	}
	else
	{
		$citation = $session->phrase( "rae:unknown_item", id => $values->{eprintid} );
	}

	
	
	print _rae_escape_csv(
		$user->get_value( "dept" ),
		$user->get_value( "username" ),
		$name->{family},
		$name->{given},
		"",
		$book,
		$citation
	);
}

# Print CSV footer row(s)
# $rows is the number of times rae_print_csv_row has been called
sub rae_print_csv_footer {
	my ( $rows ) = @_;

	print _rae_escape_csv( "", "", "", "", "", "", "" );

	my $range = "E2:E".($rows+1); # E1 is header row
	print _rae_escape_csv( "Score", "Label", "Total Papers", "", "", "", "", "");

	print _rae_escape_csv( "0", "Unclassified", "=".$rows."-INDEX(FREQUENCY($range,A".($rows+4).":A".($rows+8)."),2)-INDEX(FREQUENCY($range,A".($rows+5).":A".($rows+8)."),2)-INDEX(FREQUENCY($range,A".($rows+6).":A".($rows+8)."),2)-INDEX(FREQUENCY($range,A".($rows+7).":A".($rows+8)."),2)", "", "", "", "", "" );
	print _rae_escape_csv( "1", "1*", "=INDEX(FREQUENCY($range,A".($rows+4).":A".($rows+8)."),2)", "", "", "", "", "" );
	print _rae_escape_csv( "2", "2*", "=INDEX(FREQUENCY($range,A".($rows+5).":A".($rows+8)."),2)", "", "", "", "", "" );
	print _rae_escape_csv( "3", "3*", "=INDEX(FREQUENCY($range,A".($rows+6).":A".($rows+8)."),2)", "", "", "", "", "" );
	print _rae_escape_csv( "4", "4*", "=INDEX(FREQUENCY($range,A".($rows+7).":A".($rows+8)."),2)", "", "", "", "", "" );
};

# Helper function: format a list of values as CSV
sub _rae_escape_csv
{
	my( @values ) = @_;

	foreach( @values )
	{
		s/([\\\"])/\\$1/g;
	}
	return '"' . join( '","', @values ) . '"' ."\n";
}

# Can the given user can assume the given role?
sub rae_can_user_assume_role
{	
	my ( $session, $user, $role ) = @_;

	return 1 if $user->has_priv( "staff-view" );
	return 0;
};

# Return a list of (id, name) pairs representing the user roles the
# given user can assume
sub rae_roles_for_user
{
	my ( $session, $user ) = @_;

	return ();
};

1;
