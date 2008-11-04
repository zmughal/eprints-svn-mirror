package EPrints::Plugin::Screen::Admin::FormatsRisks;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;
my $classified = "true";
my $hideall = "";
my $unstable = 0;
my $risks_url = "";
our $classified, $hideall, $unstable, $risks_url;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ formats_risks /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions", 
			position => 1245, 
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

	my $dataset = $session->get_repository->get_dataset( "eprint" );

	my $format_files = {};

	$dataset->map( $session, sub {
		my( $session, $dataset, $eprint ) = @_;
		
		foreach my $doc ($eprint->get_all_documents)
		{
			foreach my $file (@{($doc->get_value( "files" ))})
			{
				my $puid = $file->get_value( "pronom_uid" );
				$puid = "" unless defined $puid;
				push @{ $format_files->{$puid} }, $file->get_id;
			}
		}
	} );

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
			document.getElementById(id).style.display = canSee;
		}
		function hide(id) {
			
			document.getElementById(id).style.display = "none";
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
	#my $script_node = $plugin->{session}->make_element(
	#		"script",
	#		type => "text/javascript"
	#);
	#$script_node->appendText($script);
	$html->appendChild($script);
	my $inner_panel = $plugin->{session}->make_element( 
			"div", 
			id => $plugin->{prefix}."_panel" );

	my $unclassified = $plugin->{session}->make_element(
			"div",
			align => "center"
			);	
	$unclassified->appendText( "You have unclassified objects in your repository, to classify these you may want to run the tools/update_pronom_uids script. If not installed this tool is availale via http://files.eprints.org" );
	my $risks_warning = $plugin->{session}->make_element(
			"div",
			align => "center"
			);	
	$risks_warning->appendText( "Risks analysis functionality is currently not available.\nThis feature is due to be made available by The National Archives (UK) in the near future.\nThis page will automatically pick up the data when this feature becomes available." );
	my $risks_unstable = $plugin->{session}->make_element(
			"div",
			align => "center"
			);	
	$risks_unstable->appendText( "This EPrints install is referencing a trial version of the risk analysis service. None of the risk scores are likely to be accurate and thus should be ignored." );

	my $br = $plugin->{session}->make_element(
			"br"
	);

	my $format_table;
	my $warning;
	my $doc;
	my $available;
	my $risk_xml = "http://www.eprints.org/services/pronom_risk.xml";
	eval {
		$doc = EPrints::XML::parse_url($risk_xml);
	};
	if ($@) {
		$risks_url = "http://nationalarchives.gov.uk/pronom/preservationplanning.asmx";
		my $risk_state_warning_div = $plugin->{session}->make_element(
			"div"
		);
		$risk_state_warning_div->appendText("Risk Service Status Unavailable trying default url.");
		$warning = $plugin->{session}->render_message("warning",
			$risk_state_warning_div
		);
		#$inner_panel->appendChild($unclassified);
		$inner_panel->appendChild($warning);
		$available = 1;
	} else {
		my $node; 
		if ($unstable eq 1) {
			$node = ($doc->getElementsByTagName( "risks_unstable" ))[0];
		} else {
			$node = ($doc->getElementsByTagName( "risks_stable" ))[0];
		}
		$available = ($node->getElementsByTagName( "available" ))[0];
		$available = EPrints::Utils::tree_to_utf8($available);
		if ($available eq 1) {
			$risks_url = ($node->getElementsByTagName( "base_url" ))[0];
			$risks_url = EPrints::Utils::tree_to_utf8($risks_url);
		} else {
			$risks_url = "";
		}
	}
	if ($available eq 1) {
		if ( $unstable eq 1 ) {
			$warning = $plugin->{session}->render_message("warning",
					$risks_unstable
					);
		}
	} else {
		$warning = $plugin->{session}->render_message("warning",
				$risks_warning
				);
	}
	$format_table = $plugin->get_format_risks_table();

	if ($classified eq "false") {
		$warning = $plugin->{session}->render_message("warning",
			$unclassified
		);
		$inner_panel->appendChild($warning);
	}

	$inner_panel->appendChild($warning);
	$inner_panel->appendChild($format_table);
	$html->appendChild( $inner_panel );
	
	$script = $plugin->{session}->make_javascript(
		$hideall
	);
	$html->appendChild($script);
	return $html;
}

sub get_format_risks_table {
	
	my( $plugin ) = @_;

	my $files_by_format = $plugin->fetch_data();
	
	my $url = $risks_url;

	my $max_count = 0;	
	my $max_width = 300;
	
	my $format_table = $plugin->{session}->make_element(
			"table",
			width => "100%"
	);

	my $soap_error = "";
	my $pronom_error_message = "";
	foreach my $format (sort { $#{$files_by_format->{$b}} <=> $#{$files_by_format->{$a}} } keys %{$files_by_format})
	{
		my @SOAP_ERRORS = "";
		use SOAP::Lite
			on_fault => sub { my($soap, $res) = @_;
				if( ref( $res ) ) {
					chomp( my $err = $res->faultstring );
					push( @SOAP_ERRORS, "SOAP FAULT: $err" );
				}
				else {
					chomp( my $err = $soap->transport->status );
					push( @SOAP_ERRORS, "TRANSPORT ERROR: $err" );
				}
				return SOAP::SOM->new;
			};
		my $color = "blue";
		if (!($url eq "")) {	
			my $soap = SOAP::Lite 
				-> uri('http://pp.pronom.nationalarchives.gov.uk/getFormatRiskIn')
				-> proxy($url)
				#-> on_fault(sub { my($soap, $res) = @_;
			#		die ref $res ? $res->faultstring : $soap->transport->status;
			#	        return ref $res ? $res : new SOAP::SOM;
			#        })
				-> method (SOAP::Data->name('PUID' => \SOAP::Data->value( SOAP::Data->name('Value' => $format) ))->attr({xmlns => 'http://pp.pronom.nationalarchives.gov.uk'}) );
	
			my $result = $soap->result();
			
			foreach my $error (@SOAP_ERRORS) {
				if ($soap_error eq "" && !($error eq "")) {
					$soap_error = $error;
				}
			}
		
			if ($result < 200 && $soap_error eq "") {
				$color = "red";
			} else {
				$color = "blue";
			}
		}
	
		my $count = $#{$files_by_format->{$format}};
		$count++;
		if ($max_count < 1) {
			$max_count = $count;
		}
		my $format_name = "";
		my $format_code = "";
		my $format_version = "";

		if ($format eq "" || $format eq "NULL") {
			$format_name = "Not Classified";
			$classified = "false";
		} else {
			$format_code = $format;
			if (!($pronom_error_message eq "")) {
					$format_name = $format;
			} else {
				my $natxml = "http://www.nationalarchives.gov.uk/pronom/".$format.".xml";
				my $doc;
				eval {
					$doc = EPrints::XML::parse_url($natxml);
				};	
				if ($@) {
					$format_name = $format;
					$pronom_error_message = "Format Classification Service Unavailable";
				} else {
					my $format_name_node = ($doc->getElementsByTagName( "FormatName" ))[0];
					my $format_version_node = ($doc->getElementsByTagName( "FormatVersion" ))[0];
					$format_name = EPrints::Utils::tree_to_utf8($format_name_node);
					$format_version = EPrints::Utils::tree_to_utf8($format_version_node);
				}
			}
		}
			
		my $format_panel_tr = $plugin->{session}->make_element( 
				"tr", 
				id => $plugin->{prefix}."_".$format );

		my $format_details_td = $plugin->{session}->make_element(
				"td",
				align => "right"
		);
		my $format_count_td = $plugin->{session}->make_element(
				"td",
				align => "left"
		);
		my $pronom_output = $format_name . " ";
		if (trim($format_version) eq "") {
		} else {	
			$pronom_output .= "(Version " . $format_version . ") ";
		}
		my $plus_button = $plugin->{session}->make_element(
			"img",
			id => $format . "_plus",
			onclick => 'plus("'.$format.'")',
			src => "/style/images/plus.png",
			border => 0,
			alt => "PLUS"
		);
		my $minus_button = $plugin->{session}->make_element(
			"img",
			id => $format . "_minus",
			onclick => 'minus("'.$format.'")',
			src => "/style/images/minus.png",
			border => 0,
			alt => "MINUS"
		);
		$hideall = $hideall . 'hide("'.$format.'_minus");' . "\n";
		#$pronom_output .= " [" . $format_code . "] ";
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
		
		$format_count_bar_td->appendText ( "  " );
		$format_count_bar_td2->appendText(" " .$count);
		$format_count_bar_tr->appendChild( $format_count_bar_td ); 
		$format_count_bar_tr->appendChild( $format_count_bar_td2 ); 
		$format_count_bar->appendChild( $format_count_bar_tr );
		$format_details_td->appendText ( $pronom_output );
		$format_details_td->appendChild ( $plus_button );
		$format_details_td->appendChild ( $minus_button );
		$format_count_td->appendChild( $format_count_bar );
		$format_panel_tr->appendChild( $format_details_td );
		$format_panel_tr->appendChild( $format_count_td );
		$format_table->appendChild( $format_panel_tr );

		my $format_users = {};
		my $format_eprints = {};
		foreach my $fileid (@{$files_by_format->{$format}}) {
			my $file = EPrints::DataObj::File->new(
				$plugin->{session},
				$fileid
			);
			my $document = $file->get_parent();
			my $eprint = $document->get_parent();
			my $eprint_id = $eprint->get_value( "eprintid" );
			my $user = $eprint->get_user();
			my $user_id = $user->get_value( "userid" );
			push(@{$format_eprints->{$format}->{$eprint_id}},$fileid);
			push(@{$format_users->{$format}->{$user_id}},$fileid);
		}

		my $table = $plugin->get_user_files($format_users,$format);
		
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
		$hideall = $hideall . 'hide("'. $format.'_inner_row");' . "\n";
		my $inner_column1 = $plugin->{session}->make_element(
			"td",
			width => "70%"
			);
		my $inner_column2 = $plugin->{session}->make_element(
			"td",
			width => "30%",
			valign => "top"
			);
		my $eprints_table = $plugin->get_eprints_files($format_eprints,$format);
		$inner_column1->appendChild ( $eprints_table );
		$inner_column2->appendChild ( $table );
		$inner_row->appendChild( $inner_column1 );
		$inner_row->appendChild( $inner_column2 );
		$inner_table->appendChild( $inner_row );
		$other_column->appendChild( $inner_table );
		$other_row->appendChild( $other_column );
		$format_table->appendChild( $other_row );

	}
	my $ret = $plugin->{session}->make_doc_fragment;

	if (!($pronom_error_message eq "")) {
		my $pronom_error_div = $plugin->{session}->make_element(
			"div",
			align => "center"
			);	
		$pronom_error_div->appendText( $pronom_error_message );

		my $warning = $plugin->{session}->render_message("warning",
			$pronom_error_div
		);
		$ret->appendChild($warning);
		
	}

	if (!($soap_error eq "")) {
		my $soap_error_div = $plugin->{session}->make_element(
			"div",
			align => "center"
			);	
		$soap_error_div->appendText( "Risks Analysis Error:" . $soap_error);

		my $warning = $plugin->{session}->render_message("warning",
			$soap_error_div
		);
		$ret->appendChild($warning);
	}
	$ret->appendChild($format_table);
	return $ret;
}

sub get_eprints_files
{
	my ( $plugin, $format_eprints, $format ) = @_;
	
	my $block = $plugin->{session}->make_element(
		"div"
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
			my $bold = $plugin->{session}->make_element(
					"b"
			);
			$bold->appendText( $file->get_value("filename") );	
			$col1->appendChild( $bold );
			$col1->appendText( " (" . EPrints::Utils::human_filesize($file->get_value("filesize")) . ")");
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
			my $file_url = $file->get_parent()->get_url();			
			my $file_href = $plugin->{session}->make_element(
					"a",
					href => $file_url
			);
			$file_href->appendText( $file_url );
			$col2->appendText( "URL: " );
			$col2->appendChild( $file_href );
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
			$eprint_href->appendText( $file->get_parent()->get_parent()->get_value( "eprintid" ) );	
			$col3a->appendText( "EPrint ID: " );
			$col3a->appendChild( $eprint_href );
			my $col3b = $plugin->{session}->make_element(
					"td",
					style => "border-right: 1px dashed black; border-top: 1px dashed black; border-bottom: 1px dashed black; padding: 0.3em;"
			);
			$col3b->appendText( "User: " . EPrints::Utils::tree_to_utf8($file->get_parent()->get_parent()->get_user()->render_description()));
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
	$user_format_count_th1->appendText( "User" );
	$user_format_count_th2->appendText( "No of Files" );
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
		my $user = EPrints::DataObj::User->new(
				$plugin->{session},
				$user_id
				);
		$user_format_count_td1->appendText( EPrints::Utils::tree_to_utf8($user->render_description()) );
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
		#$file_count_bar_div->appendText ("1");
		my $file_count_bar_td2 = $plugin->{session}->make_element(
				"td",
				style => "padding-left: 2px;font-size: 0.8em;"
				);
		$file_count_bar_td1->appendChild( $file_count_bar_div );
		$file_count_bar_td2->appendText( $count );
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
