#######################################################
###                                                 ###
###    Preserv2/EPrints FormatsRisk Screen Plugin   ###
###                                                 ###
#######################################################
###                                                 ###
###     Developed by David Tarrant and Tim Brody    ###
###                                                 ###
###          Released under the GPL Licence         ###
###           (c) University of Southampton         ###
###                                                 ###
###        Install in the following location:       ###
###  eprints/perl_lib/EPrints/Plugin/Screen/Admin/  ###
###                                                 ###
#######################################################

package EPrints::Plugin::Screen::Admin::FormatsRisks;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ formats_risks handle_upload get_plan/]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions_editorial", 
			position => 3000, 
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $plugin ) = @_;

	return 1;
}

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub fetch_data
{
	my ( $plugin ) = @_;

	my $session = $plugin->{session};

	my $dataset = $session->get_repository->get_dataset( "pronom" );

	my $format_files = {};

	$dataset->map( $session, sub {
		my( $session, $dataset, $pronom_formats ) = @_;
		
		foreach my $pronom_format ($pronom_formats)
		{
			my $puid = $pronom_format->get_value( "pronomid" );
			$puid = "" unless defined $puid;
			if ($pronom_format->get_value("file_count") > 0) 
			{
				$format_files->{$puid} = $pronom_format->get_value("file_count");
			}
		}
	} );

	$dataset = $session->get_repository->get_dataset( "file" );
	my $count = 0;
	$dataset->map( $session, sub {
		my( $session, $dataset, $files ) = @_;
		
		foreach my $file ($files)
		{
			my $datasetid = $file->get_value( "datasetid" );
			my $pronomid = $file->get_value( "pronomid" );
			my $document = $file->get_parent();
			if (($pronomid eq "") && ($datasetid eq "document") && ( !($document->has_related_objects( EPrints::Utils::make_relation( "isVolatileVersionOf" ) ) ) ) )	
			{
					$count++;	
			}
		}
	} );
#                session => $session,
#                dataset => $dataset,
#                filters => [
#                       { meta_fields => [qw( datasetid )], value => "document" },
#			{ meta_fields => [qw( pronomid )], value=>"" , match => "EX" },
#                ],
#        );
#        my $list = $searchexp->perform_search;
#	my $count = $list->count;
	if ($count > 0) {
		#print STDERR "Unclassified : " . $count . "\n";
		$format_files->{"Unclassified"} = $count;
	}
	
	return $format_files;
}

sub render
{
	my( $plugin ) = @_;

	my $session = $plugin->{session};

	
	my( $html , $table , $p , $span );

	$html = $session->make_doc_fragment;
	
	my $script = $plugin->{session}->make_javascript('
		function show(id) {
			var canSee = "block";
			if(navigator.appName.indexOf("Microsoft") > -1){
				canSee = "block";
			} else {
				canSee = "table-row";
			}
			$(id).style.display = canSee;
		}
		function hide(id) {
			if( !$(id) ) { return; }
			$(id).style.display = "none";
		}
		function plus(format) {
			hide(format + "_plus");
			show(format + "_minus");
			show(format + "_inner_row");
		}
		function minus(format) {
			show(format + "_plus");
			hide(format + "_minus");
			hide(format + "_inner_row");
		}
	');
	$html->appendChild($script);
	my $inner_panel = $plugin->{session}->make_element( 
			"div", 
			id => $plugin->{prefix}."_panel" );

	my $risks_unstable = $plugin->{session}->make_element(
			"div",
			align => "center"
			);	
	$risks_unstable->appendChild( $plugin->{session}->make_text("This EPrints install may be referecing a trial version of the risk analysis service. If you feel this is incorrect please contact the system administrator." ));

	my $br = $plugin->{session}->make_element(
			"br"
	);

	my $format_table;
	my $warning;
	my $doc;
	my $available;
	my $warning_width_table = $plugin->{session}->make_element(
		"table",
		id => "warnings",
		align=> "center",
		width => "620px"
	);
	my $wtr = $plugin->{session}->make_element( "tr" );
	my $warning_width_limit = $plugin->{session}->make_element( "td", width => "620px", align=>"center" );
	
	if( $session->get_repository->get_conf( "pronom_unstable" ) > 0) {
		$warning = $plugin->{session}->render_message("warning",
				$risks_unstable
				);
		$warning_width_limit->appendChild($warning);
	}
	$format_table = $plugin->get_format_risks_table( $warning_width_limit );

	$wtr->appendChild($warning_width_limit);
	$warning_width_table->appendChild($wtr);
	$inner_panel->appendChild($warning_width_table);
	$inner_panel->appendChild($format_table);
	$html->appendChild( $inner_panel );
	
	$html->appendChild( $plugin->render_hide_script );
	
	return $html;
}

sub render_hide_script {
	my( $plugin ) = @_;

	my @hides = ();
	my $dataset = $plugin->{session}->get_repository->get_dataset( "pronom" );

	my $medium_risk_boundary = $plugin->{session}->get_repository->get_conf( "medium_risk_boundary" );
	$dataset->map( $plugin->{session}, sub {
		my( $session, $dataset, $pronom_format ) = @_;
		
		my $result = $pronom_format->get_value("risk_score");
		my $format = $pronom_format->get_value("pronomid");

		if ($result <= $medium_risk_boundary) 
		{
			push @hides, 'hide("'.$format.'_minus");';
			push @hides, 'hide("'. $format.'_inner_row");';
		}
	} );

	push @hides, "";
	my $script = $plugin->{session}->make_javascript( join( "\n",@hides ) );
	return $script;
}

sub get_format_risks_table {
	
	my( $plugin, $message_element ) = @_;

	my $files_by_format = $plugin->fetch_data();

	if (%{$files_by_format} < 1) {
		my $unclassified = $plugin->{session}->make_element(
				"div",
				align => "center"
				);	
		$unclassified->appendChild( $plugin->{session}->make_text( "No Objects Found in Repository" ));
		my $warning = $plugin->{session}->render_message("warning", $unclassified);
		$message_element->appendChild($warning);	
	} 

	my $classified = 1;
	
	my $green = $plugin->{session}->make_element( "div", class=>"ep_msg_message", id=>"green" );
	my $orange = $plugin->{session}->make_element( "div", class=>"ep_msg_warning", id=>"orange" );
	my $red = $plugin->{session}->make_element( "div", class=>"ep_msg_error", id=>"red" );
	my $blue = $plugin->{session}->make_element( "div", class=>"ep_msg_other", id=>"blue" );
	#my $unclassified_orange = $plugin->{session}->make_element( "div", class=>"ep_msg_warning", id=>"unclassified_orange" );
	my $green_content_div = $plugin->{session}->make_element( "div", class=>"ep_msg_message_content" );
	my $orange_content_div = $plugin->{session}->make_element( "div", class=>"ep_msg_warning_content" );
	#my $unclassified_orange_content_div = $plugin->{session}->make_element( "div", class=>"ep_msg_warning_content" );
	my $red_content_div = $plugin->{session}->make_element( "div", class=>"ep_msg_error_content" );
	my $blue_content_div = $plugin->{session}->make_element( "div", class=>"ep_msg_other_content" );

	my $heading_red = $plugin->{session}->make_element( "h1" );
	$heading_red->appendChild( $plugin->{session}->make_text( " High Risk Objects ") );
	$red_content_div->appendChild( $heading_red );
	my $heading_orange = $plugin->{session}->make_element( "h1" );
	$heading_orange->appendChild( $plugin->{session}->make_text( " Medium Risk Objects ") );
	$orange_content_div->appendChild( $heading_orange );
	my $heading_green = $plugin->{session}->make_element( "h1" );
	$heading_green->appendChild( $plugin->{session}->make_text( " Low Risk Objects ") );
	$green_content_div->appendChild( $heading_green );
	my $heading_blue = $plugin->{session}->make_element( "h1" );
	$heading_blue->appendChild( $plugin->{session}->make_text( " No Risk Scores Available ") );
	$blue_content_div->appendChild( $heading_blue );
	#my $heading_unclassified_orange = $plugin->{session}->make_element( "h1" );
	#$heading_unclassified_orange->appendChild( $plugin->{session}->make_text( " Unclassified Objects ") );
	#$unclassified_orange_content_div->appendChild( $heading_unclassified_orange );
	
#	$div->appendChild( $title_div );
	my $green_count = 0;
	my $orange_count = 0;
	my $red_count = 0;
	my $blue_count = 0;
	#my $unclassified_count = 0;

	my $max_count = 0;	
	my $max_width = 300;

	my $green_format_table = $plugin->{session}->make_element( "table", width => "100%");
	my $orange_format_table = $plugin->{session}->make_element( "table", width => "100%");
	#my $unclassified_orange_format_table = $plugin->{session}->make_element( "table", width => "100%");
	my $red_format_table = $plugin->{session}->make_element( "table", width => "100%");
	my $blue_format_table = $plugin->{session}->make_element( "table", width => "100%");
	
	my $format_table = $blue_format_table;
	
	my $pronom_error_message = "";
	foreach my $format (sort { $files_by_format->{$b} <=> $files_by_format->{$a} } keys %{$files_by_format})
	{
		my $color = "blue";
		my $result;
		my $format_name = "";
		my $format_code = "";
		my $format_version = "";
		
		my $pronom_data = $plugin->{session}->get_repository->get_dataset("pronom")->get_object($plugin->{session}, $format);
		
		if (defined($pronom_data)) {
			$result = $pronom_data->get_value("risk_score");
			#print STDERR $format . " : ". $result . "\n";
			$format_name = $pronom_data->get_value("name");
			$format_version = $pronom_data->get_value("version");
		}

		my $high_risk_boundary = $plugin->{session}->get_repository->get_conf( "high_risk_boundary" );
		my $medium_risk_boundary = $plugin->{session}->get_repository->get_conf( "medium_risk_boundary" );


		if ($format eq "Unclassified" || $format eq "UNKNOWN" ) {
			$format_table = $red_format_table;
			$red_count = $red_count + 1;
			$color = "red";
		} elsif ($result < 1) {
			$format_table = $blue_format_table;
			$blue_count = $blue_count + 1;
			$color = "blue";
		} elsif ($result <= $high_risk_boundary) {
			$format_table = $red_format_table;
			$red_count = $red_count + 1;
			$color = "red";
		} elsif ($result > $high_risk_boundary && $result <= $medium_risk_boundary) {
			$format_table = $orange_format_table;
			$orange_count = $orange_count + 1;
			$color = "orange";
		} elsif ($result > $medium_risk_boundary) {
			$format_table = $green_format_table;
			$green_count = $green_count + 1;
			$color = "green";
		} else {
			$format_table = $blue_format_table;
			$blue_count = $blue_count + 1;
			$color = "blue";
		}
	
		my $count = $files_by_format->{$format};
		if ($max_count < 1) {
			$max_count = $count;
		}

		if ($format eq "" || $format eq "NULL") {
			$format_name = "Not Classified";
			$classified = 0;
		}

		if ($format_name eq "") {
			$format_name = $format;
		}
			
		my $format_panel_tr = $plugin->{session}->make_element( 
				"tr", 
				id => $plugin->{prefix}."_".$format );

		my $format_details_td = $plugin->{session}->make_element(
				"td",
				width => "50%",
				align => "right"
		);
		my $format_count_td = $plugin->{session}->make_element(
				"td",
				width => "50%",
				align => "left"
		);
		my $pronom_output = $format_name . " ";
		if (trim($format_version) eq "") {
		} else {	
			$pronom_output .= "(Version " . $format_version . ") ";
		}
		my $format_bar_width = ($count / $max_count) * $max_width;
		if ($format_bar_width < 10) {
			$format_bar_width = 10;
		}
		my $format_count_bar = $plugin->{session}->make_element(
				"table",
				#type => "submit",
				cellpadding => 0,
				cellspacing => 0,
				width => "100%",
				style => "background-color=$color;"
				#value => ""
		);
		my $format_count_bar_tr = $plugin->{session}->make_element(
				"tr"
		);
		my $format_count_bar_td = $plugin->{session}->make_element(
				"td",
				width => $format_bar_width."px",
				style => "background-color: $color;"
		);
		my $format_count_bar_td2 = $plugin->{session}->make_element(
				"td",
				style => "padding-left: 2px"
				
		);
		
		$format_count_bar_td->appendChild( $plugin->{session}->make_text( "  " ) );
		$format_count_bar_td2->appendChild ( $plugin->{session}->make_text( " " .$count) );
		$format_count_bar_tr->appendChild( $format_count_bar_td ); 
		$format_count_bar_tr->appendChild( $format_count_bar_td2 ); 
		$format_count_bar->appendChild( $format_count_bar_tr );
		$format_details_td->appendChild ( $plugin->{session}->make_text( $pronom_output ) );
		if ($result <= $medium_risk_boundary && !($color eq "blue")) 
		{
			$format_details_td->appendChild ( 
				$plugin->render_plus_and_minus_buttons( $format ) );
		}
		$format_count_td->appendChild( $format_count_bar );
		$format_panel_tr->appendChild( $format_details_td );
		$format_panel_tr->appendChild( $format_count_td );
		#if ($format_name eq "Not Classified") {
		#	$unclassified_orange_format_table->appendChild ( $format_panel_tr );
		#	$unclassified_count = $unclassified_count + 1;
		#} else {
			$format_table->appendChild( $format_panel_tr );
		#}
		
		my $other_row = $plugin->{session}->make_element(
			"tr"
			);
		my $other_column = $plugin->{session}->make_element(
			"td",
			colspan => 2
			);
		my $inner_table = $plugin->{session}->make_element(
			"table",
			width => "100%"
			);
		my $inner_row = $plugin->{session}->make_element(
			"tr",
			id => $format . "_inner_row"
			);
		my $inner_column1 = $plugin->{session}->make_element(
			"td",
			style => "width: 70%;",
			valign => "top"
			);
		my $inner_column2 = $plugin->{session}->make_element(
			"td",
			style => "width: 30%;",
			valign => "top"
			);

		my $format_users = {};
		my $format_eprints = {};
		if ($result <= $medium_risk_boundary && !($color eq "blue"))
		{
			my $search_format;
			my $dataset = $plugin->{session}->get_repository->get_dataset( "file" );
			if ($format eq "Unclassified") {
				$classified = 0;
				$search_format = "";
			} else {
				$search_format = $format;
			}
			my $session = $plugin->{session};
			if ($search_format eq "") {
				my $count = 0;
				$dataset->map( $session, sub {
					my( $session, $dataset, $files ) = @_;

					foreach my $file ($files)
					{
						my $datasetid = $file->get_value( "datasetid" );
						my $pronomid = $file->get_value( "pronomid" );
						my $fileid = $file->get_id;
						my $document = $file->get_parent();
						my $eprint = $document->get_parent();
						if (($pronomid eq "") && ($datasetid eq "document") && ( !($document->has_related_objects( EPrints::Utils::make_relation( "isVolatileVersionOf" ) ) ) ) )
						{	
							my $eprint_id = $eprint->get_value( "eprintid" );
							my $user = $eprint->get_user();
							my $user_id = $eprint->get_value( "userid" );
							push(@{$format_eprints->{$format}->{$eprint_id}},$fileid);
							push(@{$format_users->{$format}->{$user_id}},$fileid);
						}
					}
				} );	
			} else {
				my $searchexp = EPrints::Search->new(
						session => $session,
						dataset => $dataset,
						filters => [
						{ meta_fields => [qw( datasetid )], value => "document" },
						{ meta_fields => [qw( pronomid )], value => "$search_format", match => "EX" },
						],
						);
				my $list = $searchexp->perform_search;
				$list->map( sub { 
						my $file = $_[2];	
						my $fileid = $file->get_id;
						my $document = $file->get_parent();
						my $eprint = $document->get_parent();
						my $eprint_id = $eprint->get_value( "eprintid" );
						my $user = $eprint->get_user();
						my $user_id = $eprint->get_value( "userid" );
						push(@{$format_eprints->{$format}->{$eprint_id}},$fileid);
						push(@{$format_users->{$format}->{$user_id}},$fileid);
						} );
			} 
			my $table = $plugin->get_user_files($format_users,$format);
			my $eprints_table = $plugin->get_eprints_files($format_eprints,$format);
			my $preservation_action_table = $plugin->get_preservation_action_table($format);
			$inner_column1->appendChild ( $eprints_table );
			$inner_column2->appendChild ( $table );
			$inner_column2->appendChild ( $session->make_element("br") );
			$inner_column2->appendChild ( $preservation_action_table );
		}
		$inner_row->appendChild( $inner_column1 );
		$inner_row->appendChild( $inner_column2 );
		$inner_table->appendChild( $inner_row );
		$other_column->appendChild( $inner_table );
		$other_row->appendChild( $other_column );
		#if ($format_name eq "Not Classified") {
		#	$unclassified_orange_format_table->appendChild ( $other_row );
		#} else {
			$format_table->appendChild( $other_row );
		#}
	}
	my $ret = $plugin->{session}->make_doc_fragment;

	if (!($pronom_error_message eq "")) {
		my $pronom_error_div = $plugin->{session}->make_element(
			"div",
			align => "center"
			);	
		$pronom_error_div->appendChild( $plugin->{session}->make_text($pronom_error_message ));

		my $warning = $plugin->{session}->render_message("warning",
			$pronom_error_div
		);
		$ret->appendChild($warning);
		
	}

	$green_content_div->appendChild($green_format_table);
	$orange_content_div->appendChild($orange_format_table);
	$red_content_div->appendChild($red_format_table);
	$blue_content_div->appendChild($blue_format_table);
	#$unclassified_orange_content_div->appendChild($unclassified_orange_format_table);
	if ($green_count > 0 || $orange_count > 0 || $red_count > 0) {
		$green->appendChild( $green_content_div );
		$orange->appendChild( $orange_content_div );
		$red->appendChild( $red_content_div );
		$ret->appendChild($red);
		$ret->appendChild($orange);
		$ret->appendChild($green);
	}
	#if ($unclassified_count > 0) {
	#	$unclassified_orange->appendChild( $unclassified_orange_content_div );
	#	$ret->appendChild($unclassified_orange);
	#}
	if ($blue_count > 0) {
		$blue->appendChild( $blue_content_div );
		$ret->appendChild($blue);
	}


	if (!$classified) {
		my $unclassified = $plugin->{session}->make_element(
				"div",
				align => "center"
				);	
		$unclassified->appendChild( $plugin->{session}->make_text( "You have unclassified objects in your repository, to classify these you may want to run the tools/update_pronom_puids script. If not installed this tool is availale via http://files.eprints.org" ));
		my $warning = $plugin->{session}->render_message("warning", $unclassified);
		$message_element->appendChild($warning);
	}

	return( $ret );
}

sub render_plus_and_minus_buttons {
	my( $plugin, $format ) = @_;

	my $imagesurl = $plugin->{session}->get_repository->get_conf( "rel_path" );
	my $plus_button = $plugin->{session}->make_element(
		"img",
		id => $format . "_plus",
		onclick => 'plus("'.$format.'")',
		src => "$imagesurl/style/images/plus.png",
		border => 0,
		alt => "PLUS"
	);
	my $minus_button = $plugin->{session}->make_element(
		"img",
		id => $format . "_minus",
		onclick => 'minus("'.$format.'")',
		src => "$imagesurl/style/images/minus.png",
		border => 0,
		alt => "MINUS"
	);
	my $f = $plugin->{session}->make_doc_fragment();
	$f->appendChild ( $plus_button );
	$f->appendChild ( $minus_button );
	return $f;
}

sub get_eprints_files
{
	my ( $plugin, $format_eprints, $format ) = @_;
	
	my $block = $plugin->{session}->make_element(
		"div",
		style=>"max-width: 500px; max-height: 400px; overflow: auto;"
		);
	#my $eprint_ids = %{$format_eprints}->{$format};
	#foreach my $eprint_id (keys %{$eprint_ids})
	my @eprint_ids = keys %{$format_eprints->{$format}};
	foreach my $eprint_id (@eprint_ids)
	{

		my @file_ids = @{$format_eprints->{$format}->{$eprint_id}};
		foreach my $file_id (@file_ids)
		{
			my $file = EPrints::DataObj::File->new(
                                $plugin->{session},
                                $file_id
                        );

			my $table = $plugin->{session}->make_element(
					"table",
					width => "100%"
                        );
			my $row1 = $plugin->{session}->make_element(
					"tr"
			);			
			my $col1 = $plugin->{session}->make_element(
					"td",
					style => "border: 1px dashed black; padding: 0.3em;",
					colspan => 2
			);
			my $file_url = $file->get_parent()->get_url();			
			my $file_href = $plugin->{session}->make_element(
					"a",
					href => $file_url
			);
			my $bold = $plugin->{session}->make_element(
					"b"
			);
			$bold->appendChild( $plugin->{session}->make_text( $file->get_value("filename") ));	
			$file_href->appendChild( $bold );
			$col1->appendChild( $file_href );
			$col1->appendChild( $plugin->{session}->make_text(" (" . EPrints::Utils::human_filesize($file->get_value("filesize")) . ")"));
			$row1->appendChild( $col1 );
			$table->appendChild ( $row1 );
			my $row2 = $plugin->{session}->make_element(
					"tr"
			);			
			my $col2 = $plugin->{session}->make_element(
					"td",
					style => "border-right: 1px dashed black; border-left: 1px dashed black; padding: 0.3em;",
					colspan => 2
			);
			$bold = $plugin->{session}->make_element(
					"b"
			);
			$bold->appendChild( $plugin->{session}->make_text("Title: " ));
			$col2->appendChild( $bold );
			$col2->appendChild( $plugin->{session}->make_text($file->get_parent()->get_parent()->get_value( "title" )));
			$row2->appendChild( $col2 );
			$table->appendChild ( $row2 );
			my $row3 = $plugin->{session}->make_element(
					"tr"
			);			
			my $col3a = $plugin->{session}->make_element(
					"td",
					style => "border: 1px dashed black; padding: 0.3em;"
			);
			my $eprint_href = $plugin->{session}->make_element(
					"a",
					href => $file->get_parent()->get_parent()->get_url()
			);
			$eprint_href->appendChild( $plugin->{session}->make_text($file->get_parent()->get_parent()->get_value( "eprintid" ) ));	
			$bold = $plugin->{session}->make_element(
					"b"
			);
			$bold->appendChild( $plugin->{session}->make_text("EPrint ID: " ));
			$col3a->appendChild( $bold );
			$col3a->appendChild( $eprint_href );
			my $col3b = $plugin->{session}->make_element(
					"td",
					style => "border-right: 1px dashed black; border-top: 1px dashed black; border-bottom: 1px dashed black; padding: 0.3em;"
			);
			$bold = $plugin->{session}->make_element(
					"b"
			);
			$bold->appendChild( $plugin->{session}->make_text("User: " ));
			$col3b->appendChild( $bold );
			my $eprint = $file->get_parent()->get_parent();
			my $user = $eprint->get_user();
			if( defined $user )
			{
				$col3b->appendChild( $user->render_description() );
			}
			else
			{
				$col3b->appendChild( $plugin->{session}->make_text( "Unknown User (ID: ".$eprint->get_value( "userid" ).")"));
			}
			$row3->appendChild( $col3a );
			$row3->appendChild( $col3b );
			$table->appendChild( $row3 );
			$block->appendChild($table);
			my $br = $plugin->{session}->make_element(
				"br"
			);
			$block->appendChild($br);
		}
	}
	
	return $block;
}

sub get_preservation_action_table
{
	my ( $plugin, $format) = @_;
	
	my $session = $plugin->{session};
	my $outer_div = $session->make_element(
			"div",
			class => "ep_toolbox"
			);
	my $inner_div = $session->make_element(
			"div",
			class => "ep_toolbox_content"
			);
	$outer_div->appendChild($inner_div);

	my $title_div = $session->make_element(
			"div",
			align => "center",
			style=> "font-size: 1.2em; font-weight: bold;"
			);
	$title_div->appendText("Preservation Actions");
	$inner_div->appendChild($title_div);
	$inner_div->appendChild($plugin->{session}->make_element("hr"));

	my $p = $session->make_element(
			"p",
			style => "font-weight: bold;"
			);
	$p->appendText("Download File Seclection");
	$inner_div->appendChild($p);
	
	my $screen_id = "Screen::".$plugin->{processor}->{screenid} . "_download";
	my $screen = $session->plugin( $screen_id, processor => $plugin->{processor} );
	my $center_div = $session->make_element("div", align=>"center");
	my $form = $screen->render_form;
	$form->appendText("No. of Files:");
	my $count_field = $session->make_element(
			"input",
			name=> "count",
			size=> 3,
			value=> 5
			);
	$form->appendChild($count_field);
	my $format_field = $session->make_element( 
			"input",
			name=> "format",
			value=> $format,
			type=> "hidden"
			);
	#$format_field->appendText($format);
	$form->appendChild($format_field);
	my $download_button = $screen->render_action_button(
			{
			action => "get_files",
			screen => $screen,
			screen_id => $screen_id,
			} );
	$form->appendText(" ");
	$form->appendChild( $download_button );
	$center_div->appendChild($form);
	$inner_div->appendChild($center_div);
	
	$inner_div->appendChild($session->make_element("hr"));

	my $dataset = $session->get_repository->get_dataset( "preservation_plan" );
	
	$format =~ s/\//_/;
	$format =~ s/\\/_/;
	my $searchexp = EPrints::Search->new(
			session => $session,
			dataset => $dataset,
			filters => [
			{ meta_fields => [qw( format )], value => "$format", match => "EX" },
			],
			);

	my $list = $searchexp->perform_search;

	if ($list->count > 0) {
		my $file_path;
		$list->map( sub {
                        my $preservation_plan = $_[2];
                        $file_path = $preservation_plan->get_value("file_path");
                        });
		$p = $session->make_element(
				"p",
				style => "font-weight: bold;"
				);
		$p->appendText("Download Preservation Plan");
		$inner_div->appendChild($p);

		my $download_div = $session->make_element("div", style=>"width: 250px;", align=>"center");
		my $form = $session->render_form("POST");
		$inner_div->appendChild($download_div);
		$download_div->appendChild($form);
		my $file_field = $session->make_element( 
			"input",
			name=> "file_path",
			value=> $file_path,
			type=> "hidden"
			);
		$form->appendChild($file_field);
		
		$screen_id = "Screen::".$plugin->{processor}->{screenid} . "_get_plan";
		$screen = $session->plugin( $screen_id, processor => $plugin->{processor} );
		$download_button = $screen->render_action_button(
			{
			action => "get_plan",
			screen => $screen,
			screen_id => $screen_id,
			} );
		$form->appendChild($download_button);
		
		$form = $session->render_form("POST");
		$download_div->appendChild($form);
		$form->appendChild($format_field);
		$screen_id = "Screen::".$plugin->{processor}->{screenid} . "_delete_plan";
		$screen = $session->plugin( $screen_id, processor => $plugin->{processor} );
		my $msg = $plugin->phrase( "delete_plan_confirm" );
		my $delete_button = $screen->render_action_button(
			{
			action => "delete_plan",
			screen => $screen,
			screen_id => $screen_id,
	                #onclick => "if( window.event ) { window.event.cancelBubble = true; } return confirm(".EPrints::Utils::js_string($msg).");",
			} );
		$form->appendChild($delete_button);
	} else {

		$p = $session->make_element(
				"p",
				style => "font-weight: bold;"
				);
		$p->appendText("Upload Preservation Plan");
		$inner_div->appendChild($p);

		my $upload_form = $session->render_form("POST");
		my $upload_div = $session->make_element("div", style=>"width: 250px;", align=>"center");
		my $f = $session->make_doc_fragment;

#$f->appendChild( $session->html_phrase( "Plugin/InputForm/Component/Upload:new_document" ) );

		my $ffname = $plugin->{prefix}."_first_file";
		my $file_button = $session->make_element( "input",
				name => $ffname,
				id => $ffname,
				type => "file",
				size=> 12,
				maxlength=>12,
				);
		my $upload_progress_url = $session->get_url( path => "cgi" ) . "/users/ajax/upload_progress";
		my $onclick = "return startEmbeddedProgressBar(this.form,{'url':".EPrints::Utils::js_string( $upload_progress_url )."});";
		my $add_format_button = $session->render_button(
				value => $session->phrase( "Plugin/InputForm/Component/Upload:add_format" ),
				class => "ep_form_internal_button",
				name => "_action_handle_upload",
				onclick => $onclick );
		$f->appendChild( $file_button );
		$f->appendChild( $session->make_element( "br" ));
		$f->appendChild( $add_format_button );
		my $progress_bar = $session->make_element( "div", id => "progress" );
		$f->appendChild( $progress_bar );

		my $script = $session->make_javascript( "EPJS_register_button_code( '_action_next', function() { el = \$('$ffname'); if( el.value != '' ) { return confirm( ".EPrints::Utils::js_string($session->phrase("Plugin/InputForm/Component/Upload:really_next"))." ); } return true; } );" );
		$f->appendChild( $script);
		$f->appendChild( $session->render_hidden_field( "screen", $plugin->{processor}->{screenid} ) );
		$f->appendChild( $session->render_hidden_field( "_action_handle_upload", "Upload" ) );
		$upload_div->appendChild($f);
		$upload_form->appendChild($upload_div);
		$format_field = $session->make_element( 
				"input",
				name=> "format",
				value=> $format,
				type=> "hidden"
				);
		$upload_form->appendChild($format_field);
		$inner_div->appendChild($upload_form);
	}
	return $outer_div;
	
}

sub allow_handle_upload {
	my ( $self ) = @_;
	return 1;
}

sub action_handle_upload
{
	my ( $self ) = @_;
	
	my $session = $self->{session};

	my $format = $self->{session}->param( "format" );
	$format =~ s/\//_/;
	$format =~ s/\\/_/;

	my $fname = $self->{prefix}."_first_file";

	my $fh = $session->get_query->upload( $fname );

	my $doc_path = $session->get_conf( "arc_path" ) . "/" . $session->get_id . "/documents/preservation_plans/";
	mkdir($doc_path);

	if( defined( $fh ) )
	{
		binmode($fh);
		my $tmpfile = File::Temp->new( SUFFIX => ".xml" );
		use bytes;

		while(sysread($fh,my $buffer, 4096)) {
			syswrite($tmpfile,$buffer);
		}

		my $dataset = $session->get_repository->get_dataset( "preservation_plan" );

		my $searchexp = EPrints::Search->new(
				session => $session,
				dataset => $dataset,
				filters => [
				{ meta_fields => [qw( format )], value => "$format", match => "EX" },
			],
		);
	
		my $list = $searchexp->perform_search;

		if ($list->count < 1) {
			my $output = $doc_path . $format . ".xml";
			rename($tmpfile,$output);
			my $plan_data = $session->get_repository->get_dataset("preservation_plan")->create_object($session,{plan_type=>"plato",file_path=>$output,format=>$format});
			$plan_data->commit;
			$self->{processor}->add_message(
                                "message",
                                $self->html_phrase( "success" )
                                );
	                $self->{processor}->{screenid} = "Admin::FormatsRisks";
		} else {
			$self->{processor}->add_message(
                                "error",
                                $self->html_phrase( "plan_exists" )
                                );
	                $self->{processor}->{screenid} = "Admin::FormatsRisks";
		}
		#print STDERR "XML = " . $xml . "\n\n\n";
	
	}

}

sub get_user_files 
{
	my ( $plugin, $format_users, $format ) = @_;

	
	my $user_format_count_table = $plugin->{session}->make_element(
			"table",
			width => "250px",
			cellpadding => 1,
			style => "border: 1px solid black;",
			cellspacing => 0
			);
	my $user_format_count_tr = $plugin->{session}->make_element(
			"tr"
			);
	my $user_format_count_htr = $plugin->{session}->make_element(
			"tr"
			);
	my $user_format_count_th1 = $plugin->{session}->make_element(
			"th",
			align => "center",
			style => "font-size: 1em; font-weight: bold;"
			);
	my $user_format_count_th2 = $plugin->{session}->make_element(
			"th",
			align => "center",
			style => "font-size: 1em; font-weight: bold;"
			);
	$user_format_count_th1->appendChild( $plugin->{session}->make_text( "User" ));
	$user_format_count_th2->appendChild( $plugin->{session}->make_text( "No of Files" ));
	$user_format_count_htr->appendChild( $user_format_count_th1 );
	$user_format_count_htr->appendChild( $user_format_count_th2 );
	
	$user_format_count_table->appendChild( $user_format_count_htr );
	
	my $max_width=120;
	my $max_count = 0;



	my @user_ids = keys %{$format_users->{$format}};

	foreach my $user_id (sort  @user_ids)
	{
		my $count = $#{$format_users->{$format}->{$user_id}};
		$count++;
		if ($max_count < 1) {
			$max_count = $count;
		}
		my $user_format_count_tr = $plugin->{session}->make_element(
				"tr",
				);
		my $user_format_count_td1 = $plugin->{session}->make_element(
				"td",
				align => "right",
				style => "font-size: 0.9em;",
				width => "120px"
				);
		my $user = EPrints::DataObj::User->new( $plugin->{session}, $user_id );
		if( defined $user )
		{
			$user_format_count_td1->appendChild( $user->render_description() );
		}
		else
		{
			$user_format_count_td1->appendChild( $plugin->{session}->make_text( "Unknown User (ID: $user_id)"));
		}
		my $user_format_count_td2 = $plugin->{session}->make_element(
				"td",
				width => "130px"
				);
		my $file_count_bar = $plugin->{session}->make_element(
				"table",
				cellpadding => 0,
				cellspacing => 0,
				style => "width: 130px;"
				);
		my $file_count_bar_tr = $plugin->{session}->make_element(
				"tr"
				);
		my $file_bar_width = ($count / $max_count) * $max_width;
		if ($file_bar_width < 10) {
			$file_bar_width = 10;
		}
		my $file_count_bar_td1 = $plugin->{session}->make_element(
				"td",
				width => $file_bar_width . "px"
				);
		$file_bar_width = ($count / $max_count) * $max_width;
		if ($file_bar_width < 10) {
			$file_bar_width = 10;
		}
		my $file_count_bar_div = $plugin->{session}->make_element(
				"div",
				style => "width=".$file_bar_width."px; height: 10px; background-color: blue;"
				);
		my $file_count_bar_td2 = $plugin->{session}->make_element(
				"td",
				style => "padding-left: 2px;font-size: 0.8em;"
				);
		$file_count_bar_td1->appendChild( $file_count_bar_div );
		$file_count_bar_td2->appendChild( $plugin->{session}->make_text( $count ));
		$file_count_bar_tr->appendChild( $file_count_bar_td1 );
		$file_count_bar_tr->appendChild( $file_count_bar_td2 );
		$file_count_bar->appendChild( $file_count_bar_tr );
		$user_format_count_td2->appendChild( $file_count_bar );
		$user_format_count_tr->appendChild( $user_format_count_td1 );
		$user_format_count_tr->appendChild( $user_format_count_td2 );
		$user_format_count_table->appendChild( $user_format_count_tr );
	}
	return $user_format_count_table;	
}

sub redirect_to_me_url
{
	my( $plugin ) = @_;

	return undef;
}


1;
