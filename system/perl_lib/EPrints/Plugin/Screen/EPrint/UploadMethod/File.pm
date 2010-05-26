package EPrints::Plugin::Screen::EPrint::UploadMethod::File;

use EPrints::Plugin::Screen::EPrint::UploadMethod;

@ISA = qw( EPrints::Plugin::Screen::EPrint::UploadMethod );

use strict;

sub new
{
	my( $self, %params ) = @_;

	return $self->SUPER::new(
		appears => [
			{ place => "upload_methods", position => 100 },
		],
		%params );
}

sub render_title
{
	my( $self ) = @_;

	return $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:from_file" );
}

sub from
{
	my( $self, $basename ) = @_;

	my $session = $self->{session};
	my $processor = $self->{processor};
	my $eprint = $processor->{eprint};

	return if !$self->SUPER::from( $basename );

	my $epdata = $processor->{notes}->{epdata};
	return if !defined $epdata->{main};

	my $doc = $eprint->create_subdataobj( "documents", $epdata );
	if( !defined $doc )
	{
		$processor->add_message( "error", $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:create_failed" ) );
		return;
	}

	$processor->{notes}->{upload_plugin}->{to_unroll}->{$doc->id} = 1;
}

1;
