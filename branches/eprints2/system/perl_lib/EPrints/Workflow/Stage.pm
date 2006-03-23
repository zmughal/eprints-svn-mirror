package EPrints::Workflow::Stage;

sub new
{
	my( $class, $stage, $repository ) = @_;
	my $self = {};
	bless $self, $class;

	$self->{repository} = $repository;

	if( $stage->hasAttribute( "name" ) )
	{
		# Creating a new stage
		$self->{name} = $stage->getAttribute("name");
		$self->{components} = $self->_read_components( $stage->getChildNodes );
	}
	return $self;
}

sub _read_params
{
	my( $self, $root ) = @_;
	my $out = {};

	foreach my $comp_node ( $root->getChildNodes )
	{
			return $comp_node->toString if EPrints::XML::is_dom( $comp_node, "Text" );

			my $elname = $comp_node->getNodeName;
			my $field_name = $comp_node->getAttribute( "name" );
			my $field_value = undef;
			if( $elname eq "wf:value" )
			{
				$field_value = $comp_node->getFirstChild->getNodeValue;
			}
			elsif( $elname eq "wf:array" )
			{
				$field_value = [];
				foreach my $val_node ( $comp_node->getChildNodes )
				{
					push @$field_value, $self->_read_params( $val_node );
				}
			}
			$out->{$field_name} = $field_value;
	}
	return $out;
}
	

sub _read_components
{
	my( $self, @stage_nodes ) = @_;
	print STDERR "Reading components\n"; 
	my $component_list = [];
	
	foreach my $stage_node ( @stage_nodes )
	{
		my $name = $stage_node->getNodeName;
		if( $name eq "wf:component" )
		{
			# Pull out the type
			my $type = $stage_node->getAttribute( "type" );
			# Grab any values inside
			my %params = %{$self->_read_params( $stage_node )};
			$params{type} = $type;
			my $class = $self->{repository}->plugin_class( $type );
			if( !defined $class )
			{
				print STDERR "Using placeholder for $type\n";
				$class = $self->{repository}->plugin_class( "component/placeholder" );
				$params{name} = $type;
			}
			if( defined $class )
			{
				my $plugin = $class->new( %params );
				push @$component_list, $plugin;
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
	return $component_list;
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
