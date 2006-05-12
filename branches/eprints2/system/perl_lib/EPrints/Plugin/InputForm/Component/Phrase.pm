package EPrints::Plugin::InputForm::Component::Phrase;

use EPrints::Plugin::InputForm::Component;

@ISA = ( "EPrints::Plugin::InputForm::Component" );

use Unicode::String qw(latin1);

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Phrase";
	$self->{visible} = "all";

	return $self;
}

=pod

=item $bool = $component->parse_config( $dom )

Parses the supplied DOM object and populates $component->{config}

=cut

sub parse_config
{
	my( $self, $dom ) = @_;


	$self->{config}->{phraseid} = $dom->getAttribute("ref");
}

=pod

=item $content = $component->render_content( $session )

Returns the DOM for the content of this component.

=cut


sub render_content
{
	my( $self, $session ) = @_;

	my $phrase = $session->html_phrase( $self->{config}->{phraseid} );

	return $phrase; 
}

1;





