######################################################################
#
# EPrints::Extras;
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::Extras;

use EPrints::Session;

use warnings;
use strict;


######################################################################
=pod

=item subject_browser_input

This is an alternate input renderer for "subject" fields. It is 
intended to be passed by reference to the render_input parameter
of such a field.

Due to the way this works, it is recommended that the "subjects"
type field it is used for is by itself on the metadata input page.

=cut
######################################################################

sub subject_browser_input
{
	my( $field, $value, $dataset, $type, $staff, $hidden_fields ) = trim_params(@_);

	my $values;
	if( !defined $value )
	{
		$values = [];
	}
	elsif( !$field->get_property( "multiple" ) )
	{
		$values = [ $value ]; 
	}
	else
	{
		$values = $value; 
	}

	my $topsubj = $field->get_top_subject;
 	my $subject = $topsubj;

	my $html = &SESSION->make_doc_fragment;

	my $search;
	if( &SESSION->internal_button_pressed )
	{
		my $button = &SESSION->get_internal_button;
		my $rexp;
		$rexp = $field->get_name."_view_";
		if( $button =~ m/^$rexp(.*)$/ )
		{
			$subject = EPrints::Subject->new( $1 );
			if( !defined $subject ) 
			{ 
				$subject = $topsubj; 
			}
		}
		if( $button eq $field->get_name."_search" )
		{
			$search = &SESSION->param( "_internal_".$field->get_name."_search" );
		}
	}

	my @param_pairs = ( "_default_action=null" );
	foreach( keys %{$hidden_fields} )
	{
		push @param_pairs, $_.'='.$hidden_fields->{$_};
	}
	my $baseurl = '?'.join( '&', @param_pairs );

	my( %bits );

	$bits{selections} = &SESSION->make_doc_fragment;

	foreach my $s_id ( sort @{$values} )
	{
		my $s = EPrints::Subject->new( $s_id );
		next if( !defined $s );

		$html->appendChild( 
			&SESSION->render_hidden_field(
				$field->get_name,
				$s_id ) );

		my $div = &SESSION->make_element( "div" );
		$div->appendChild( $s->render_description );

		my $url = $baseurl.'&_internal_'.$field->get_name.'_view_'.$subject->get_id.'=1'.$field->get_name.'='.$s->get_id;
		foreach my $v ( @{$values} )
		{
			next if( $v eq $s_id );
			$url.= '&'.$field->get_name.'='.$v;
		}
		$url .= '#t';

		$div->appendChild(  &SESSION->html_phrase(
                        "lib/extras:subject_browser_remove",
			link=>&SESSION->make_element( "a", href=>$url ) ) );
		$bits{selections}->appendChild( $div );
	}

	if( scalar @{$values} == 0 )
	{	
		my $div = &SESSION->make_element( "div" );
		$div->appendChild( &SESSION->html_phrase(
			"lib/extras:subject_browser_none" ) );
		$bits{selections}->appendChild( $div );
	}

	my @paths = $subject->get_paths;
	my %expanded = ();
	foreach my $path ( @paths )
	{
		my $div = &SESSION->make_element( "div" );
		my $first = 1;
		foreach my $s ( @{$path} )
		{
			$expanded{$s->get_id}=1;
		}
		$bits{selections}->appendChild( $div );
	}	

	$bits{search} = &SESSION->html_phrase(
			"lib/extras:subject_browser_search",
			input=>&SESSION->make_element( "input", name=>"_internal_".$field->get_name."_search" ),
			button=>&SESSION->make_element( "input", type=>"submit", name=>"_null", 
				value=>&SESSION->phrase( "lib/extras:subject_browser_search_button" ) ) );
	$bits{topsubj} = $topsubj->render_description;

	if( defined $search ) 
	{
		my $subject_ds = &ARCHIVE->get_dataset( "subject" );

		my $searchexp = new EPrints::SearchExpression(
			dataset=>$subject_ds );
	
		$searchexp->add_field(
			$subject_ds->get_field( "name" ),
			$search,
			"IN",
			"ALL" );
		$searchexp->add_field(
			$subject_ds->get_field( "ancestors" ),
			$topsubj->get_id,
			"EQ" );

		my $searchid = $searchexp->perform_search;

		my @records = $searchexp->get_records;
		$searchexp->dispose();

		my $results;
		if( scalar @records )
		{
			$results = &SESSION->make_element( "ul" );
			foreach my $s ( @records )
			{
				$results->appendChild( 
					_subject_browser_input_aux(
						$field,
						$s,
						$subject,
						\%expanded,
						$baseurl,
						$values ) );
			}
		}	
		else
		{
			$results = &SESSION->html_phrase( 
                        "lib/extras:subject_browser_no_matches" );
		}

		my $url = $baseurl.'&_internal_'.$field->get_name.'_view_'.$subject->get_id.'=1'.$field->get_name.'='.$subject->get_id;
		foreach my $v ( @{$values} )
		{
			$url.= '&'.$field->get_name.'='.$v;
		}
		$url .= '#t';

		$bits{opts} = &SESSION->html_phrase( 
			"lib/extras:subject_browser_search_results", 
			results=>$results,
			browse=>&SESSION->render_link( $url ) );
	}
	else
	{	
		my $ul = &SESSION->make_element( "ul" );
		foreach my $s ( $topsubj->children() )
		{
			$ul->appendChild( 
				_subject_browser_input_aux( 
					$field,
					$s,
					$subject,
					\%expanded,
					$baseurl,
					$values ) );
		}
		$bits{opts} = $ul;
	}

	$html->appendChild( &SESSION->html_phrase( 
			"lib/extras:subject_browser",
			%bits ) );

	return $html;
}


sub _subject_browser_input_aux
{
	my( $field, $subject, $current_subj, $expanded, $baseurl, $values ) = trim_params(@_);

	my $addurl = $baseurl;
	foreach my $v ( @{$values} )
	{
		$addurl.= '&'.$field->get_name.'='.$v;
	}

	my $li = &SESSION->make_element( "li" );

	my $n_kids = scalar $subject->children();
	my $exp = 0;
	if( $n_kids > 0 )
	{
		if( $expanded->{$subject->get_id} )
		#if( $expanded->{$subject->get_id} || $n_kids < 3)
		{
			$exp = 1;
		}
		else
		{
			$exp = -1;
		}
	}
	my $selected = 0;
	foreach my $v ( @{$values} )
	{
		$selected = 1 if( $v eq $subject->get_id );
	}
	if( $exp == -1 )
	{
		my $url = $addurl.'&_internal_'.$field->get_name.'_view_'.$subject->get_id.'=1#t';
		my $a = &SESSION->make_element( "a", href=>$url );
		$a->appendChild( $subject->render_description );
		$li->appendChild( $a );
		$li->appendChild( &SESSION->html_phrase(
                       	"lib/extras:subject_browser_expandable" ) );
	}
	else
	{
		my $span = &SESSION->make_element( 
			"span", 
			class=>"subject_browser_".($selected?"":"un")."selected" );
		$span->appendChild( $subject->render_description );
		$li->appendChild( $span );
	}
	if( $subject->can_post && $exp != -1 && !$selected )
	{
		my $ibutton = '_internal_'.$field->get_name.'_view_'.$current_subj->get_id.'=1';
		if( &SESSION->internal_button_pressed )
		{
			my $intact = '_internal_'.&SESSION->get_internal_button();
			$ibutton = $intact.'='.&SESSION->param( $intact );
		}

		my $url = $addurl.'&'.$ibutton.'&'.$field->get_name.'='.$subject->get_id.'#t';
		$li->appendChild(  &SESSION->html_phrase(
                       	"lib/extras:subject_browser_add",
			link=>&SESSION->make_element( "a", href=>$url ) ) );
	}
	if( $exp == 1 )
	{
		$li->appendChild( &SESSION->make_element( "br" ));

		my $ul = &SESSION->make_element( "ul" );
		foreach my $s ( $subject->children() )
		{
				$ul->appendChild( _subject_browser_input_aux(
					$field,
					$s, 
					$current_subj,
					$expanded, 
					$baseurl,
					$values ) );
		}
		$li->appendChild( $ul );
	}

	return $li;
}





######################################################################
1;

