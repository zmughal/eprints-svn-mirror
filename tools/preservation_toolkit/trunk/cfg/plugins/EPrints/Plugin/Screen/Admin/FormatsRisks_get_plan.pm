package EPrints::Plugin::Screen::Admin::FormatsRisks_get_plan;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new {
	my( $class, %params ) = @_;
 	
	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ get_plan /];

	return $self;
}

sub action_get_plan {
	my ( $self ) = @_;

	my $file_path = $self->{session}->param( "file_path" );

	my $session = $self->{session};
	my $result = 1;
	if ( !-s "$file_path" )
	{
		$result = 0;
	}
	if ($result ==1) 
	{
		seek($file_path, 0, 0);
		$self->{processor}->{file} = $file_path;
	} else {
		$self->{processor}->add_message(
				"error",
				$self->html_phrase( "failed" )
				);
		$self->{processor}->{screenid} = "Admin::FormatsRisks";
	}

}

sub allow_get_plan
{
	my( $self ) = @_;
	return 1;
}

sub wishes_to_export
{
	my( $self ) = @_;

	if( !defined( $self->{processor}->{file} ) )
	{
		return 0;
	}
	my $filename = "plan.xml";
	my $filesize = -s $self->{processor}->{file};

	EPrints::Apache::AnApache::header_out(
			$self->{session}->get_request,
			"Content-Disposition: attachment; filename=$filename; Content-Length: $filesize;"
			);

	return 1;
}

sub export
{
	my( $self ) = @_;

	binmode(STDOUT);
	my $file = $self->{processor}->{file};
	seek($file,0,0);
	open(HANDLE,$file);
	while(sysread(HANDLE, my $buffer, 4096))
	{
		print $buffer;
	}
}

sub export_mimetype
{
	my( $self ) = @_;

	return "text/xml";
}

sub render
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return undef;
}

1;

