package EPrints::Workflow::Stage;

sub new
{
	my( $class, $stage, $session, $item ) = @_;
	my $self = {};
	bless $self, $class;

	$self->{session} = $session;
	$self->{item} = $item;
	$self->{repository} = $session->get_repository;

	unless( $stage->hasAttribute( "name" ) )
	{
		EPrints::abort( "Workflow stage with no name attribute." );
	}

	# Creating a new stage
	$self->{name} = $stage->getAttribute("name");
	$self->_read_components( $stage->getChildNodes );

	return $self;
}

	

sub _read_components
{
	my( $self, @stage_nodes ) = @_;
	print STDERR "Reading components\n"; 

	$self->{components} = [];
	
	foreach my $stage_node ( @stage_nodes )
	{
		my $name = $stage_node->getNodeName;
		if( $name eq "component" )
		{
			# Pull out the type
			my $type = "FieldComponent";
			if( $stage_node->hasAttribute( "type" ) )
			{
				$type = $stage_node->getAttribute( "type" );
			}
			# Grab any values inside
			$params{type} = $type;
			my $class = $self->{repository}->plugin_class( "InputForm::Component::$type" );
			if( !defined $class )
			{
				print STDERR "Using placeholder for $type\n";
				$class = $self->{repository}->plugin_class( "InputForm::Component::FieldComponent::PlaceHolder" );
				$params{name} = $type;
			}
			if( defined $class )
			{
				my $plugin = $class->new( session=>$self->{session}, xml_config=>$stage_node, dataobj=>$self->{item} );
				push @{$self->{components}}, $plugin;
			}
		}
		elsif( $name eq "title" )
		{
			$self->{title} = $stage_node->getFirstChild->getNodeValue;
		}
		elsif( $name eq "short-title" )
		{
			$self->{short_title} = $stage_node->getFirstChild->getNodeValue;
		}
	}
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

sub get_components
{
	my( $self ) = @_;
	return @{$self->{components}};
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
      

	$form->appendChild( $session->render_action_buttons( %$submit_buttons ) );

	foreach my $component (@{$self->{components}})
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
		$div->appendChild( $component->render( undef, \%params ) );
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
