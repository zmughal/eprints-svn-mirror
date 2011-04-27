package EPrints::Plugin::Screen::LogoBuilder;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;
# Make the plug-in

our $fh;
our $color;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ handle_upload process_input/];

	return $self;
}

# Can anyone see this screen.
sub can_be_viewed
{
	my( $plugin ) = @_;

	return 1;
}

sub allow_handle_upload
{
	my ( $self ) = @_;

	return 1;
}

sub allow_process_input
{
	my ( $self ) = @_;

	return 1;
}

sub action_handle_upload
{
	my ( $self ) = @_;
	
	my $session = $self->{session};

	my $fname = $self->{prefix}."_first_file";
	
	$fh = $session->get_query->upload( $fname );

	my $doc_path = $session->get_conf( "arc_path" ) . "/" . $session->get_id . "/cfg/static/images/temp_logos/";
	mkdir($doc_path);

	if( defined( $fh ) )
	{
		binmode($fh);
		my $tmpfile = File::Temp->new( SUFFIX => ".xml" );
		use bytes;

		while(sysread($fh,my $buffer, 4096)) {
			syswrite($tmpfile,$buffer);
		}
		my $output = $doc_path . $fh;
		rename($tmpfile,$output);
	}

}

sub action_process_input 
{
	my ( $self ) = @_;
	
	my $repository = $self->{repository};

	$fh = $repository->param( "file_handle" );
	
	$color = $repository->param( "color_chooser" );

}

sub generate_image
{
	my ( $self, $color ) = @_;

	my $repository = $self->{repository};

	my $convert = $repository->get_conf( 'executables','convert' );
	
	my $doc_path = $repository->get_conf( "arc_path" ) . "/" . $repository->get_id . "/cfg/static/images/temp_logos/";
	my $local_fh = $doc_path . $fh;

	# Stage 1 - Generate the Canvas
	my $canvas = File::Temp->new(UNLINK => 1, SUFFIX=>'.png');

	my $cmd = "$convert -size 300x300 xc:#$color $canvas";

	system( $cmd );

print STDERR "\n\nFailed Stage 1\n\n" unless (-e $canvas);

	# Stage 2 - Resize the Input Image
	my $resize = File::Temp->new(UNLINK => 1, SUFFIX=>'.png');

	$cmd = "$convert $local_fh -resize 290x290 $resize";

	system( $cmd );

print STDERR "\n\nFailed Stage 2\n\n" unless (-e $resize);

	# Stage 3 - Overlay the imput image on the canvas
	my $canvas2 = File::Temp->new(UNLINK => 1, SUFFIX=>'.png');

	$cmd = "$convert $canvas $resize -gravity center -composite $canvas2";

	system( $cmd );

print STDERR "\n\nFailed Stage 3\n\n" unless (-e $canvas2);
	
	# Stage 4 - Create the Mask
	my $mask = File::Temp->new(UNLINK => 1, SUFFIX=>'.png');

	$cmd = "$convert $canvas2 -alpha off -fill white -colorize 100% -draw 'fill black polygon 0,0 0,15 15,0 fill white circle 15,15 15,0' \\( +clone -flip \\) -compose Multiply -composite \\( +clone -flop \\) -compose Multiply -composite -background grey50 -alpha Shape $mask";
	
	system( $cmd );

print STDERR "\n\nFailed Stage 4\n\n" unless (-e $mask);
	
	# Stage 5 - Create the Lighting Effect Mask
	my $lighting = File::Temp->new(UNLINK => 1, SUFFIX=>'.png');

	$cmd = "$convert $mask -bordercolor None -border 1x1 -alpha on -alpha Extract -blur 0x10 -shade 130x30 -background grey50 -alpha background -auto-level $lighting";	
	
	system( $cmd );

print STDERR "\n\nFailed Stage 5\n\n" unless (-e $lighting);
	
	# Stage 6 - Combine the Images to Make Glass Bubble Image
	my $glass_bubble = File::Temp->new(UNLINK => 1, SUFFIX=>'.png');

	$cmd = "$convert $canvas2 $lighting \\( -clone 0,1 -compose Hardlight -composite \\) -delete 0 -compose In -composite $glass_bubble";

	system( $cmd );

print STDERR "\n\nFailed Stage 6\n\n" unless (-e $glass_bubble);
	
	# Stage 7 - Round off the corners
	my $final_path = $doc_path . $fh . "_$color.png";
	
	my $mvg = File::Temp->new(UNLINK => 1, SUFFIX=>'.mvg');

	$cmd = "$convert $glass_bubble -format 'roundrectangle 1,1 %[fx:w],%[fx:h] 20,20' -write info:$mvg -matte -bordercolor none -border 3 \\( +clone -alpha transparent -background none -fill white -stroke none -strokewidth 0 -draw \@$mvg \\) -compose DstIn -composite \\( +clone -alpha transparent -background none -fill none -stroke none -strokewidth 3 -draw \@$mvg -fill none -stroke none -strokewidth 1 -draw \@$mvg \\) -compose Over -composite $final_path";

	system( $cmd );

print STDERR "\n\nFailed Stage 7\n\n" unless (-e $final_path);
	unlink($canvas);
	unlink($canvas2);
	unlink($resize);
	unlink($mask);
	unlink($lighting);
	unlink($glass_bubble);
	unlink($mvg);

	return $final_path;

}

# What to display
sub render
{
	my( $self ) = @_;

	my $repository = $self->{repository};

	my $ret = $repository->make_doc_fragment();
	my $br = $repository->make_element("br");

	my $lang_phrase = $self->html_phrase("eprints_test_phrase");

	my $text_from_config = $repository->make_text($repository->{config}->{eprints_test_package}->{phrase});

	$ret->appendChild($lang_phrase);
	$ret->appendChild($br);
	$ret->appendChild($text_from_config);

	if (!defined $fh) {
		my $p = $repository->make_element(
				"p",
				style => "font-weight: bold;"
				);
		$p->appendChild($self->html_phrase("upload_pres_plan"));
		$ret->appendChild($p);

		my $upload_form = $repository->render_form("POST");
		my $upload_div = $repository->make_element("div", style=>"width: 300px;", align=>"center");
		my $f = $repository->make_doc_fragment;

		my $ffname = $self->{prefix}."_first_file";
		my $file_button = $repository->make_element( "input",
				name => $ffname,
				id => $ffname,
				type => "file",
				size=> 12,
				maxlength=>12,
				);

		my $upload_progress_url = $repository->get_url( path => "cgi" ) . "/users/ajax/upload_progress";
		my $onclick = "return startEmbeddedProgressBar(this.form,{'url':".EPrints::Utils::js_string( $upload_progress_url )."});";
		my $add_format_button = $repository->render_button(
				value => $repository->phrase( "Plugin/InputForm/Component/Upload:add_format" ),
				class => "ep_form_internal_button",
				name => "_action_handle_upload",
				onclick => $onclick );
		$f->appendChild( $file_button );
		$f->appendChild( $repository->make_element( "br" ));
		$f->appendChild( $add_format_button );

		my $progress_bar = $repository->make_element( "div", id => "progress" );
		$f->appendChild( $progress_bar );

		my $script = $repository->make_javascript( "EPJS_register_button_code( '_action_next', function() { el = \$('$ffname'); if( el.value != '' ) { return confirm( ".EPrints::Utils::js_string($repository->phrase("Plugin/InputForm/Component/Upload:really_next"))." ); } return true; } );" );

		$f->appendChild( $script );
		$f->appendChild( $repository->render_hidden_field( "screen", $self->{processor}->{screenid} ) );
		$f->appendChild( $repository->render_hidden_field( "_action_handle_upload", "Upload" ) );
		$upload_div->appendChild($f);
		$upload_form->appendChild($upload_div);

		$ret->appendChild($upload_form);
	} 
	else 
	{
		my $image_path;
		if ($color && $fh) {
			$image_path = $self->generate_image($color);
		}
		
		my $upload_form = $repository->render_form("POST");
		my $table = $repository->make_element("table", style=>"width: 100%;", align=>"center");
		my $tr = $repository->make_element( "tr" );
		my $td = $repository->make_element( "td", style=>"width: 50%;", align=>"center" );
		
		my $img = $repository->make_element( "img", src => "/images/temp_logos/$fh" );

		my $color_value = $color;

		$td->appendChild($img);
		$tr->appendChild($td);
		$table->appendChild($tr);
		$upload_form->appendChild($table);

		$td = $repository->make_element( "td", style=>"width: 50%;", align=>"left", valign=>"top" );
		$tr->appendChild($td);

		my $file_handle = $repository->make_element(
					"input",
					name => "file_handle",
					value => $fh,
					type => "hidden"
					);
		$td->appendChild($file_handle);

		$td->appendChild($repository->html_phrase("color_chooser"));
		$td->appendChild($repository->make_element("br"));
		my $color_chooser = $repository->make_element(
					"input",
					name => "color_chooser",
					value => $color_value,
					type => "text"
					);
		$td->appendChild($color_chooser);

		my $screen_id = "Screen::".$self->{processor}->{screenid};
		my $screen = $repository->plugin( $screen_id, processor => $self->{processor} );
		
		my $submit_button = $screen->render_action_button(
				{
				action => "process_input",
				screen => $screen,
				screen_id => $screen_id,
				} );
		$td->appendChild($submit_button);
		if ($image_path) {
			$img = $repository->make_element( "img", src => "/images/temp_logos/".$fh."_$color.png" );
			$td->appendChild($img);
		}

		$upload_form->appendChild($repository->make_element("br"));
		$upload_form->appendChild($repository->make_element("br"));
		
		my $table2 = $repository->make_element( "table" );
		$upload_form->appendChild($table2);
		my $tr2 = $repository->make_element( "tr" );
		$table2->appendChild($tr2);
		
		my @colors = ( "cccccc", "666666", "990099", "00ffff", "0000ff", "00ff00", "ffff00", "ff9933", "ff0000", "ff33ff" );

		foreach my $color2 (@colors) {
			my $td = $repository->make_element( "td", width=>"10%" );
			$image_path = $self->generate_image($color2);
			$img = $repository->make_element( "img", src => "/images/temp_logos/".$fh."_$color2.png", width=>"60px" );
			$td->appendChild($img);
			$tr2->appendChild($td);	
		}

		$ret->appendChild($upload_form);

	}

	return $ret;

}

1;
