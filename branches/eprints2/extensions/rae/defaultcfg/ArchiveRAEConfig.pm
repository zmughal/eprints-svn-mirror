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

my $fields = {};

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

# Selection fields
$c->{fields}->{edit} = [
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
$c->{search_id} = "advanced";

# The field to group by on the reporting page
$c->{group_by} = "dept";

# The groups to exclude from the list on the reporting page
$c->{exclude_group} = {
	uos => 1,
};

# Set this flag to show the group of "all staff" on the reporting page
$c->{show_all} = 1;

return $c;
}

# Test whether the given user can assume the given role.
# Example: let certain users assume role of any person in school
sub can_user_assume_role {
	
	my ( $session, $user, $role ) = @_;

	if( !defined( $role ) )
	{
		return 0;
	}
	if ( dept_for_user( $user ) ne $role->get_value( "dept" ) )
	{
		return 0;
	}

	return 1;
};

# Return a list of (id, name) pairs representing the user roles the
# given user is able to assume
# Example: let certain users assume role of any person in school
sub roles_for_user {

	my ( $session, $user ) = @_;

	my @roles;
	my $searchexp = new EPrints::SearchExpression(
		session => $session,
		custom_order => "name",
		dataset => $session->get_archive->get_dataset( "user" ),
	);
	$searchexp->add_field( $session->get_archive->get_dataset( "user" )->get_field( "dept" ) , dept_for_user( $user ) );
	$searchexp->perform_search;

	foreach ( $searchexp->get_records ) {
		push @roles, [ $_->get_id, EPrints::Utils::tree_to_utf8( $_->render_description ) ];
	}
	
	return @roles;
};

# Set the default values for the search used on the eprint
# selection page
sub init_search {

	my ($searchexp, $user) = @_;
	print STDERR $user->get_value( "name" )->{family} . "\n\n\n";

	$searchexp->get_searchfield( "creators" )->{value} = $user->get_value("name")->{family};
	$searchexp->get_searchfield( "date_effective" )->{value} = "2003-";
};

# Return a list of problems with the given item as selected by the 
# given user (and possibly other users)
sub check_item { 
	my ( $session, $user, $item, $others ) = @_;
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
                } else {
			push @names, $session->phrase( "rae:unknown_user", id => $otherid );
		}
        }
        if( scalar( @names ) > 0 )
        {
		my $prob = $session->make_doc_fragment;
		my $perl_url = $session->get_archive->get_conf("perl_url");
		my $link = $session->render_link( $perl_url . "/users/rae/raeselect?role=" . $user->get_id );	
	
		push @problems, $session->html_phrase( "rae/report:problem_multiple_users",
                        names => $session->make_text( join(", ", @names) ),
			resolve_link => $link );
        }
	
	# Example: check item has full text
	my @docs = $item->get_all_documents();
	if( scalar( @docs ) == 0 ) {
		push @problems, $session->html_phrase( "rae/report:problem_no_doc",
			type => $session->make_text( $item->get_value( "type" ) ) );
	}

	return \@problems;
};

# Return the header line of the CSV output
sub csv_header {
	print csv_line('Dept', 'Username', 'Surname', 'First Name', 'Score', 'Publication', 'Paper' );
};


# Return a CSV row for the given item as selected by the given user
 sub csv_row {
	my ( $session, $user, $item ) = @_;
	my $name = $user->get_value( 'name' );
	my $book = $item->get_value( 'publication' );
	$book = $item->get_value( 'event_title' ) if !defined $book;
	
	print csv_line(
		$user->get_value( "dept" ),
		$user->get_value( "username" ),
		$name->{family},
		$name->{given},
		'',
		$book,
		EPrints::Utils::tree_to_utf8( $item->render_citation ),
	);
};

# Return the footer line(s) of the CSV output, given the number
# of rows already output
sub csv_footer {
	my ( $rows ) = @_;
	print csv_line( '','','','','','','' );
	my $range = 'E2:E'.($rows+1); # E1 is header row
	print csv_line( 'Score','Label','Total Papers','','','','','');
	print csv_line( '0', "Unclassified", '='.$rows."-INDEX(FREQUENCY($range,A".($rows+4).":A".($rows+8)."),2)-INDEX(FREQUENCY($range,A".($rows+5).":A".($rows+8)."),2)-INDEX(FREQUENCY($range,A".($rows+6).":A".($rows+8)."),2)-INDEX(FREQUENCY($range,A".($rows+7).":A".($rows+8)."),2)", '','','','','' );
	print csv_line( '1', "1*", "=INDEX(FREQUENCY($range,A".($rows+4).":A".($rows+8)."),2)",'','','','','' );
	print csv_line( '2', "2*", "=INDEX(FREQUENCY($range,A".($rows+5).":A".($rows+8)."),2)",'','','','','' );
	print csv_line( '3', "3*", "=INDEX(FREQUENCY($range,A".($rows+6).":A".($rows+8)."),2)",'','','','','' );
	print csv_line( '4', "4*", "=INDEX(FREQUENCY($range,A".($rows+7).":A".($rows+8)."),2)",'','','','','' );
};

# Format a list of values as a CSV row
# (used by csv_header, csv_row and csv_footer)
sub csv_line
{
	my( @values ) = @_;
	foreach( @values )
	{
		s/([\\\"])/\\$1/g;
	}
	return '"'.join( '","', @values ).'"'."\n";
}

# Map users to schools
sub dept_for_user {
	my ( $user ) = @_;
	return "uos-fp" if $user->get_id eq "500";
	return "uos-jf" if $user->get_id eq "341";
	return "uos-fp" if $user->get_id eq "7985";
	return undef;
}

1;
