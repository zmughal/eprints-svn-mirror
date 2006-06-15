package EPrints::Plugin::InputForm::Surround::None;

use strict;

our @ISA = qw/ EPrints::Plugin /;


sub render
{
	my( $self, $component ) = @_;
	return $component->render_content( $self );
}

sub get_req_icon
{
	my( $self ) = @_;
	my $reqimg = $self->{session}->make_element( "img", src => "/images/req.gif", class => "wf_req_icon", border => "0" );
	return $reqimg;
}

1;
