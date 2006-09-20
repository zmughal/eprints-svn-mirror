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

	my $expanded = 0;
	$expanded = 1 if( $depth < $self->{visdepth} );
	$expanded = 1 if( $self->{expanded}->{$node_id} );
	$expanded = 0 if( !$has_kids );

	my $prefix = $self->{prefix}."_".$node_id;
	
	my $r_node = $session->make_doc_fragment;

	my $desc = $session->make_element( "span" );
	$desc->appendChild( $subject->render_description );
	$r_node->appendChild( $desc );

	if( $has_kids )
	{
		my $toggle;
		if( $expanded )
		{
			$toggle = $self->{session}->make_element( "a", onClick => "EPJS_toggle('${prefix}_kids',true,'block');EPJS_toggle('${prefix}_hide',true,'inline');EPJS_toggle('${prefix}_show',false,'inline');return false", href=>"#", class=>"ep_only_js" );
	
			my $hide = $self->{session}->make_element( "span", id=>$prefix."_hide" );
			$hide->appendChild( $self->{session}->make_element( "img", alt=>"-", src=>"/images/style/minus.png", border=>0 ) );
			$hide->appendChild( $self->{session}->make_text( " " ) );
			$hide->appendChild( $subject->render_description );
			$toggle->appendChild( $hide );
	
			my $show = $self->{session}->make_element( "span", id=>$prefix."_show", style=>"display:none" );
			$show->appendChild( $self->{session}->make_element( "img", alt=>"+", src=>"/images/style/plus.png", border=>0 ) );
			$show->appendChild( $self->{session}->make_text( " " ) );
			$show->appendChild( $subject->render_description );
			$toggle->appendChild( $show );

			$desc->setAttribute( "class", "ep_no_js" );
		}
		else # not expanded
		{
			$toggle = $self->{session}->make_element( "a", onClick => "EPJS_toggle('${prefix}_kids',false,'block');EPJS_toggle('${prefix}_hide',false,'inline');EPJS_toggle('${prefix}_show',true,'inline');return false", href=>"#", class=>"ep_only_js" );
	
			my $hide = $self->{session}->make_element( "span", id=>$prefix."_hide", style=>"display:none" );
			$hide->appendChild( $self->{session}->make_element( "img", alt=>"-", src=>"/images/style/minus.png", border=>0 ) );
			$hide->appendChild( $self->{session}->make_text( " " ) );
			$hide->appendChild( $subject->render_description );
			$toggle->appendChild( $hide );
	
			my $show = $self->{session}->make_element( "span", id=>$prefix."_show" );
			$show->appendChild( $self->{session}->make_element( "img", alt=>"+", src=>"/images/style/plus.png", border=>0 ) );
			$show->appendChild( $self->{session}->make_text( " " ) );
			$show->appendChild( $subject->render_description );
			$toggle->appendChild( $show );

			$desc->setAttribute( "class", "ep_no_js" );
		}

		$r_node->appendChild( $toggle );
	}

	if( $subject->can_post )
	{
		if( $self->{selected}->{$node_id} )
		{
			my $rem_button = $session->make_element( "input", 
				class=> "ep_form_action_button",
				type => "submit",
				name => "_internal_".$prefix."_remove",
				value => "Remove" );
			$r_node->appendChild( $session->make_text( " " ) );
			$r_node->appendChild( $rem_button ); 
		}
		else
		{
			my $add_button = $session->make_element( "input", 
				class=> "ep_form_action_button",
				type => "submit",
				name => "_internal_".$prefix."_add",
				value => "Add" );
			$r_node->appendChild( $session->make_text( " " ) );
			$r_node->appendChild( $add_button ); 
		}
	}

	if( $has_kids )
	{
		my $div = $session->make_element( "div", id => $prefix."_kids" );
		if( !$expanded ) 
		{ 
			$div->setAttribute( "class", "ep_no_js" ); 
		}
		$div->appendChild( $self->_render_subnodes( $subject, $depth ) );
		$r_node->appendChild( $div );
	}

	return $r_node;
}
	
1;
