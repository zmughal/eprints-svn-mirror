package EPrints::Plugin::InputForm::Surround::None;

use strict;

our @ISA = qw/ EPrints::Plugin /;


sub render
{
	my( $self, $component ) = @_;

	my $surround = $self->{session}->make_element( "div", class => "ep_sr_none" );
	foreach my $field_id ( $component->get_fields_handled )
	{
		$surround->appendChild( $self->{session}->make_element( "a", name=>$field_id ) );
	}
	if( $component->get_internal_button && (scalar @{$component->{stage}->{components}} > 1) )
	{
		$surround->appendChild( $self->{session}->make_element( "a", name=>"t" ) );
	}
	$surround->appendChild( $component->render_content( $self ) );

	return $surround;
}


1;
