######################################################################
#
#  Site Information: Metadata Fields
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
# Metadata Configuration
#
#  The archive specific fields for users and eprints. Some fields
#  come automatically like a user's username or an eprints type. See
#  the docs for more information.
#
#  It's very tricky to change these fields without erasing the archive
#  and starting from scratch. So make the effort to get it right!
#
#  Note: Changing the fields here (usually) requires you to make a 
#  number of other configuration changes in some or all of the 
#  following:
#   - The metadata types config XML file
#   - The citation config XML file(s)
#   - The render functions
#   - The search options 
#   - The OAI support 
#
#  To (re)create the database you will need to run
#   bin/erase_archive  (if you've already run create_tables before)
#   bin/create_tables
#
#  See the documentation for more information.
#
######################################################################

sub get_metadata_conf
{
my $fields = {};

$fields->{user} = [

	{ name => "name", type => "name", render_opts=>{order=>"gf"} },

	{ name => "dept", type => "text" },

	{ name => "org", type => "text" },

	{ name => "address", type => "longtext", input_rows => 5 },

	{ name => "country", type => "text" },

	{ name => "hideemail", type => "boolean", input_style=>"radio" },

	{ name => "os", type => "set", input_rows => 1,
		options => [ "win", "unix", "vms", "mac", "other" ] },

	{ name => "url", type => "url" }

];

$fields->{eprint} = [

	{ name => "creators", type => "name", multiple => 1, input_boxes => 4,
		hasid => 1, input_id_cols=>20, 
		family_first=>1, hide_honourific=>1, hide_lineage=>1 }, 

	{ name => "title", type => "longtext", multilang=>0, input_rows => 3 },

	{ name => "ispublished", type => "set", 
			options => [ "pub","inpress","submitted" , "unpub" ] },

	{ name => "subjects", type=>"subject", top=>"subjects", multiple => 1, 
		browse_link => "subjects",
		render_input=>\&EPrints::Extras::subject_browser_input },

	{ name => "full_text_status", type=>"set",
			options => [ "public", "restricted", "none" ] },

	{ name => "monograph_type", type=>"set",
			options => [ 
				"technical_report", 
				"project_report",
				"documentation",
				"manual",
				"working_paper",
				"discussion_paper",
				"other" ] },



	{ name => "pres_type", type=>"set",
			options => [ 
				"paper", 
				"lecture", 
				"speech", 
				"poster", 
				"other" ] },

	{ name => "keywords", type => "longtext", input_rows => 2 },

	{ name => "note", type => "longtext", input_rows => 3 },

	{ name => "suggestions", type => "longtext" },

	{ name => "abstract", input_rows => 10, type => "longtext" },

	{ name => "date_sub", type=>"date", min_resolution=>"year" },

	{ name => "date_issue", type=>"date", min_resolution=>"year" },

	{ name => "date_effective", type=>"date", min_resolution=>"year" },

	{ name => "series", type => "text" },

	{ name => "publication", type => "text" },

	{ name => "volume", type => "text", maxlength => 6 },

	{ name => "number", type => "text", maxlength => 6 },

	{ name => "publisher", type => "text" },

	{ name => "place_of_pub", type => "text" },

	{ name => "pagerange", type => "pagerange" },

	{ name => "pages", type => "int", maxlength => 6, sql_index => 0 },

	{ name => "event_title", type => "text" },

	{ name => "event_location", type => "text" },
	
	{ name => "event_dates", type => "text" },

	{ name => "event_type", type => "set", options=>[ "conference","workshop","other" ] },

	{ name => "id_number", type => "text" },

	{ name => "patent_applicant", type => "text" },

	{ name => "institution", type => "text" },

	{ name => "department", type => "text" },

	{ name => "thesis_type", type => "set", options=>[ "masters", "phd", "other"] },

	{ name => "refereed", type => "boolean", input_style=>"radio" },

	{ name => "isbn", type => "text" },

	{ name => "issn", type => "text" },

	{ name => "fileinfo", type => "longtext",
		render_value=>\&render_fileinfo },

	{ name => "book_title", type => "text" },
	
	{ name => "editors", type => "name", multiple => 1, hasid=>1,
		input_boxes => 4, input_id_cols=>20, 
		family_first=>1, hide_honourific=>1, hide_lineage=>1 }, 

	{ name => "official_url", type => "url" },

# nb. Can't call this field "references" because that's a MySQL keyword.
	{ name => "referencetext", type => "longtext", input_rows => 3 },

	{ name => "date_embargo", type=>"date", render_input=>\&de_render_input, fromform => \&de_fromform },

];

# Render custom input controls for date_embargo field
sub de_render_input
{
	my ( $metafield, $session, $value ) = @_;
	my ( $yearval, $monthval, $dayval ) = split( "-", $value );

	my $frag = $session->make_doc_fragment;

	$frag->appendChild( $session->html_phrase( "lib/metafield:year" ) );
	$frag->appendChild( $session->make_text(" ") );

	# Year option list
	my ($year, $month, $day) = EPrints::Utils::get_date( time );
	my @pairs = ( [ "", $session->phrase( "lib/metafield:unspecified_selection" ) ] );
	map { push @pairs, [$_, $_] } $year .. ( $year + 10 ); # 10 years in future

	$frag->appendChild( $session->render_option_list(
		name => 'date_embargo_year',
		default => $yearval,
		pairs => \@pairs ) );
	
	# Month option list
	$frag->appendChild( $session->make_text(" ") );
	$frag->appendChild( $session->html_phrase( "lib/metafield:month" ) );
	$frag->appendChild( $session->make_text(" ") );

	$frag->appendChild( $session->render_option_list(
		name => 'date_embargo_month',
		values => [ "00".."12" ],
		default => $monthval,
		labels => $metafield->_month_names( $session ) ) );

	return $frag;
}

# Get values from custom date_embargo input controls
sub de_fromform
{
	my ( $value, $session ) = @_;
	my $month = $session->param( 'date_embargo_month' );
	my $year = $session->param( 'date_embargo_year' );

	$month = undef if( !EPrints::Utils::is_set($month) || $month == 0 );
	$year = undef if( !EPrints::Utils::is_set($year) || $year == 0 );

	my $r = undef;
	return $r if( !defined $year );
	$r .= sprintf( "%04d", $year );
	return $r if( !defined $month );
	$r .= sprintf( "-%02d", $month );
	return $r;
}

# Don't worry about this bit, remove it if you want.
# it's to store some information for a citation-linking
# modules we've not built yet. 
	
$fields->{document} = [
	{ name => "citeinfo", type => "longtext", multiple => 1 }
];

return $fields;
}



######################################################################
#
# set_eprint_defaults( $data , $session )
# set_user_defaults( $data , $session )
# set_document_defaults( $data , $session )
# set_subscription_defaults( $data , $session )
#
######################################################################
# $data 
# - reference to HASH mapping 
#      fieldname string
#   to
#      metadata value structure (see docs)
# $session 
# - the session object
# $eprint 
# - (only for set_document_defaults) this is the
#   eprint to which this document will belong.
#
# returns: nothing (Modify $data instead)
#
######################################################################
# These methods allow you to set some default values when things
# are created. This is useful if you skip stages in the submission 
# form or just want to set a default.
#
######################################################################

sub set_eprint_defaults
{
	my( $data, $session ) = @_;

	$data->{type} = "article";
}

sub set_user_defaults
{
	my( $data, $session ) = @_;

	$data->{hideemail} = "TRUE";
}

sub set_document_defaults
{
	my( $data, $session, $eprint ) = @_;

	$data->{language} = $session->get_langid();
	$data->{security} = "";
}

sub set_subscription_defaults
{
	my( $data, $session ) = @_;
}


######################################################################
#
# set_eprint_automatic_fields( $eprint )
# set_user_automatic_fields( $user )
# set_document_automatic_fields( $doc )
# set_subscription_automatic_fields( $subscription )
#
######################################################################
# $eprint/$user/$doc/$subscription 
# - the object to be modified
#
# returns: nothing (Modify the object instead).
#
######################################################################
# These methods are called every time commit is called on an object
# (commit writes it back into the database)
# These methods allow you to read and modify fields just before this
# happens. There are a number of uses for this. One is to encrypt 
# passwords as "secret" fields are only set if they are being changed
# otherwise they are empty. Another is to create fields which the
# submitter can't edit directly but you want to be searchable. eg.
# Number of authors.
#
######################################################################

sub set_eprint_automatic_fields
{
	my( $eprint ) = @_;

	my $type = $eprint->get_value( "type" );
	if( $type eq "monograph" || $type eq "thesis" )
	{
		unless( $eprint->is_set( "institution" ) )
		{
 			# This is a handy place to make monographs and thesis default to
			# your insitution
			#
			# $eprint->set_value( "institution", "University of Southampton" );
		}
	}

	if( $type eq "patent" )
	{
		$eprint->set_value( "ispublished", "pub" );
		# patents are always published!
	}

	if( $type eq "thesis" )
	{
		$eprint->set_value( "ispublished", "unpub" );
		# thesis are always unpublished.
	}

	my $date;
	if( $eprint->is_set( "date_issue" ) )
	{
		$date = $eprint->get_value( "date_issue" );
	} 
	elsif( $eprint->is_set( "date_sub" ) )
	{
		$date = $eprint->get_value( "date_sub" );
	}
	else
	{
	 	$date = $eprint->get_value( "datestamp" ); # worstcase
	}
	$eprint->set_value( "date_effective", $date );

	my @docs = $eprint->get_all_documents();
	my $textstatus = "none";
	my @finfo = ();
	if( scalar @docs > 0 )
	{
		$textstatus = "public";
		foreach( @docs )
		{
			if( $_->is_set( "security" ) )
			{
				$textstatus = "restricted"
			}
			push @finfo, $_->get_type.";".$_->get_url;
		}
	}
	$eprint->set_value( "full_text_status", $textstatus );
	$eprint->set_value( "fileinfo", join( "|", @finfo ) );


}

sub set_user_automatic_fields
{
	my( $user ) = @_;

	if( !$user->is_set( "frequency" ) )
	{
		$user->set_value( "frequency", "never" );
	}
}

sub set_document_automatic_fields
{
	my( $doc ) = @_;
}

sub set_subscription_automatic_fields
{
	my( $subscription ) = @_;
}



# Return true to indicate the module loaded OK.
1;













