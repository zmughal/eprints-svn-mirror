package EPrints::Plugin::InputForm::Surround::Light;

use strict;

our @ISA = qw/ EPrints::Plugin /;


sub render
{
	my( $self, $component ) = @_;
	
	my $content_class="";

	my $surround = $self->{session}->make_element( "div", class => "ep_sr_component" );
	$surround->appendChild( $self->{session}->make_element( "a", name=>$component->{prefix} ) );
	foreach my $field_id ( $component->get_fields_handled )
	{
		$surround->appendChild( $self->{session}->make_element( "a", name=>$field_id ) );
	}
	
	my $content = $self->{session}->make_element( "div", id => $component->{prefix}."_content", class=>"$content_class ep_sr_content" );
	my $content_inner = $self->{session}->make_element( "div", id => $component->{prefix}."_content_inner" );

	$content->appendChild( $content_inner );
	$content_inner->appendChild( $component->render_content( $self ) );
	
	
	$surround->appendChild( $content );

	return $surround;
}


1;
