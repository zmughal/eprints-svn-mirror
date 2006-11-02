package EPrints::Plugin::InputForm::Component::Field::Subject;

use EPrints;
use EPrints::Plugin::InputForm::Component::Field;
@ISA = ( "EPrints::Plugin::InputForm::Component::Field" );

use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );
	
	$self->{name} = "Subject";
	$self->{visible} = "all";
	$self->{visdepth} = 1;
	return $self;
}


sub update_from_form
{
	my( $self ) = @_;
	my $field = $self->{config}->{field};

	my $ibutton = $self->get_internal_button;
	if( $ibutton =~ /^(.+)_add$/ )
	{
		my $subject = $1;
		my %vals = ();
		$vals{$subject} = 1;
			
		my $values = $self->{dataobj}->get_value( $field->get_name );
		foreach my $s ( @$values )
		{
			$vals{$s} = 1;
		}
		
		my @out = keys %vals;
		$self->{dataobj}->set_value( $field->get_name, \@out );
		$self->{dataobj}->commit;
	}
	
	if( $ibutton =~ /^(.+)_remove$/ )
	{
		my $subject = $1;
		my %vals = ();
		
		my $values = $self->{dataobj}->get_value( $field->get_name );
		foreach my $s ( @$values )
		{
			$vals{$s} = 1;
		}
		delete $vals{$subject};
		
		my @out = keys %vals;
		
		$self->{dataobj}->set_value( $field->get_name, \@out );
		$self->{dataobj}->commit;
	}

	return ();
}



sub render_content
{
	my( $self, $surround ) = @_;

	my $session = $self->{session};
	my $field = $self->{config}->{field};
	my $eprint = $self->{workflow}->{item};

	( $self->{subject_map}, $self->{reverse_map} ) = EPrints::DataObj::Subject::get_all( $session );

	my $out = $self->{session}->make_element( "div" );

	$self->{top_subj} = $field->get_top_subject( $session );

	# populate selected and expanded values	

	$self->{expanded} = {};
	$self->{selected} = {};
	my @values = @{$field->get_value( $eprint )};
	foreach my $subj_id ( @values )
	{
		$self->{selected}->{$subj_id} = 1;
		my $subj = $self->{subject_map}->{ $subj_id };
		my @paths = $subj->get_paths( $session, $self->{top_subj} );
		foreach my $path ( @paths )
		{
			foreach my $s ( @{$path} )
			{
				$self->{expanded}->{$s->get_id} = 1;
			}
		}
	}

	my @sels = ();
	foreach my $subject_id ( sort keys %{$self->{selected}} )
	{
		push @sels, $self->{subject_map}->{ $subject_id };
	}

	if( scalar @sels )
	{
		$out->appendChild( $self->_format_subjects(
			table_class => "ep_subjectinput_selections",
			subject_class => "ep_subjectinput_selected_subject",
			button_class => "ep_subjectinput_selected_remove",
			button_text => $self->phrase( "remove" ),
			button_id => "remove",
			subjects => \@sels ) );
	}
	
	# Render the search box

	$self->{search} = "";
	my $using_store = 0;
	my $clear = 0;
	
	if( $session->internal_button_pressed )
	{
		my $ibutton = $self->get_internal_button;
	
		if( $ibutton eq "clear" )
		{
			$clear = 1;
		}
		
		if( $ibutton eq "search" )
		{
			$self->{search} = $session->param( $self->{prefix}."_searchtext" );
			if( $self->{search} eq "" )
			{
				$clear = 1;
			}
		}
	}

	if( !$clear && !$self->{search} && $session->param( $self->{prefix}."_searchstore" ) )
	{
		$self->{search} = $session->param( $self->{prefix}."_searchstore" );
		$using_store = 1;
	}
	
	$out->appendChild( $self->_render_search );
	
	if( $self->{search} )
	{
		my $search_store = $session->render_hidden_field( 
			$self->{prefix}."_searchstore",
			$self->{search} );
		$out->appendChild( $search_store );
		
		my $num_results = $self->_do_search;
		
		# If we're using a stored search, don't show the results.
		if( !$using_store || $num_results > 0 )
		{
			$out->appendChild( $self->{results} );
		}
	}	
	
	# render the tree

	$out->appendChild( $self->_render_subnodes( $self->{top_subj}, 0 ) );

	return $out;
}

sub _do_search
{
	my( $self ) = @_;
	my $session = $self->{session};
	
	# Carry out search

	if( !$self->{search} )
	{
		$self->{results} = $self->html_phrase(
			"search_no_matches" );
		return 0;
	}

	my $subject_ds = $session->get_repository->get_dataset( "subject" );
	my $searchexp = new EPrints::Search(
		session=>$session,
		dataset=>$subject_ds );

	$searchexp->add_field(
	$subject_ds->get_field( "name" ),
		$self->{search},
		"IN",
		"ALL" );

	$searchexp->add_field(
		$subject_ds->get_field( "ancestors" ),
		$self->{top_subj}->get_id,
		"EQ" );

	my $result = $searchexp->perform_search;

	my @records = $result->get_records;
	$searchexp->dispose();
	if( !scalar @records )
	{
		$self->{results} = $self->html_phrase(
			"search_no_matches" );
		return 0;
	}

	$self->{results} = $self->_format_subjects(
		table_class => "ep_subjectinput_results",
		subject_class => "ep_subjectinput_results_subject",
		button_class => "ep_subjectinput_results_add",
		button_text => $self->phrase( "add" ),
		button_id => "add",
		hide_selected => 1,
		subjects => \@records );
	
	return( scalar @records );
}

# Params:
# table_class: Class for the table
# subject_class: Class for the subject cell
# button_class: Class for the button cell
# button_text: Text for the button
# button_id: postfix for the button name
# subjects: array of subjects
# hide_selected: If 1, hides any already selected subjects.

sub _format_subjects
{
	my( $self, %params ) = @_;

	my $session = $self->{session};
	my $table = $session->make_element( "table", class=>$params{table_class} );
	my @subjects = @{$params{subjects}};
	if( scalar @subjects )
	{
		my $first = 1;
		foreach my $subject ( @subjects )
		{
			my $subject_id = $subject->get_id();
			next if ( $params{hide_selected} && $self->{selected}->{ $subject_id } );
			my $prefix = $self->{prefix}."_".$subject_id;
			my $tr = $session->make_element( "tr" );
			
			my $td1 = $session->make_element( "td" );
			$td1->appendChild( $subject->render_description );
			my $td2 = $session->make_element( "td" );
			my $add_button = $session->make_element( "input", 
				class=> "ep_form_action_button",
				type => "submit",
				name => "_internal_".$prefix."_".$params{button_id},
				value => $params{button_text} );
			$td2->appendChild( $add_button );
			
			my @td1_attr = ( $params{subject_class} );
			my @td2_attr = ( $params{button_class} );
			if( $first )
			{
				push @td1_attr, "ep_first";
				push @td2_attr, "ep_first";
				$first = 0;
			}
			$td1->setAttribute( "class", join(" ", @td1_attr ) );
			$td2->setAttribute( "class", join(" ", @td2_attr ) );
						
			$tr->appendChild( $td1 ); 
			$tr->appendChild( $td2 );
			
			$table->appendChild( $tr );
		}
	}
	return $table;
}

sub _render_search
{
	my( $self ) = @_;
	my $prefix = $self->{prefix};
	my $session = $self->{session};
	my $bar = $self->html_phrase(
		"search_bar",
		input=>$session->make_element( 
			"input", 
			name=>$prefix."_searchtext", 
			type=>"text", 
			value=>$self->{search} ),
		search_button=>$session->make_element( 
			"input", 
			type=>"submit", 
			name=>"_internal_".$prefix."_search",
			value=>$self->phrase( "search_search_button" ) ),
		clear_button=>$session->make_element(
			"input",
			type=>"submit",
			name=>"_internal_".$prefix."_clear",
			value=>$self->phrase( "search_clear_button" ) ),
		);
	return $bar;
}


sub _render_subnodes
{
	my( $self, $subject, $depth ) = @_;

	my $session = $self->{session};

	my $node_id = $subject->get_value( "subjectid" );

	my @children = ();
	if( defined $self->{reverse_map}->{$node_id} )
	{
		@children = @{$self->{reverse_map}->{$node_id}};
	}

	if( scalar @children == 0 ) { return $session->make_doc_fragment; }

	my $ul = $session->make_element( "ul", class=>"ep_subjectinput_subjects" );
	
	foreach my $child ( @children )
	{
		my $li = $session->make_element( "li" );
		$li->appendChild( $self->_render_subnode( $child, $depth+1 ) );
		$ul->appendChild( $li );
	}
	
	return $ul;
}


sub _render_subnode
{
	my( $self, $subject, $depth ) = @_;

	my $session = $self->{session};

	my $node_id = $subject->get_value( "subjectid" );

	my $has_kids = 0;
	$has_kids = 1 if( defined $self->{reverse_map}->{$node_id} );

	my $expanded = 0;
	$expanded = 1 if( $depth < $self->{visdepth} );
	$expanded = 1 if( $self->{expanded}->{$node_id} );
	$expanded = 0 if( !$has_kids );

	my $prefix = $self->{prefix}."_".$node_id;
	my $id = "id".$session->get_next_id;
	
	my $r_node = $session->make_doc_fragment;

	my $desc = $session->make_element( "span" );
	$desc->appendChild( $subject->render_description );
	$r_node->appendChild( $desc );
	
	my @classes = (); 
	
	if( $self->{selected}->{$node_id} )
	{
		push @classes, "ep_subjectinput_selected";
	}

	if( $has_kids )
	{
		my $toggle;
		$toggle = $self->{session}->make_element( "a", href=>"#", class=>"ep_only_js ep_subjectinput_toggle" );

		my $hide = $self->{session}->make_element( "span", id=>$id."_hide" );
		$hide->appendChild( $self->{session}->make_element( "img", alt=>"-", src=>"/style/images/minus.png", border=>0 ) );
		$hide->appendChild( $self->{session}->make_text( " " ) );
		$hide->appendChild( $subject->render_description );
		$hide->setAttribute( "class", join( " ", @classes ) );
		$toggle->appendChild( $hide );

		my $show = $self->{session}->make_element( "span", id=>$id."_show" );
		$show->appendChild( $self->{session}->make_element( "img", alt=>"+", src=>"/style/images/plus.png", border=>0 ) );
		$show->appendChild( $self->{session}->make_text( " " ) );
		$show->appendChild( $subject->render_description );
		$show->setAttribute( "class", join( " ", @classes ) );
		$toggle->appendChild( $show );

		push @classes, "ep_no_js";
		if( $expanded )
		{
			$toggle->setAttribute( "onClick", "EPJS_toggleSlide('${id}_kids',true,'block');EPJS_toggle('${id}_hide',true,'inline');EPJS_toggle('${id}_show',false,'inline');return false" );
			$show->setAttribute( "style", "display:none" );
		}
		else # not expanded
		{
			$toggle->setAttribute( "onClick", "EPJS_toggleSlide('${id}_kids',false,'block');EPJS_toggle('${id}_hide',false,'inline');EPJS_toggle('${id}_show',true,'inline');return false" );
			$hide->setAttribute( "style", "display:none" );
		}

		$r_node->appendChild( $toggle );
	}
	$desc->setAttribute( "class", join( " ", @classes ) );
	
	if( !$self->{selected}->{$node_id} )
	{
		if( $subject->can_post )
		{
			my $add_button = $session->make_element( "input", 
				class=> "ep_form_action_button",
				type => "submit",
				name => "_internal_".$prefix."_add",
				value => $self->phrase( "add" ) );
			$r_node->appendChild( $session->make_text( " " ) );
			$r_node->appendChild( $add_button ); 
		}
	}

	if( $has_kids )
	{
		my $div = $session->make_element( "div", id => $id."_kids" );
		my $div_inner = $session->make_element( "div", id => $id."_kids_inner" );
		if( !$expanded ) 
		{ 
			$div->setAttribute( "class", "ep_no_js" ); 
		}
		$div_inner->appendChild( $self->_render_subnodes( $subject, $depth ) );
		$div->appendChild( $div_inner );
		$r_node->appendChild( $div );
	}


	return $r_node;
}
	
1;
