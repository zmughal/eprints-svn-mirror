package EPrints::Plugin::Screen::IconBuilder;

use MIME::Base64 qw();
use Digest::SHA qw();

@ISA = qw( EPrints::Plugin::Screen );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{actions} = [qw( upload )];
	$self->{disable} = 0;

	return $self;
}

sub can_be_viewed { 1 }
sub allow_upload { shift->can_be_viewed }

sub redirect_to_me_url { undef }
sub wishes_to_export { shift->{repository}->param( "export" ) }
sub export_mimetype { "image/png" }
sub export
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	my $convert = $repo->config( "executables", "convert" );

	my $image = MIME::Base64::decode_base64(
		$self->{repository}->param( "image" )
	);
	# basic check to stop images being shown via us
	my $hmac_key = $self->{repository}->param( "hmac_key" );
	return if $hmac_key ne Digest::SHA::hmac_sha256_base64( $image, $self->param( "secret" ) );

	my $color = $self->{repository}->param( "color" );
	return if $color !~ /^[0-9a-f]{6}$/i;

	# background colour with rounded corners
	my $bg = File::Temp->new( SUFFIX => ".png" );
	system($convert, -size => "300x300", "xc:transparent", -background => "none", -fill => "#$color", -draw => "roundrectangle 0,0 299,299 38,38", "$bg");
	sysseek($bg,0,0);

	# compose it with the icon image
	my $img = File::Temp->new( SUFFIX => ".png" );
	open(my $ch, "|-", "composite", "-", "-compose", "over", "$bg", "$img")
		or EPrints->abort( "Error in $convert" );
	syswrite($ch, $image);
	close($ch);
	sysseek($img,0,0);

	sysread($img,$image,-s $img);

	$repo->get_request->headers_out->{'Content-Disposition'} = "attachment; filename=icon.png";

	binmode(STDOUT);
	print $image;
}

sub action_upload
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	my $fh = $repo->get_query->upload( "file" );
	return if !defined $fh;

	my $convert = $repo->config( "executables", "convert" );
	my $mask = $repo->config( "base_path" ) . "/lib/static/images/button_mask.png";

	# scale the uploaded image to 260pixels in a 300pixel image
	my $img = File::Temp->new( SUFFIX => ".png" );
	open(my $ch, "|-", $convert, "-", "-resize", "260x260", "-bordercolor", "none", "-border", "300x300", "-gravity", "Center", "-crop", "300x300+0+0", "$img")
		or EPrints->abort( "Error in $convert - -resize 270x270 $img" );
	while(sysread($fh, my $buffer, 4092))
	{
		syswrite($ch, $buffer);
	}
	close($ch);
	sysseek($img,0,0);

	sysread($img, $self->{processor}->{image}, -s $img);

	# apply the 300pixels button mask over the uploaded image
	$img = File::Temp->new( SUFFIX => ".png" );
	open(my $ch, "|-", "composite", "-background", "none", "-gravity", "center", "$mask", "-", "$img")
		or EPrints->abort( "Error in composite -background none -gravity center $mask - $img" );
	syswrite($ch, $self->{processor}->{image});
	close($ch);
	sysseek($img,0,0);

	sysread($img, $self->{processor}->{image}, -s $img);

	# create a 80x80 icon for the user to pick a background colour with
	$img = File::Temp->new( SUFFIX => ".png" );
	open($ch, "|-", $convert, "-", "-resize", "80x80", "$img")
		or EPrints->abort( "Error in $convert - -resize 150x150 $img" );
	syswrite($ch, $self->{processor}->{image});
	close($ch);
	sysseek($img,0,0);

	sysread($img, $self->{processor}->{icon}, -s $img);

	$self->{processor}->{hmac_key} = Digest::SHA::hmac_sha256_base64(
		$self->{processor}->{image},
		$self->param( "secret" )
	);
}

sub render_links
{
	my( $self ) = @_;

	my $frag = $self->SUPER::render_links;
	$frag->appendChild(
		$self->{repository}->make_javascript( undef,
			src => $self->{repository}->current_url( path => "static", "jscolor/jscolor.js" )
		) );
	$frag->appendChild(
		$self->{repository}->make_javascript( undef,
			src => $self->{repository}->current_url( path => "static", "javascript/icon_builder.js" )
		) );
	return $frag;
}

sub render
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $frag = $xml->create_document_fragment;

	my $div = $xml->create_element( "div" );
	$frag->appendChild( $div );

	my $form = $self->render_form;
	$div->appendChild( $form );
	$form->appendChild( $xhtml->input_field(
		file => undef,
		type => "file",
		) );
	$form->appendChild( $repo->render_action_buttons(
		upload => $repo->phrase( "lib/submissionform:action_upload" ),
		) );

	return $frag if !defined $self->{processor}->{image};

	$div = $xml->create_element( "div" );
	$frag->appendChild( $div );

	$form = $self->render_form;
	$div->appendChild( $form );
	$form->appendChild( $xhtml->hidden_field( export => 1 ) );
	$form->appendChild( $xhtml->hidden_field( hmac_key => $self->{processor}->{hmac_key} ) );
	$form->appendChild( $xml->create_data_element( "textarea",
		MIME::Base64::encode_base64( $self->{processor}->{image} ),
		name => "image",
		style => "display: none",
	) );

	my $icon = MIME::Base64::encode_base64( $self->{processor}->{icon}, '' );

	$form->appendChild( $xml->create_element( "div",
		id => "container",
		style => "
	background-image: url(data:image/png;base64,$icon);
	width: 80px;
	height: 80px;
	background-repeat: no-repeat;
	border-radius: 10px;
	margin-bottom: 30px;
			",
		) );

	$form->appendChild( $xhtml->input_field(
		color => "f0f080",
		id => "color",
		style => "position: absolute;",
		) );

	$form->appendChild( $repo->render_action_buttons(
		export => $repo->phrase( "lib/searchexpression:export_button" )
		) );

	return $frag;
}

1;
