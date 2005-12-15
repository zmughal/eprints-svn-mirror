package EPrints::Workflow::Stage;

use EPrints::Plugin;
sub new
{
	my( $class, $stage, $archive ) = @_;
	my $self = {};
	bless $self, $class;

	$self->{archive} = $archive;

	if( $stage->hasAttribute( "name" ) )
	{
		# Creating a new stage
		$self->{name} = $stage->getAttribute("name");
		$self->{controls} = $self->_read_controls( $stage->getChildNodes );
	}
	return $self;
}

sub _read_controls
{
	my( $self, @stage_nodes ) = @_;
	print STDERR "Reading controls\n"; 
	my $control_list = [];
	
	foreach my $stage_node ( @stage_nodes )
	{
		my $name = $stage_node->getNodeName;
		if( $name eq "wf:control" )
		{
			# Pull out the type
			my $type = $stage_node->getAttribute( "type" );
			# Grab any values inside
			my %params = ();
			$params{type} = $type;
			foreach my $control_node ( $stage_node->getChildNodes )
			{
				my $elname = $control_node->getNodeName;
				if( $elname eq "wf:value" )
				{
					my $valname = $control_node->getAttribute( "name" );
					my $valtext = $control_node->getFirstChild->getNodeValue;  
					$params{$valname} = $valtext;
				}
			}
			my $class = $self->{archive}->plugin_class( $type );
			if( !defined $class )
			{
				$class = $self->{archive}->plugin_class( "control/placeholder" );
				$params{name} = $type;
			}
			if( defined $class )
			{
				my $plugin = $class->new( %params );
				push @$control_list, $plugin;
			}
		}
		elsif( $name eq "wf:title" )
		{
			$self->{title} = $stage_node->getFirstChild->getNodeValue;
		}
		elsif( $name eq "wf:short-title" )
		{
			$self->{short_title} = $stage_node->getFirstChild->getNodeValue;
		}
	}
	return $control_list;
}

sub get_name
{
  my( $self ) = @_;
  return $self->{name};
}

sub get_title
{
  my( $self ) = @_;
  return $self->{title};
}


sub get_short_title
{
  my( $self ) = @_;
  return $self->{short_title};
}

sub render
{
  my( $self, $session, $workflow, $eprint ) = @_;
  my $page = $session->make_doc_fragment();

  my $form = $session->render_form( "post", $target );

  my $submit_buttons = {
    _order => [ "prev", "save", "next" ],
    _class => "submission_buttons",
    prev => $session->phrase(
      "lib/submissionform:action_prev" ),
      save => $session->phrase(
        "lib/submissionform:action_save" ),
      next => $session->phrase(
        "lib/submissionform:action_next" ) };

  my $hidden_fields = {
      stage => $self->get_name,
      pageid => $session->param( "pageid" ), 
      };
      

#  $form->appendChild( $session->render_action_buttons( %$submit_buttons ) );

  foreach my $control (@{$self->{controls}})
  {
    my $div;

    $div = $session->make_element(
      "div",
      class => "formfieldinput",
      id => "inputfield_".$params{field} );
	%params = ();
	$params{eprint} = $eprint if( defined $eprint);
	$params{workflow} = $workflow;
	$params{stage} = $self->{name};
	$params{session} = $session;
	$params{show_help} = 1;
    $div->appendChild( $control->render( undef, \%params ) );
    $form->appendChild( $div );
  }

  foreach (keys %$hidden_fields)
  {
    $form->appendChild( $session->render_hidden_field(
        $_,
        $hidden_fields->{$_} ) );
  }
        

#  $form->appendChild( $session->render_action_buttons( %$submit_buttons ) ); 
  
  return $form;
}

1;
