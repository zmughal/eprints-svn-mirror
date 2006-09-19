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
			
		my $values = $self->{dataobj}->get_value( "subjects" );
		foreach my $s ( @$values )
		{
			$vals{$s} = 1;
		}
		
		my @out = keys %vals;
		$self->{dataobj}->set_value( "subjects", \@out );
		$self->{dataobj}->commit;
	}

	if( $ibutton =~ /^(.+)_remove$/ )
	{
		my $subject = $1;
		my %vals = ();
		
		my $values = $self->{dataobj}->get_value( "subjects" );
		foreach my $s ( @$values )
		{
			$vals{$s} = 1;
		}
		delete $vals{$subject};
		
		my @out = keys %vals;
		
		$self->{dataobj}->set_value( "subjects", \@out );
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

	my $top_subj = $field->get_top_subject( $session );

	# populate selected and expanded values	

	$self->{expanded} = {};
	$self->{selected} = {};
	my @values = @{$field->get_value( $eprint )};
	foreach my $subj_id ( @values )
	{
		$self->{selected}->{$subj_id} = 1;
		my $subj = $self->{subject_map}->{ $subj_id };
		my @paths = $subj->get_paths( $session, $top_subj );
		foreach my $path ( @paths )
		{
			foreach my $s ( @{$path} )
			{
				$self->{expanded}->{$s->get_id} = 1;
			}
		}
	}

	# render the tree
	
	$out->appendChild( $self->_render_subnodes( $top_subj, 0 ) );

	return $out;
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

	my $ul = $session->make_element( "ul" );
	
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

	my $prefix = $self->{prefix}."_".$node_id;
	
	my $out = $session->make_doc_fragment;
	my $desc = $subject->render_description;
	$out->appendChild( $desc );

	if( $subject->can_post )
	{
		if( $self->{selected}->{$node_id} )
		{
			my $rem_button = $session->make_element( "input", 
				class=> "ep_form_action_button",
				type => "submit",
				name => "_internal_".$prefix."_remove",
				value => "Remove" );
			$out->appendChild( $session->make_text( " " ) );
			$out->appendChild( $rem_button ); 
		}
		else
		{
			my $add_button = $session->make_element( "input", 
				class=> "ep_form_action_button",
				type => "submit",
				name => "_internal_".$prefix."_add",
				value => "Add" );
			$out->appendChild( $session->make_text( " " ) );
			$out->appendChild( $add_button ); 
		}
	}

	$out->appendChild( $self->_render_subnodes( $subject, $depth ) );
	return $out;
	
#	my $children_div = $session->make_element( "div", id => $pre );
#	
#	if( $depth > 0 )
#	{
#		my $div = $session->make_element( "div", class => "tree_node", id => $self->{prefix}."_node_".$root_id );
#		
#		# Decide on the state of the root node.
#		# 1 = expanded, 0 = contracted
#		
#		my $root_expanded = 0;
#		
#		# By default, expand everything up to visdepth and everything
#		# that is expanded (by being a value).
#		if( $depth < $self->{visdepth} || $expanded->{$root_id} )
#		{
#			$root_expanded = 1;
#		}
#		else
#		{
#			$root_expanded = 0;
#		}
#	
#
#		my $desc = $subject->render_description;
#		
#		if( $n_kids != 0 )
#		{
#			my $dots = $session->make_element( "span", id => $pre."_dots" );
#			$dots->appendChild( $session->html_phrase( "lib/extras:subject_browser_expandable" ) );
#			my $a_toggle = $session->make_element( "a", id => "${pre}_toggle", href=>"#" );
#
#			if( $root_expanded )
#			{
#				# Expanded, so show the content and hide the '...'
#				$dots->setAttribute( "style", "display: none" );
#				$a_toggle->setAttribute( "onClick"=>"EPJS_toggle('$pre',true,'inline');EPJS_toggle('${pre}_dots',false,'inline');return false" ); 
#			}
#			else
#			{
#				# Contracted, so hide the content  (show the '...')
#				#$children_div->setAttribute( "style", "display: none" );
#				$children_div->setAttribute( "class", "ep_no_js" );
#				$a_toggle->setAttribute( "onClick"=>"EPJS_toggle('$pre',false,'inline');EPJS_toggle('${pre}_dots',true,'inline');return false" ); 
#			}
#
#			
#			
#			
#			$a_toggle->appendChild( $desc );
#			$div->appendChild( $a_toggle );
#			$div->appendChild( $dots );
#		}
#		else
#		{	
#			$div->appendChild( $desc );
#		}
#		
#		$div->appendChild( $session->make_text( " " ) );
#		
#		if( $selected->{$root_id} )
#		{
#			$div->setAttribute( "class", "tree_node_selected" );
#		}
#		
#	}
	

	
	# Then append any children

	return $out;
}

1;
