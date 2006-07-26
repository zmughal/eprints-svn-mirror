package EPrints::Plugin::InputForm::Component::Field::Subject;

use EPrints;
use EPrints::Plugin::InputForm::Component::Field;
@ISA = ( "EPrints::Plugin::InputForm::Component::Field" );

use Time::HiRes qw(gettimeofday tv_interval);
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

	my %params = $self->params();

	foreach my $param ( keys %params )
	{
		if( $param =~ /^root_(.+)_add$/ )
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
		elsif( $param =~ /^root_(.+)_remove$/ )
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
	}
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
	my $pre = $self->{prefix}."_root_".$root_id;
	
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
	

		my $desc = $subject->render_description;
		
		if( $n_kids != 0 )
		{
			
			my $a_toggle = $session->make_element( "a", 
				id => "${pre}_toggle", 
				href=>"#", 
				onClick=>"Element.toggle('$pre');Element.toggle('${pre}_dots');return false" ); 
			
			my $dots = $session->make_element( "span", id => $pre."_dots" );
			$dots->appendChild( $session->html_phrase( "lib/extras:subject_browser_expandable" ) );
			
			if( $root_state == 1 )
			{
				# Expanded, so show the content and hide the '...'
				$dots->setAttribute( "style", "display: none" );
			}
			else
			{
				# Contracted, so hide the content 
				$children_div->setAttribute( "style", "display: none" );
				$children_div->setAttribute( "class", "ep_no_js" );
			}

			$a_toggle->appendChild( $desc );
			$div->appendChild( $a_toggle );
			$div->appendChild( $dots );
		}
		else
		{	
			$div->appendChild( $desc );
		}
		
		$div->appendChild( $session->make_text( " " ) );
		
		if( $selected->{$root_id} )
		{
			$div->setAttribute( "class", "tree_node_selected" );
		}
		
		if( $subject->can_post )
		{
			if( $selected->{$root_id} )
			{
				my $rem_button = $session->make_element( "input", 
					type => "submit",
					name => "_internal_".$pre."_remove",
					value => "Remove" );
				$div->appendChild( $rem_button ); 
			}
			else
			{
				my $add_button = $session->make_element( "input", 
					type => "submit",
					name => "_internal_".$pre."_add",
					value => "Add" );
				$div->appendChild( $add_button ); 
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





