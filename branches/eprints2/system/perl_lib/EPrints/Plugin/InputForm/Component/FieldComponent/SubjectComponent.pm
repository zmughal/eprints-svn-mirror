package EPrints::Plugin::InputForm::Component::FieldComponent::SubjectComponent;

use EPrints;
use EPrints::Plugin::InputForm::Component::FieldComponent;
@ISA = ( "EPrints::Plugin::InputForm::Component::FieldComponent" );

use Time::HiRes qw(gettimeofday tv_interval);
use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );
	
	$self->{name} = "SubjectComponent";
	$self->{visible} = "all";
	$self->{visdepth} = 1;
	return $self;
}


sub update_from_form
{
	my( $self ) = @_;
	my $field = $self->{config}->{field};
#	my $value = $field->form_value( $self->{session} );
#	$self->{dataobj}->set_value( $field->{name}, $value );
}


sub render_help
{
	my( $self, $surround ) = @_;
	return $self->{session}->make_text( "Help goes here" );
}

sub _render_portion
{
	my( $self, $subject, $depth, $expanded, $selected ) = @_;

	my $session = $self->{session};
	
	my @children = $subject->children();
	my $n_kids = scalar @children;
	my $root_id = $subject->get_value( "subjectid" );
	
	my $out;
	$out = $session->make_doc_fragment;
	
	my $children_div = $session->make_element( "div", id => $self->{prefix}."_root_".$root_id );
	
	if( $depth > 0 )
	{
		my $div = $session->make_element( "div", class => "tree_node", id => $self->{prefix}."_node_".$root_id );
		
		# Decide on the state of the root node.
		# 1 = expanded, 0 = contracted
		
		my $root_state = 0;
		
		# By default, expand everything up to visdepth and everything
		# that is expanded (by being a value).
		if( $depth < $self->{visdepth} || $expanded->{$root_id} )
		{
			$root_state = 1;
		}
		else
		{
			$root_state = 0;
		}
		
		if( $n_kids != 0 )
		{
			my $pre = $self->{prefix}."_root_".$root_id;
			
			my $a_hide = $session->make_element( "a", 
				id => "${pre}_hide", 
				href=>"#", 
				onClick=>"Element.toggle('$pre');Element.toggle('${pre}_hide');Element.toggle('${pre}_show');return false" );
			
			my $hide = $session->make_element( "span", 
				class => "ep_js_only" );
			$hide->appendChild( $session->make_text( "-" ) );
			$a_hide->appendChild( $hide ); 
			
			my $a_show = $session->make_element( "a", 
				id => "${pre}_show", 
				href=>"#", 
				onClick=>"Element.toggle('$pre');Element.toggle('${pre}_hide');Element.toggle('${pre}_show');return false" ); 
				
			my $show = $session->make_element( "span", 
				class => "ep_js_only" );
			$show->appendChild( $session->make_text( "+" ) );
			$a_show->appendChild( $show ); 

			if( $root_state == 1 )
			{
				# Expanded, so show the content and hide the '+'
				$a_show->setAttribute( "style", "display: none" );
			}
			else
			{
				# Contracted, so hide the content and hide the '-'
				$a_hide->setAttribute( "style", "display: none" );
				$children_div->setAttribute( "style", "display: none" );
				$children_div->setAttribute( "class", "ep_no_js" );
			}
			
			$div->appendChild( $a_hide );
			$div->appendChild( $a_show );
			$div->appendChild( $session->make_text( " " ) );
		}
		
		if( $selected->{$root_id} )
		{
			$div->setAttribute( "class", "tree_node_selected" );
		}

		$div->appendChild( $subject->render_description ); 
		if( $subject->can_post )
		{
			if( $selected->{$root_id} )
			{
				$div->appendChild( $session->make_text( " [remove]" ) );
			}
			else
			{
				$div->appendChild( $session->make_text( " [add]" ) );
			}
		}
		$out->appendChild( $div );
	}
	

	
	# Then append any children

	if( $n_kids != 0 )
	{
		my $div2;
		foreach my $child ( @children )
		{
			$div2 = $session->make_element( "div", class => "tree_portion" );
			$div2->appendChild( $self->_render_portion( $child, $depth+1, $expanded, $selected ) );
			$children_div->appendChild( $div2 );
		}
		$out->appendChild( $children_div );
	}

	return $out;
}

sub render_content
{
	my( $self, $surround ) = @_;

	my $session = $self->{session};
	my $field = $self->{config}->{field};
	my $eprint = $self->{workflow}->{item};



	my $out = $self->{session}->make_element( "div", class => "wf_subjectcomponent" );

	my $top_subj = $field->get_top_subject( $session );
my $time = [gettimeofday()];
	
	my %expanded = ();
	my %selected = ();
	my @values = @{$field->get_value( $eprint )};
	foreach my $subj_id ( @values )
	{
		$selected{$subj_id} = 1;
		my $subj = new EPrints::DataObj::Subject( $session, $subj_id );
		my @paths = $subj->get_paths( $session, $top_subj );
		foreach my $path ( @paths )
		{
			foreach my $s ( @{$path} )
			{
				$expanded{$s->get_id} = 1;
			}
		}
	}
my $elapsed = tv_interval($time);
print STDERR "Default paths: $elapsed\n";
$time = [gettimeofday()];
	
	$out->appendChild( $self->_render_portion( $top_subj, 0, \%expanded, \%selected ) );

$elapsed = tv_interval($time);
print STDERR "Render: $elapsed\n";
	

	return $out;
}

sub render_title
{
	my( $self, $surround ) = @_;
	return $self->{session}->html_phrase( "lib/submissionform:title_fileview" );	
}

sub is_required
{
	my( $self ) = @_;
	return 1;
}

1;





