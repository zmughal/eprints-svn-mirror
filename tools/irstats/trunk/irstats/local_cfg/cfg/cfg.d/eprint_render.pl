
######################################################################

=item $xhtmlfragment = eprint_render( $eprint, $session, $preview )

This subroutine takes an eprint object and renders the XHTML view
of this eprint for public viewing.

Takes two arguments: the L<$eprint|EPrints::DataObj::EPrint> to render and the current L<$session|EPrints::Session>.

Returns three XHTML DOM fragments (see L<EPrints::XML>): C<$page>, C<$title>, (and optionally) C<$links>.

If $preview is true then this is only being shown as a preview.
(This is used to stop the "edit eprint" link appearing when it makes
no sense.)

=cut

######################################################################

$c->{eprint_render} = sub
{
	my( $eprint, $session, $preview ) = @_;

	my $succeeds_field = $session->get_repository->get_dataset( "eprint" )->get_field( "succeeds" );
	my $commentary_field = $session->get_repository->get_dataset( "eprint" )->get_field( "commentary" );
	my $has_multiple_versions = $eprint->in_thread( $succeeds_field );

	my( $table, $tr, $td, $th );	# this table needs more class cjg
	my( $page, $p, $a );

	$page = $session->make_doc_fragment;
	# Citation
	$p = $session->make_element( "p", class=>"ep_block", style=>"margin-bottom: 1em" );
	$p->appendChild( $eprint->render_citation() );
	$page->appendChild( $p );

	# Put in a message describing how this document has other versions
	# in the repository if appropriate
	if( $has_multiple_versions )
	{
		my $latest = $eprint->last_in_thread( $succeeds_field );
		my $block = $session->make_element( "div", class=>"ep_block", style=>"margin-bottom: 1em" );
		$page->appendChild( $block );
		if( $latest->get_value( "eprintid" ) == $eprint->get_value( "eprintid" ) )
		{
			$block->appendChild( $session->html_phrase( 
						"page:latest_version" ) );
		}
		else
		{
			$block->appendChild( $session->render_message(
				"warning",
				$session->html_phrase( 
					"page:not_latest_version",
					link => $session->render_link( 
							$latest->get_url() ) ) ) );
		}
	}		

	# Contact email address
	my $has_contact_email = 0;
	if( $session->get_repository->can_call( "email_for_doc_request" ) )
	{
		if( defined( $session->get_repository->call( "email_for_doc_request", $session, $eprint ) ) )
		{
			$has_contact_email = 1;
		}
	}

	# Available documents
	my @documents = $eprint->get_all_documents();

	my $docs_to_show = scalar @documents;

	$p = $session->make_element( "p", class=>"ep_block", style=>"margin-bottom: 1em" );
	$page->appendChild( $p );

	if( $docs_to_show == 0 )
	{
		$p->appendChild( $session->html_phrase( "page:nofulltext" ) );
		if( $has_contact_email && $eprint->get_value( "eprint_status" ) eq "archive"  )
		{
			# "Request a copy" button
			my $form = $session->render_form( "get", $session->get_repository->get_conf( "http_cgiurl" ) . "/request_doc" );
			$form->appendChild( $session->render_hidden_field( "eprintid", $eprint->get_id ) );
			$form->appendChild( $session->render_action_buttons( 
				"null" => $session->phrase( "request:button" )
			) );
			$p->appendChild( $form );
		}
	}
	else
	{
		$p->appendChild( $session->html_phrase( "page:fulltext" ) );

		my( $doctable, $doctr, $doctd );
		$doctable = $session->make_element( "table", class=>"ep_block", style=>"margin-bottom: 1em" );

		foreach my $doc ( @documents )
		{
			my $icon_url = $doc->icon_url();

			$doctr = $session->make_element( "tr" );
	
			$doctd = $session->make_element( "td", valign=>"top", style=>"text-align:center" );
			$doctr->appendChild( $doctd );
			$doctd->appendChild( $doc->render_icon_link( preview => 0 ) );
	
			my %files = $doc->files;
			my $size = $files{$doc->get_main};

			$doctd = $session->make_element( "td", valign=>"top" );
			$doctr->appendChild( $doctd );
			$doctd->appendChild( $doc->render_citation() );

			my @doc_actions;

			if( defined $files{$doc->get_main} )
			{
				$doctd->appendChild( $session->make_element( 'br' ) );
				my $download_link = $session->render_link( $doc->get_url );
				$download_link->appendChild( $session->html_phrase( "lib/document:download", size => $session->make_text( EPrints::Utils::human_filesize($size) ) ) );
				push @doc_actions, $download_link;
				if( $doc->is_public )
				{
					my $caption = $session->make_doc_fragment;

					$caption->appendChild( $doc->render_citation() );
					$caption->appendChild( $session->make_element( "br" ) );
					$caption->appendChild( EPrints::XML::clone_node( $download_link ) );

					push @doc_actions, $doc->render_preview_link(
						caption=>$caption,
						set=>"documents",
					);
				}
			}

			if( $has_contact_email && !$doc->is_public && $eprint->get_value( "eprint_status" ) eq "archive" )
			{
				# "Request a copy" button
				my $uri = URI->new( $session->get_repository->get_conf( "http_cgiurl" ) . "/request_doc" );
				$uri->query_form(
					docid => $doc->get_id
				);
				my $request_link = $session->render_link( $uri );
				$request_link->appendChild( $session->html_phrase( "request:button" ) );
				push @doc_actions, $request_link;
			}

			for(my $i = 0; $i < @doc_actions; ++$i)
			{
				$doctd->appendChild( $session->html_phrase( "lib/document:action_separator" ) ) if $i > 0;
				$doctd->appendChild( $doc_actions[$i] );
			}

			$doctable->appendChild( $doctr );
		}
		$page->appendChild( $doctable );
	}	

	# Alternative locations
	if( $eprint->is_set( "official_url" ) )
	{
		$p = $session->make_element( "p", class=>"ep_block", style=>"margin-bottom: 1em" );
		$page->appendChild( $p );
		$p->appendChild( $session->html_phrase( "eprint_fieldname_official_url" ) );
		$p->appendChild( $session->make_text( ": " ) );
		$p->appendChild( $eprint->render_value( "official_url" ) );
	}
	
	# Then the abstract
	if( $eprint->is_set( "abstract" ) )
	{
		my $div = $session->make_element( "div", class=>"ep_block" );
		$page->appendChild( $div );
		my $h2 = $session->make_element( "h2" );
		$h2->appendChild( 
			$session->html_phrase( "eprint_fieldname_abstract" ) );
		$div->appendChild( $h2 );

		$p = $session->make_element( "p", style=>"text-align: left; margin: 1em auto 0em auto" );
		$p->appendChild( $eprint->render_value( "abstract" ) );
		$div->appendChild( $p );
	}
	else
	{
		$page->appendChild( $session->make_element( 'br' ) );
	}
	
	$table = $session->make_element( "table",
					class=>"ep_block", style=>"margin-bottom: 1em",
					border=>"0",
					cellpadding=>"3" );
	$page->appendChild( $table );

	# Commentary
	if( $eprint->is_set( "commentary" ) )
	{
		my $target = EPrints::DataObj::EPrint->new( 
			$session,
			$eprint->get_value( "commentary" ),
			$session->get_repository()->get_dataset( "archive" ) );
		if( defined $target )
		{
			$table->appendChild( $session->render_row(
				$session->html_phrase( 
					"eprint_fieldname_commentary" ),
				$target->render_citation_link() ) );
		}
	}

	my $frag = $session->make_doc_fragment;
	$frag->appendChild( $eprint->render_value( "type"  ) );
	my $type = $eprint->get_value( "type" );
	if( $type eq "conference_item" )
	{
		$frag->appendChild( $session->make_text( " (" ));
		$frag->appendChild( $eprint->render_value( "pres_type"  ) );
		$frag->appendChild( $session->make_text( ")" ));
	}
	if( $type eq "monograph" )
	{
		$frag->appendChild( $session->make_text( " (" ));
		$frag->appendChild( $eprint->render_value( "monograph_type"  ) );
		$frag->appendChild( $session->make_text( ")" ));
	}
	if( $type eq "thesis" )
	{
		$frag->appendChild( $session->make_text( " (" ));
		$frag->appendChild( $eprint->render_value( "thesis_type"  ) );
		$frag->appendChild( $session->make_text( ")" ));
	}
	$table->appendChild( $session->render_row(
		$session->html_phrase( "eprint_fieldname_type" ),
		$frag ));

	# Additional Info
	if( $eprint->is_set( "note" ) )
	{
		$table->appendChild( $session->render_row(
			$session->html_phrase( "eprint_fieldname_note" ),
			$eprint->render_value( "note" ) ) );
	}


	# Keywords
	if( $eprint->is_set( "keywords" ) )
	{
		$table->appendChild( $session->render_row(
			$session->html_phrase( "eprint_fieldname_keywords" ),
			$eprint->render_value( "keywords" ) ) );
	}



	# Subjects...
	if( $eprint->is_set( "subjects" ) )
	{
		$table->appendChild( $session->render_row(
			$session->html_phrase( "eprint_fieldname_subjects" ),
			$eprint->render_value( "subjects" ) ) );
	}

	# Divisions...
	if( $eprint->is_set( "divisions" ) )
	{
		$table->appendChild( $session->render_row(
			$session->html_phrase( "eprint_fieldname_divisions" ),
			$eprint->render_value( "divisions" ) ) );
	}

	$table->appendChild( $session->render_row(
		$session->html_phrase( "page:id_code" ),
		$eprint->render_value( "eprintid" ) ) );

	my $user = new EPrints::DataObj::User( 
			$eprint->{session},
 			$eprint->get_value( "userid" ) );
	my $usersname;
	if( defined $user )
	{
		$usersname = $user->render_description();
	}
	else
	{
		$usersname = $session->html_phrase( "page:invalid_user" );
	}

	$table->appendChild( $session->render_row(
		$session->html_phrase( "page:deposited_by" ),
		$usersname ) );

	if( $eprint->is_set( "sword_depositor" ) )
	{
		my $depositor = new EPrints::DataObj::User(
					$eprint->{session},
					$eprint->get_value( "sword_depositor" ) );
		my $depo_user;
		if( defined $depositor )
		{
			$depo_user = $depositor->render_description();
		}
		else
		{
			$depo_user = $session->html_phrase( "page:invalid_user" );
		}

		$table->appendChild( $session->render_row(
			$session->html_phrase( "page:sword_deposited_by" ),
			$depo_user) );
	}


	if( $eprint->is_set( "datestamp" ) )
	{
		$table->appendChild( $session->render_row(
			$session->html_phrase( "page:deposited_on" ),
			$eprint->render_value( "datestamp" ) ) );
	}

	if( $eprint->is_set( "lastmod" ) )
	{
		$table->appendChild( $session->render_row(
			$session->html_phrase( "eprint_fieldname_lastmod" ),
			$eprint->render_value( "lastmod" ) ) );
	}


	# Now show the version and commentary response threads
	if( $has_multiple_versions )
	{
		my $div = $session->make_element( "div", class=>"ep_block", style=>"margin-bottom: 1em" );
		$page->appendChild( $div );
		$div->appendChild( 
			$session->html_phrase( "page:available_versions" ) );
		$div->appendChild( 
			$eprint->render_version_thread( $succeeds_field ) );
	}
	
	if( $eprint->in_thread( $commentary_field ) )
	{
		my $div = $session->make_element( "div", class=>"ep_block", style=>"margin-bottom: 1em" );
		$page->appendChild( $div );
		$div->appendChild( 
			$session->html_phrase( "page:commentary_threads" ) );
		$div->appendChild( 
			$eprint->render_version_thread( $commentary_field ) );
	}

if(0){	
	# Experimental SFX Link
	my $url ="http://demo.exlibrisgroup.com:9003/demo?";
	#my $url = "http://aire.cab.unipd.it:9003/unipr?";
	$url .= "title=".$eprint->get_value( "title" );
	$url .= "&";
	my $authors = $eprint->get_value( "creators" );
	my $first_author = $authors->[0];
	$url .= "aulast=".$first_author->{name}->{family};
	$url .= "&";
	$url .= "aufirst=".$first_author->{name}->{family};
	$url .= "&";
	$url .= "date=".$eprint->get_value( "date" );
	my $sfx_block = $session->make_element( "p" );
	$page->appendChild( $sfx_block );
	my $sfx_link = $session->render_link( $url );
	$sfx_block->appendChild( $sfx_link );
	$sfx_link->appendChild( $session->make_text( "SFX" ) );
}

if(0){
	# Experimental OVID Link
	my $url ="http://linksolver.ovid.com/OpenUrl/LinkSolver?";
	$url .= "atitle=".$eprint->get_value( "title" );
	$url .= "&";
	my $authors = $eprint->get_value( "creators" );
	my $first_author = $authors->[0];
	$url .= "aulast=".$first_author->{name}->{family};
	$url .= "&";
	$url .= "date=".substr($eprint->get_value( "date" ),0,4);
	if( $eprint->is_set( "issn" ) )
	{
		$url .= "&issn=".$eprint->get_value( "issn" );
	}
	if( $eprint->is_set( "volume" ) )
	{
		$url .= "&volume=".$eprint->get_value( "volume" );
	}
	if( $eprint->is_set( "number" ) )
	{
		$url .= "&issue=".$eprint->get_value( "number" );
	}
	if( $eprint->is_set( "pagerange" ) )
	{
		my $pr = $eprint->get_value( "pagerange" );
		$pr =~ m/^([^-]+)-/;
		$url .= "&spage=$1";
	}

	my $ovid_block = $session->make_element( "p" );
	$page->appendChild( $ovid_block );
	my $ovid_link = $session->render_link( $url );
	$ovid_block->appendChild( $ovid_link );
	$ovid_link->appendChild( $session->make_text( "OVID" ) );
}
	
	if( scalar @documents )
        {
                $page->appendChild( render_eprint_stats( $session, $eprint ));
        }

	unless( $preview )
	{
		# Add a link to the edit-page for this record. Handy for staff.
		my $edit_para = $session->make_element( "p", align=>"right" );
		$edit_para->appendChild( $session->html_phrase( 
			"page:edit_link",
			link => $session->render_link( $eprint->get_control_url ) ) );
		$page->appendChild( $edit_para );
	}

	my $title = $eprint->render_description();

	my $links = $session->make_doc_fragment();
	$links->appendChild( $session->plugin( "Export::Simple" )->dataobj_to_html_header( $eprint ) );
	$links->appendChild( $session->plugin( "Export::DC" )->dataobj_to_html_header( $eprint ) );

	return( $page, $title, $links );
};

sub render_eprint_stats
{
        my( $session, $eprint ) = @_;

        my $stats = $session->make_doc_fragment;

        my $h2 = $session->make_element( "h2" );
        $h2->appendChild( $session->make_text( "Download Statistics - Monthly" ) );
        $stats->appendChild( $h2 );

	my $cgi_path = $session->get_url(path=>"cgi");

	my $iframe = $session->make_element( "iframe", 
			src=>"$cgi_path/irstats.cgi?page=get_view2&IRS_epchoice=EPrint&eprint=".$eprint->get_value( 'eprintid' )."&IRS_datechoice=period&period=-12m&view=MonthlyDownloadsGraph",
			width=>"550px",
			height=>"350px",
			style=>"border: 0;"
			);
	my $p = $session->make_element("p");
	$p->appendText("Monthly Stats not available via this browser");
	$iframe->appendChild($p);
	my $br = $session->make_element("br");
	$stats->appendChild( $iframe );
	$stats->appendChild( $br );

        $h2 = $session->make_element( "h2" );
        $h2->appendChild( $session->make_text( "Download Statistics - Daily" ) );
        $stats->appendChild( $h2 );
	$iframe = $session->make_element( "iframe", 
			src=>"$cgi_path/irstats.cgi?page=get_view2&IRS_epchoice=EPrint&eprint=".$eprint->get_value( 'eprintid' )."&IRS_datechoice=period&period=-12m&view=DailyDownloadsGraph",
			width=>"550px",
			height=>"350px",
			style=>"border: 0;"
			);
	$p = $session->make_element("p");
	$p->appendText("Monthly Stats not available via this browser");
	$iframe->appendChild($p);
	$stats->appendChild( $iframe );
	$stats->appendChild( $br );

	

        return $stats;
}
