package EPrints::Workflow::Stage;

sub new
{
	my( $class, $stage, $workflow ) = @_;
	my $self = {};
	bless $self, $class;

	$self->{workflow} = $workflow;
	$self->{session} = $workflow->{session};
	$self->{item} = $workflow->{item};
	$self->{repository} = $self->{session}->get_repository;

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
			my $surround = "Default";
			if( $stage_node->hasAttribute( "surround" ) )
			{
				$surround = $stage_node->getAttribute( "surround" );
			}
			# Grab any values inside
			$params{type} = $type;
			print STDERR "Create with type [$type]\n";
			my $class = $self->{repository}->plugin_class( "InputForm::Component::$type" );
			if( !defined $class )
			{
				print STDERR "Using placeholder for $type\n";
				$class = $self->{repository}->plugin_class( "InputForm::Component::PlaceHolder" );
				$params{name} = $type;
			}
			if( defined $class )
			{
				my $surround_obj = $self->{session}->plugin( "InputForm::Surround::$surround" );
				if( !defined $surround_obj )
				{
					$surround_obj = $self->{session}->plugin( "InputForm::Surround::Default" ); 
				}
				
				my $plugin = $class->new( 
					session=>$self->{session}, 
					xml_config=>$stage_node, 
					dataobj=>$self->{item}, 
					workflow=>$self->{workflow}, 
					surround=>$surround_obj );
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

sub validate
{
	my( $self, $session ) = @_;

	return 1;
}

sub render
{
	my( $self, $session, $workflow ) = @_;


	my $dom = $session->make_doc_fragment();

	foreach my $component (@{$self->{components}})
	{
		my $div;
		my $surround;
		
		$div = $session->make_element(
			"div",
			class => "formfieldinput",
			id => "inputfield_".$params{field} );
		$div->appendChild( $component->{surround}->render( $component, $session ) );
		$dom->appendChild( $div );
	}

#  $form->appendChild( $session->render_action_buttons( %$submit_buttons ) ); 
  
	return $dom;
}

1;
