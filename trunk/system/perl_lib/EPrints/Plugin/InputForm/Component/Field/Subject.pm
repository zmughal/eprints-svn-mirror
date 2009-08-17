package EPrints::Plugin::InputForm::Component::Field::Subject;

use EPrints;
use EPrints::Plugin::InputForm::Component::Field;
@ISA = ( "EPrints::Plugin::InputForm::Component::Field" );

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
	my( $self, $processor ) = @_;
	my $field = $self->{config}->{field};

	my $ibutton = $self->get_internal_button;
	if( $ibutton =~ /^(.+)_add$/ )
	{
		my $subject = $1;
		my $value;
		if( $field->get_property( "multiple" ) )
		{
			my %vals = ();

			my $values = $self->{dataobj}->get_value( $field->get_name );
			foreach my $s ( @$values, $subject )
			{
				$vals{$s} = 1;
			}
			
			$value = [sort keys %vals];
		}
		else
		{
			$value = $subject;
		}
		$self->{dataobj}->set_value( $field->get_name, $value );
		$self->{dataobj}->commit;
	}
	
	if( $ibutton =~ /^(.+)_remove$/ )
	{
		my $subject = $1;
		my $value;
		if( $field->get_property( "multiple" ) )
		{
			my %vals = ();
			
			my $values = $self->{dataobj}->get_value( $field->get_name );
			foreach my $s ( @$values )
			{
				$vals{$s} = 1;
			}
			delete $vals{$subject};
			
			$value = [sort keys %vals];
		}
		else
		{
			$value = undef;
		}
		$self->{dataobj}->set_value( $field->get_name, $value );
		$self->{dataobj}->commit;
	}

	return;
}



sub render_content
{
	my( $self, $surround ) = @_;

	my $handle = $self->{handle};
	my $field = $self->{config}->{field};
	my $eprint = $self->{workflow}->{item};

	( $self->{subject_map}, $self->{reverse_map} ) = EPrints::DataObj::Subject::get_all( $handle );

	my $out = $self->{handle}->make_element( "div" );

	$self->{top_subj} = $field->get_top_subject( $handle );

	# populate selected and expanded values	

	$self->{expanded} = {};
	$self->{selected} = {};
	my @values;
	if( $field->get_property( "multiple" ) )
	{
		@values = @{$field->get_value( $eprint )};
	}
	elsif( $eprint->is_set( $field->get_name ) )
	{
		push @values, $field->get_value( $eprint );
	}
	foreach my $subj_id ( @values )
	{
		$self->{selected}->{$subj_id} = 1;
		my $subj = $self->{subject_map}->{ $subj_id };
		next if !defined $subj;
		my @paths = $subj->get_paths( $handle, $self->{top_subj} );
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

	$self->{search} = undef;
	
	if( $handle->param( $self->{prefix}."_searchstore" ) )
	{
		$self->{search} = $handle->param( $self->{prefix}."_searchstore" );
	}

	my $ibutton = $handle->param( $self->{prefix}."_action" );
	$ibutton = "" unless defined $ibutton;

	if( $ibutton eq "search" )
	{
		$self->{search} = $handle->param( $self->{prefix}."_searchtext" );
	}
	if( $ibutton eq "clear" )
	{
		delete $self->{search};
	}

	if( $self->{search} eq "" )
	{
		delete $self->{search};
	}
	
	$out->appendChild( $self->_render_search );
	
	if( $self->{search} )
	{
		my $search_store = $handle->render_hidden_field( 
			$self->{prefix}."_searchstore",
			$self->{search} );
		$out->appendChild( $search_store );
		
		my $results = $self->_do_search;
		
		if( !$results->count )
		{
			$out->appendChild( $self->html_phrase(
				"search_no_matches" ) );
		}
		else
		{
			my $whitelist = {};
			foreach my $subj ( $results->get_records )
			{
				foreach my $ancestor ( @{$subj->get_value( "ancestors" )} )
				{	
					$whitelist->{$ancestor} = 1;
				}
			}
			$out->appendChild( $self->_render_subnodes( $self->{top_subj}, 0, $whitelist ) );
		}
	}	
	else
	{	
		# render the treeI	
		$out->appendChild( $self->_render_subnodes( $self->{top_subj}, 0 ) );
	}


	return $out;
}

sub _do_search
{
	my( $self ) = @_;
	my $handle = $self->{handle};
	
	# Carry out search

	my $subject_ds = $handle->get_repository->get_dataset( "subject" );
	my $searchexp = new EPrints::Search(
		handle =>$handle,
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

	return $searchexp->perform_search;
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

	my $handle = $self->{handle};
	my $table = $handle->make_element( "table", class=>$params{table_class} );
	my @subjects = @{$params{subjects}};
	if( scalar @subjects )
	{
		my $first = 1;
		foreach my $subject ( @subjects )
		{
			next if( !defined $subject ); # need a warning?

			my $subject_id = $subject->get_id();
			next if ( $params{hide_selected} && $self->{selected}->{ $subject_id } );
			my $prefix = $self->{prefix}."_".$subject_id;
			my $tr = $handle->make_element( "tr" );
			
			my $td1 = $handle->make_element( "td" );
			my $remove_button = $handle->render_button(
				class=> "ep_subjectinput_remove_button",
				name => "_internal_".$prefix."_".$params{button_id},
				value => $params{button_text} );
			$td1->appendChild( $remove_button );
			my $td2 = $handle->make_element( "td" );
			$td2->appendChild( $subject->render_description );
			
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
	my $handle = $self->{handle};
	my $field = $self->{config}->{field};
	my $bar = $self->html_phrase(
		$field->get_name."_search_bar",
		input=>$handle->render_noenter_input_field( 
			class=>"ep_form_text",
			name=>$prefix."_searchtext", 
			type=>"text", 
			value=>$self->{search},
			onKeyPress=>"return EPJS_enter_click( event, '_internal_".$prefix."_search' )" ),
		search_button=>$handle->render_button( 
			name=>"_internal_".$prefix."_search",
			id=>"_internal_".$prefix."_search",
			value=>$self->phrase( "search_search_button" ) ),
		clear_button=>$handle->render_button(
			name=>"_internal_".$prefix."_clear",
			value=>$self->phrase( "search_clear_button" ) ),
		);
	return $bar;
}


sub _render_subnodes
{
	my( $self, $subject, $depth, $whitelist ) = @_;

	my $handle = $self->{handle};

	my $node_id = $subject->get_value( "subjectid" );

	my @children = ();
	if( defined $self->{reverse_map}->{$node_id} )
	{
		@children = @{$self->{reverse_map}->{$node_id}};
	}

	my @filteredchildren;
	if( defined $whitelist )
	{
		foreach( @children )
		{
			next unless $whitelist->{$_->get_value( "subjectid" )};
			push @filteredchildren, $_;
		}
	}
	else
	{
		@filteredchildren=@children;
	}
	if( scalar @filteredchildren == 0 ) { return $handle->make_doc_fragment; }

	my $ul = $handle->make_element( "ul", class=>"ep_subjectinput_subjects" );
	
	foreach my $child ( @filteredchildren )
	{
		my $li = $handle->make_element( "li" );
		$li->appendChild( $self->_render_subnode( $child, $depth+1, $whitelist ) );
		$ul->appendChild( $li );
	}
	
	return $ul;
}


sub _render_subnode
{
	my( $self, $subject, $depth, $whitelist ) = @_;

	my $handle = $self->{handle};

	my $node_id = $subject->get_value( "subjectid" );

#	if( defined $whitelist && !$whitelist->{$node_id} )
#	{
#		return $self->{handle}->make_doc_fragment;
#	}

	my $has_kids = 0;
	$has_kids = 1 if( defined $self->{reverse_map}->{$node_id} );

	my $expanded = 0;
	$expanded = 1 if( $depth < $self->{visdepth} );
	$expanded = 1 if( defined $whitelist && $whitelist->{$node_id} );
#	$expanded = 1 if( $self->{expanded}->{$node_id} );
	$expanded = 0 if( !$has_kids );

	my $prefix = $self->{prefix}."_".$node_id;
	my $id = "id".$handle->get_next_id;
	
	my $r_node = $handle->make_doc_fragment;

	my $desc = $handle->make_element( "span" );
	$desc->appendChild( $subject->render_description );
	$r_node->appendChild( $desc );
	
	my @classes = (); 
	
	if( $self->{selected}->{$node_id} )
	{
		push @classes, "ep_subjectinput_selected";
	}

	my $imagesurl = $handle->get_repository->get_conf( "rel_path" );

	if( $has_kids && !defined $whitelist )
	{
		my $toggle;
		$toggle = $self->{handle}->make_element( "a", href=>"#", class=>"ep_only_js ep_subjectinput_toggle" );

		my $hide = $self->{handle}->make_element( "span", id=>$id."_hide" );
		$hide->appendChild( $self->{handle}->make_element( "img", alt=>"-", src=>"$imagesurl/style/images/minus.png", border=>0 ) );
		$hide->appendChild( $self->{handle}->make_text( " " ) );
		$hide->appendChild( $subject->render_description );
		$hide->setAttribute( "class", join( " ", @classes ) );
		$toggle->appendChild( $hide );

		my $show = $self->{handle}->make_element( "span", id=>$id."_show" );
		$show->appendChild( $self->{handle}->make_element( "img", alt=>"+", src=>"$imagesurl/style/images/plus.png", border=>0 ) );
		$show->appendChild( $self->{handle}->make_text( " " ) );
		$show->appendChild( $subject->render_description );
		$show->setAttribute( "class", join( " ", @classes ) );
		$toggle->appendChild( $show );

		push @classes, "ep_no_js";
		if( $expanded )
		{
			$toggle->setAttribute( "onclick", "EPJS_blur(event); EPJS_toggleSlide('${id}_kids',true,'block');EPJS_toggle_type('${id}_hide',true,'inline');EPJS_toggle_type('${id}_show',false,'inline');return false" );
			$show->setAttribute( "style", "display:none" );
		}
		else # not expanded
		{
			$toggle->setAttribute( "onclick", "EPJS_blur(event); EPJS_toggleSlide('${id}_kids',false,'block');EPJS_toggle_type('${id}_hide',false,'inline');EPJS_toggle_type('${id}_show',true,'inline');return false" );
			$hide->setAttribute( "style", "display:none" );
		}

		$r_node->appendChild( $toggle );
	}
	$desc->setAttribute( "class", join( " ", @classes ) );
	
	if( !$self->{selected}->{$node_id} && (!defined $whitelist || $whitelist->{$node_id}) )
	{
		if( $subject->can_post )
		{
			my $add_button = $handle->render_button(
				class=> "ep_subjectinput_add_button",
				name => "_internal_".$prefix."_add",
				value => $self->phrase( "add" ) );
			my $r_node_tmp = $handle->make_doc_fragment;
			$r_node_tmp->appendChild( $add_button ); 
			$r_node_tmp->appendChild( $handle->make_text( " " ) );
			$r_node_tmp->appendChild( $r_node ); 
			$r_node = $r_node_tmp;
		}
	}

	if( $has_kids )
	{
		my $div = $handle->make_element( "div", id => $id."_kids" );
		my $div_inner = $handle->make_element( "div", id => $id."_kids_inner" );
		if( !$expanded && !defined $whitelist ) 
		{ 
			$div->setAttribute( "class", "ep_no_js" ); 
		}
		$div_inner->appendChild( $self->_render_subnodes( $subject, $depth, $whitelist ) );
		$div->appendChild( $div_inner );
		$r_node->appendChild( $div );
	}


	return $r_node;
}
	
sub get_state_params
{
	my( $self ) = @_;

	my $params = "";
	foreach my $id ( 
 		$self->{prefix}."_searchstore",
		$self->{prefix}."_searchtext",
	)
	{
		my $v = $self->{handle}->param( $id );
		next unless defined $v;
		$params.= "&$id=$v";
	}

	if( defined $self->{handle}->param( "_internal_".$self->{prefix}."_search" ) )
	{
		$params .= "&".$self->{prefix}."_action=search";
	}
	elsif( defined $self->{handle}->param( "_internal_".$self->{prefix}."_clear" ) )
	{
		$params .= "&".$self->{prefix}."_action=clear";
	}

	return $params;	
}

1;
