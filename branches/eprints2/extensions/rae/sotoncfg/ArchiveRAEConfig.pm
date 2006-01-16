use EPrints::DisambiguateCreators;
# Configuration for eprints@soton

sub get_rae_conf {

my $c = ();

$c->{group_perms} = {
	"500" => "uos-fp", #tmb
	"341" => "uos-jf", # anw
	"7985" => "uos-fp", # sf11
};

# 'Measures of esteem' fields
$c->{rae_fields} = ["rae_conf", "rae_prof", "rae_gbod", "rae_extexam", "rae_vispos", "rae_advbod", "rae_ed", 
	"rae_fell", "rae_lect", "rae_awards", "rae_hdeg", "rae_grants", "rae_papawards", "rae_rmono", 
	"rae_patents", "rae_sorgs", "rae_rcent", "rae_consind", "rae_entract", "rae_sciboards", "rae_other"];

# Id of the search used to select RAE items
$c->{search_id} = "advanced";

# Default values for the $searchexp
# in context of current $user
$c->{init} = sub {
	my ($searchexp, $user) = @_;
	
	#print STDERR "Hello: ".$searchexp->render_description()->toString();
			
	#$searchexp->get_searchfield( "creators/editors" )->{value} = $user->get_value("name")->{family};
	$searchexp->get_searchfield( "creators" )->{value} = $user->get_value("name")->{family};
	
	$searchexp->get_searchfield( "date_effective" )->{value} = "2003-";
};

# Grouping field for RAE reports
$c->{group_by} = "dept";

# Groups to exclude from the list
$c->{exclude_group} = {
	uos => 1,
};

# Show the group of 'all staff'
$c->{show_all} = 1;

# Check a selected item for problems in RAE report
# $user is the user who has selected the $item
# $others is the list of all users (inc. $user) who
# have selected the item
$c->{check_item} = sub { 
	my ( $session, $user, $item, $others ) = @_;
	my @problems;
	# Check no other users have selected this item
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
		push @problems, $session->html_phrase( "rae/report:problem_multiple_users",
                        names => $session->make_text( join(", ", @names) ) );
        }	
	# Check item has a document
	my @docs = $item->get_all_documents();
	if( scalar( @docs ) == 0 ) {
		push @problems, $session->html_phrase( "rae/report:problem_no_doc",
			type => $session->make_text( $item->get_value( "type" ) ) );
	}
	my $perl_url = $session->get_archive->get_conf("perl_url");
	#seb: added link to raeselect if problem
	if(scalar(@problems) > 0)
	{
		my $link = $session->render_link( $perl_url . "/users/rae/raeselect?role=" . $user->get_id."&_action_submit=Change+Role");
	
		push @problems, $session->html_phrase( "rae/report:problem_select_link",
                        select_link => $link );
	}
	
	##ANW Error note to identify eprints with incomplete disambiguation information
	if(DisambiguateCreators::verifyCreatorID($item,$session) ne "")
	{
			my $link = $session->render_link($perl_url."/users/staff/edit_eprint?dataset=".($item->{dataset})."&eprintid=".($item->get_value("eprintid")));
			
			push (@problems, $session->html_phrase( "rae/report:problem_disambig", select_link => $link ));
		
	}
	
	return \@problems;
};

# Print CSV header
$c->{csv_header} = sub {
	print csv_line('Dept', 'Username', 'Surname', 'First Name', 'Score', 'Publication', 'Paper', 'Author Disposition');
};


# Print CSV row for a selected item
# (called for each selected item)
$c->{csv_row} = sub {
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
		DisambiguateCreators::renderRAECreatorStatusText($session, $item->get_value("eprintid")),
	);
};

# Print CSV footer
# $rows is the number of item rows already output
$c->{csv_footer} = sub {
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

$c->{testconf} = "Hello World!";

return $c;
}


sub csv_line
{
	# Format a list of values as a CSV row
	my( @values ) = @_;
	foreach( @values )
	{
		s/([\\\"])/\\$1/g;
	}
	return '"'.join( '","', @values ).'"'."\n";
}


1;
