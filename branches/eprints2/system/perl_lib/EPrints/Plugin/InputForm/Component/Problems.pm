package EPrints::Plugin::InputForm::Component::Problems;

use EPrints::Plugin::InputForm::Component;

@ISA = ( "EPrints::Plugin::InputForm::Component" );

use Unicode::String qw(latin1);

use strict;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();

	$d{id} = "component/problems";
	$d{name} = "Problems";
	$d{visible} = "all";

	return %d;
}

=pod

=item $content = $component->render_content()

Returns the DOM for the content of this component.

=cut

sub render_content
{
	my( $self ) = @_;
	
	my $out = $self->{session}->make_doc_fragment;

	if( $self->{stage}->has_problems() )
	{
		my $div = $self->{session}->make_element( "div", class => "wf_problems" );
		my $ul = $self->{session}->make_element( "ul" );
		foreach my $problem ( $self->{stage}->get_problems() )
		{
			my $li = $self->{session}->make_element( "li" );
			$li->appendChild( $problem );
			$ul->appendChild( $li );
		}
		$div->appendChild( $ul );
		$out->appendChild( $div );
	}
	return $out;
}

1;





