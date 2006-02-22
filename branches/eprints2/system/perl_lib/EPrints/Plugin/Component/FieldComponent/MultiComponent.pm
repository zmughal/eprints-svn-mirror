package EPrints::Plugin::Component::FieldComponent::MultiComponent;

use EPrints::Plugin::Component::FieldComponent;

@ISA = ( "EPrints::Plugin::Component::FieldComponent" );

use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "MultiComponent";
	$self->{visible} = "all";

	return $self;
}

sub render
{
	my( $self, $defobj, $params ) = @_;

	my $session = $params->{session};

	my $user_ds = $session->get_repository->get_dataset( "eprint" );
	
	my $helpf = $session->make_doc_fragment;
	my $table = $session->make_element( "table" );
	my $tbody = $session->make_element( "tbody", class => "sidetable" );
	$table->appendChild( $tbody );
	my ($th, $tr, $td);
	foreach my $comp ( @{$self->{components}} )
	{
		my $field = $comp->{field};
	    my $metafield = $user_ds->get_field( $field );
		
	#	foreach my $key ( keys %$comp )
	#	{
	#		print STDERR "Want to set property $key\n";
	#		$metafield->set_property( $key, $comp->{$key} );	
	#	}
		$tr = $session->make_element( "tr" );
		
		# Get the field and its value/default
		my $value;
		if( $params->{eprint} )
		{
			$value = $params->{eprint}->get_value( $field );
		}
		else
		{
			$value = $params->{default};
		}
		
		# Get relevant info
		my $help = $metafield->render_help( $session, $metafield->get_type() );
		

		# Append help information
		
		my $fdiv = $session->make_element( "div", class => "field" );
		my $ddiv = $session->make_element( "p", class => "desc" );
		$fdiv->appendChild( $metafield->render_name( $session ) );
		$helpf->appendChild( $fdiv );
		$ddiv->appendChild( $help );
		$helpf->appendChild( $ddiv );
		
		# Append field
		$th = $session->make_element( "th" );
		$th->appendChild( $metafield->render_name( $session ) );
		$td = $session->make_element( "td" );
		$td->appendChild( $self->render_field( $session, $metafield, $value ) );
		$tr->appendChild( $th );
		$tr->appendChild( $td );
		$tbody->appendChild( $tr );
	}

	# Get the shell
	my $outer = $self->render_shell(
		session => $session,
		title => $session->make_text( "Some Title" ),
		help => $helpf,
		req => 0,
		name => "sometest" );
	$outer->appendChild( $table );
	return $outer;
}

1;





