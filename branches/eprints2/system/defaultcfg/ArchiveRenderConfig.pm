######################################################################
#
#  Site Render Config
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

=head1 NAME

ArchiveRenderConfig.pm - Repository-specific rendering routines

=head1 DESCRIPTION

Functions which convert repository data into a human readable form.

A couple of these routines return UTF8 encoded strings, but the
others return DOM structures. See the docs for more information
about this.

Anywhere text is set, it is requested from the repository phrases
XML file, in case you are running the repository in more than one
language.

Hopefully when we are in beta the'll be an alternative version
of this config for single language repositories.

=head1 METHODS

=over 4

=cut

######################################################################



######################################################################

=item $xhtmlfragment = eprint_render( $eprint, $session )

This subroutine takes an eprint object and renders the XHTML view
of this eprint for public viewing.

Takes two arguments: the L<$eprint|EPrints::DataObj::EPrint> to render and the current L<$session|EPrints::Session>.

Returns three XHTML DOM fragments (see L<EPrints::XML>): C<$page>, C<$title>, (and optionally) C<$links>.

=cut

######################################################################

sub eprint_render
{
	my( $eprint, $session ) = @_;

	my $succeeds_field = $session->get_repository->get_dataset( "eprint" )->get_field( "succeeds" );
	my $commentary_field = $session->get_repository->get_dataset( "eprint" )->get_field( "commentary" );
	my $has_multiple_versions = $eprint->in_thread( $succeeds_field );

	my( $page, $p, $a );

	$page = $session->make_doc_fragment;

	# Citation
	$p = $session->make_element( "p" );
	$p->appendChild( $eprint->render_citation() );
	$page->appendChild( $p );

	# Put in a message describing how this document has other versions
	# in the repository if appropriate
	if( $has_multiple_versions )
	{
		my $latest = $eprint->last_in_thread( $succeeds_field );

		if( $latest->get_value( "eprintid" ) == $eprint->get_value( "eprintid" ) )
		{
			$page->appendChild( $session->html_phrase( 
						"page:latest_version" ) );
		}
		else
		{
			$page->appendChild( $session->html_phrase( 
				"page:not_latest_version",
				link => $session->render_link( $latest->get_url() ) ) );
		}
	}		

	# Contact email address
	my $hascontact = 0;
	if( $session->get_repository->can_call( "email_for_doc_request" ) )
	{
		if( defined( $session->get_repository->call( "email_for_doc_request", $session, $eprint ) ) )
		{
			$hascontact = 1;
		}
	}

	# Available documents
	my @documents = $eprint->get_all_documents();

	my $docs_to_show = scalar @documents;

	# look for any coverimage document
	foreach( @documents )
	{
		next unless ( $_->get_value( "format" ) eq "coverimage" );

		$page->appendChild( $session->make_element(
			"img",
			align=>"left",
			style=>"padding-right: 0.5em; padding-bottom: 0.5em;",
			src=>$_->get_url(),
			alt=>$_->get_value( "formatdesc" ) ) );
		--$docs_to_show;	
	}

	$p = $session->make_element( "p" );
	$page->appendChild( $p );

	if( $docs_to_show == 0 )
	{
		$p->appendChild( $session->html_phrase( "page:nofulltext" ) );
		if( $hascontact )
		{
			# "Request a copy" button
			my $form = $session->render_form( "post", $session->get_repository->get_conf( "perl_url" ) . "/request_doc" );
			$form->appendChild( $session->render_hidden_field( "eprintid", $eprint->get_id ) );
			$form->appendChild( $session->render_action_buttons( 
				"submit" => $session->phrase( "request:button" )
			) );
			$p->appendChild( $form );
		}
	}
	else
	{
		$p->appendChild( $session->html_phrase( "page:fulltext" ) );

		my( $doctable, $doctr, $doctd );
		$doctable = $session->make_element( "table" );

		foreach my $doc ( @documents )
		{
			next if( $doc->get_value( "format" ) eq "coverimage" );
	
			$doctr = $session->make_element( "tr" );
	
			$doctd = $session->make_element( "td" );
			$doctr->appendChild( $doctd );
			$doctd->appendChild( 
				_render_fileicon( 
					$session, 
					$doc->get_type, 
					$doc->get_url ) );
	
			$doctd = $session->make_element( "td" );
				$doctr->appendChild( $doctd );
			$doctd->appendChild( $doc->render_citation_link() );
			my %files = $doc->files;
			if( defined $files{$doc->get_main} )
			{
				my $size = $files{$doc->get_main};
				$doctd->appendChild( $session->make_element( 'br' ) );
				$doctd->appendChild( $session->make_text( EPrints::Utils::human_filesize($size) ));
			}

			my $security = $doc->get_value( "security" );
			if( $hascontact && defined $security && $security ne "" )
			{
				# "Request a copy" button
				$doctd = $session->make_element( "td" );
				my $form = $session->render_form( "post", $session->get_repository->get_conf( "perl_url" ) . "/request_doc" );
				$form->appendChild( $session->render_hidden_field( "docid", $doc->get_id ) );
				$form->appendChild( $session->render_action_buttons( 
					"submit" => $session->phrase( "request:button" )
				) );
				$doctd->appendChild( $form );
				$doctr->appendChild( $doctd );
			}

			$doctable->appendChild( $doctr );
		}
		$page->appendChild( $doctable );
	}	

	# Embargo date
	if( $eprint->is_set( "date_embargo" ) && $eprint->get_value( "full_text_status") eq "restricted" )
	{
		$page->appendChild( $session->html_phrase( "embargo:status", 
			date => EPrints::Utils::render_date( $session, $eprint->get_value( "date_embargo" ) ) ) );
	}


	# Alternative locations
	if( $eprint->is_set( "official_url" ) )
	{
		$p = $session->make_element( "p" );
		$page->appendChild( $p );
		$p->appendChild( $session->html_phrase( "eprint_fieldname_official_url" ) );
		$p->appendChild( $session->make_text( ": " ) );
		$p->appendChild( $eprint->render_value( "official_url" ) );
	}
	
	# Then the abstract
	if( $eprint->is_set( "abstract" ) )
	{
		my $h2 = $session->make_element( "h2" );
		$h2->appendChild( 
			$session->html_phrase( "eprint_fieldname_abstract" ) );
		$page->appendChild( $h2 );

		$p = $session->make_element( "p" );
		$p->appendChild( $eprint->render_value( "abstract" ) );
		$page->appendChild( $p );
	}
	else
	{
		$page->appendChild( $session->make_element( 'br' ) );
	}
	
	my( $table, $tr, $td, $th );	# this table needs more class cjg
	$table = $session->make_element( "table",
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
	$table->appendChild( $session->render_row(
		$session->html_phrase( "eprint_fieldname_subjects" ),
		$eprint->render_value( "subjects" ) ) );

	$table->appendChild( $session->render_row(
		$session->html_phrase( "page:id_code" ),
		$eprint->render_value( "eprintid" ) ) );

	my $user = new EPrints::DataObj::User( 
			$eprint->{session},
 			$eprint->get_value( "userid" ) );
	my $usersname;
	if( defined $user )
	{
		$usersname = $session->make_element( "a", 
				href=>$eprint->{session}->get_repository->get_conf( "perl_url" )."/user?userid=".$user->get_value( "userid" ) );
		$usersname->appendChild( 
			$user->render_description() );
	}
	else
	{
		$usersname = $session->html_phrase( "page:invalid_user" );
	}

	$table->appendChild( $session->render_row(
		$session->html_phrase( "page:deposited_by" ),
		$usersname ) );

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
		$page->appendChild( 
			$session->html_phrase( "page:available_versions" ) );
		$page->appendChild( 
			$eprint->render_version_thread( $succeeds_field ) );
	}
	
	if( $eprint->in_thread( $commentary_field ) )
	{
		$page->appendChild( 
			$session->html_phrase( "page:commentary_threads" ) );
		$page->appendChild( 
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
	$url .= "aulast=".$first_author->{main}->{family};
	$url .= "&";
	$url .= "aufirst=".$first_author->{main}->{family};
	$url .= "&";
	$url .= "date=".$eprint->get_value( "date_issue" );
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
	$url .= "aulast=".$first_author->{main}->{family};
	$url .= "&";
	$url .= "date=".substr($eprint->get_value( "date_issue" ),0,4);
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



	# Add a link to the edit-page for this record. Handy for staff.
	my $edit_para = $session->make_element( "p", align=>"right" );
	$edit_para->appendChild( $session->html_phrase( 
		"page:edit_link",
		link => $session->render_link( $eprint->get_control_url ) ) );
	$page->appendChild( $edit_para );

	my $title = $eprint->render_description();

	my $links = $session->make_doc_fragment();

	$links->appendChild( $session->make_element( 
		"link",
		rel => "schema.DC",
		href => "http://purl.org/DC/elements/1.0/" ) );
	my $dcplugin = $session->plugin( "Export::DC" );
	my $dc = $dcplugin->convert_dataobj( $eprint );
	foreach( @{$dc} )
	{
		$links->appendChild( $session->make_element( 
			"meta",
			name => "DC.".$_->[0],
			content => $_->[1] ) );
	}

	return( $page, $title, $links );
}


######################################################################

=item $xhtmlfragment = user_render( $user, $session )

This subroutine takes a user object and renders the XHTML view
of this user for public viewing.

Takes the L<$user|EPrints::DataObj::User> to render and the current L<$session|EPrints::Session>.

Returns an $xhtmlfragment (see L<EPrints::XML>).

=cut

######################################################################


sub user_render
{
	my( $user, $session ) = @_;

	my $html;	

	my( $info, $p, $a );
	$info = $session->make_doc_fragment;

	# Render the public information about this user.
	$p = $session->make_element( "p" );
	$p->appendChild( $user->render_description() );
	# Address, Starting with dept. and organisation...
	if( $user->is_set( "dept" ) )
	{
		$p->appendChild( $session->make_element( "br" ) );
		$p->appendChild( $user->render_value( "dept" ) );
	}
	if( $user->is_set( "org" ) )
	{
		$p->appendChild( $session->make_element( "br" ) );
		$p->appendChild( $user->render_value( "org" ) );
	}
	if( $user->is_set( "address" ) )
	{
		$p->appendChild( $session->make_element( "br" ) );
		$p->appendChild( $user->render_value( "address" ) );
	}
	if( $user->is_set( "country" ) )
	{
		$p->appendChild( $session->make_element( "br" ) );
		$p->appendChild( $user->render_value( "country" ) );
	}
	$info->appendChild( $p );
	

	## E-mail and URL last, if available.
	if( $user->get_value( "hideemail" ) ne "TRUE" )
	{
		if( $user->is_set( "email" ) )
		{
			$p = $session->make_element( "p" );
			$p->appendChild( $user->render_value( "email" ) );
			$info->appendChild( $p );
		}
	}

	if( $user->is_set( "url" ) )
	{
		$p = $session->make_element( "p" );
		$p->appendChild( $user->render_value( "url" ) );
		$info->appendChild( $p );
	}
		

	return( $info );
}


######################################################################

=item $xhtmlfragment = render_value_with_id( $field, $session, $value, $alllangs, $rendered )

This function is used to madify how a field with an ID is rendered,
By default it just returns the rendered value as it was passed. The
most likely use for this function is to wrap the rendered value in
an anchor ( <a href="foo"> </a> ), generating the URL as appropriate
from the value's ID part.

=over 4

=item L<$field|EPrints::MetaField>

The field to which this value belongs.

=item L<$session|EPrints::Session>

The current session.

=item $value

The metadata value structure (see docs). (Field dependent, but most commonly a string or hash reference).

=item $alllangs

A boolean flag (1 or 0) indicating whether we rendering for just the current session language or showing all the data in the value.

=item $rendered

An XHTML DOM fragment containing the value rendered without any attention to the ID.

=back

Returns an XHTML DOM fragment (see L<EPrints::XML>) containing the value rendered with attention to the ID (or by default just $rendered)

=cut

######################################################################

sub render_value_with_id
{
	my( $field, $session, $value, $alllangs, $rendered ) = @_;

	# You might want to wrap the rendered value in an anchor, 
	# eg if the ID is a staff username
	# you may wish to link to their homepage. 

#cjg Link Baton?

# Simple Example:
#
#	if( $field->get_name() eq "SOMENAME" ) 
#	{	
#		my $fragment = $session->make_doc_fragment();
#		$fragment->appendChild( $rendered );
#		$fragment->appendChild( 
#			$session->make_text( " (".$value->{id}.")" ) );
#		return( $fragment );
#	}

	return( $rendered );
}


######################################################################

=item $label = id_label( $field, $session, $id )

Used when browsing by an ID field, this is used to convert the ID
to a displayable label. 

For example, if you are creating a browse-by for the authors ID
then you might want them displayed as the authors name. How you do 
this, if at all, depends very much on your data. By default it
just returns the value of the ID it was passed.

It will almost always just contain text. It could in theory contain
an image. It will usually be wrapped in an anchor <a> </a> so it
should not have any links in.

The L<$field|EPrints::MetaField> to which this ID belongs, the current L<$session|EPrints::Session> and $id is the ID part of a single metadata value 

Returns an XHTML DOM fragment (see L<EPrints::XML>), $label, describing human readable version of the ID.

=cut

######################################################################

sub id_label
{
	my( $field, $session, $id ) = @_;

	return $session->make_text( $id );
}

######################################################################

=item $xhtml = render_fileinfo( $session, $field, $value )

This is a custom render method for the fileinfo field. It splits
up the information in the "fileinfo" field and renders icons which
link directly to the documents.

It is used to include file icons in a citation.

The fileinfo field is updated using the "L<set_eprint_automatic_fields|ArchiveMetadataFieldsConfig/set_eprint_automatic_fields>" method in C<ArchiveMetadataFieldsConfig.pm>.

=cut

######################################################################

sub render_fileinfo
{
	my( $session, $field, $value ) = @_;

	my $f = $session->make_doc_fragment;
	foreach my $icon ( split /\|/ , $value )
	{
		my( $type, $url ) = split( /;/, $icon );
		$f->appendChild( _render_fileicon( $session, $type, $url ));
	}

	return $f;
}

sub _render_fileicon
{
	my( $session, $type, $url ) = @_;

	# If you want to do something clever like
	# map several types to one icon, then this
	# is the place to do it! 

	my $a = $session->render_link( $url );
	$a->appendChild( $session->make_element( 
		"img", 
		src=>$session->get_repository->get_conf("base_url")."/images/fileicons/$type.png",
		width=>48,
		height=>48,
		border=>0 ));
	return $a;
}



# Return true to indicate the module loaded OK.
1;

__END__

=back
