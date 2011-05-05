package EPrints::Plugin::Screen::IconBuilder;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;
# Make the plug-in

our $fh;
our $color;
our $folder; 

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
	
	my $repository = $self->{repository};

	my $fname = $self->{prefix}."_first_file";
	
	$fh = $repository->get_query->upload( $fname );

	my $doc_path = $repository->get_conf( "arc_path" ) . "/" . $repository->get_id . "/cfg/static/images/temp_logos/";
	mkdir($doc_path);

	if( defined( $fh ) )
	{
		binmode($fh);
		my $tmpfile = File::Temp->new( SUFFIX => ".png" );
		use bytes;
		
		$folder = substr($fh,0,rindex($fh,".")) . "_" . time();
		
		while(sysread($fh,my $buffer, 4096)) {
			syswrite($tmpfile,$buffer);
		}

		mkdir($doc_path . $folder);
		my $output = $doc_path . $folder . "/" . $fh;
		rename($tmpfile,$output);
	}

}

sub action_process_input 
{
	my ( $self ) = @_;
	
	my $repository = $self->{repository};

	$fh = $repository->param( "file_handle" );
	$folder = $repository->param( "folder_handle" );
	
	$color = $repository->param( "color_chooser" );

}

sub generate_image
{
	my ( $self, $color ) = @_;

	my $repository = $self->{repository};

	my $convert = $repository->get_conf( 'executables','convert' );
	
	my $doc_path = $repository->get_conf( "arc_path" ) . "/" . $repository->get_id . "/cfg/static/images/temp_logos/" . $folder . "/";
	my $local_fh = $doc_path . $fh;
	
	my $final_path = $doc_path . $fh . "_$color.png";

	return $final_path if ( -e $final_path );
		
	# Stage 1 - Resize the Input Image
	my $canvas2 = File::Temp->new(UNLINK => 1, SUFFIX=>'.png');

	my $cmd = "$convert $local_fh -resize 300x300\\! $canvas2";

	system( $cmd );

	print STDERR "\n\n[IconBuilder] Failed Stage 1\n\n" unless (-e $canvas2);
	
	if (defined $color) 
	{
		# Stage 2 - Generate the Canvas
		my $canvas = File::Temp->new(UNLINK => 1, SUFFIX=>'.png');

		$cmd = "$convert -size 300x300 xc:#$color $canvas";

		system( $cmd );

		print STDERR "\n\n[IconBuilder] Failed Stage 2\n\n" unless (-e $canvas);

		# Stage 1(b) - Resize the Input Image
		my $resize = File::Temp->new(UNLINK => 1, SUFFIX=>'.png');

		$cmd = "$convert $local_fh -resize 290x290 $resize";

		system( $cmd );

		print STDERR "\n\n[IconBuilder] Failed Stage 1(b)\n\n" unless (-e $resize);

		# Stage 3 - Overlay the imput image on the canvas
		$canvas2 = File::Temp->new(UNLINK => 1, SUFFIX=>'.png');

		$cmd = "$convert $canvas $resize -gravity center -composite $canvas2";

		system( $cmd );

		unlink($canvas);
		unlink($resize);
	}
	
	# Stage 4 - Create the Mask
	my $mask = File::Temp->new(UNLINK => 1, SUFFIX=>'.png');

	$cmd = "$convert $canvas2 -alpha off -fill white -colorize 100% -draw 'fill black polygon 0,0 0,15 15,0 fill white circle 15,15 15,0' \\( +clone -flip \\) -compose Multiply -composite \\( +clone -flop \\) -compose Multiply -composite -background grey50 -alpha Shape $mask";
	
	system( $cmd );

print STDERR "\n\n[IconBuilder] Failed Stage 4\n\n" unless (-e $mask);
	
	# Stage 5 - Create the Lighting Effect Mask
	my $lighting = File::Temp->new(UNLINK => 1, SUFFIX=>'.png');

	$cmd = "$convert $mask -bordercolor None -border 1x1 -alpha on -alpha Extract -blur 0x10 -shade 130x30 -background grey50 -alpha background -auto-level $lighting";	
	
	system( $cmd );

print STDERR "\n\n[IconBuilder] Failed Stage 5\n\n" unless (-e $lighting);
	
	# Stage 6 - Combine the Images to Make Glass Bubble Image
	my $glass_bubble = File::Temp->new(UNLINK => 1, SUFFIX=>'.png');

	$cmd = "$convert $canvas2 $lighting \\( -clone 0,1 -compose Hardlight -composite \\) -delete 0 -compose In -composite $glass_bubble";

	system( $cmd );

print STDERR "\n\n[IconBuilder] Failed Stage 6\n\n" unless (-e $glass_bubble);
	
	# Stage 7 - Round off the corners
	my $mvg = File::Temp->new(UNLINK => 1, SUFFIX=>'.mvg');

	$cmd = "$convert $glass_bubble -format 'roundrectangle 1,1 %[fx:w],%[fx:h] 20,20' -write info:$mvg -matte -bordercolor none -border 3 \\( +clone -alpha transparent -background none -fill white -stroke none -strokewidth 0 -draw \@$mvg \\) -compose DstIn -composite \\( +clone -alpha transparent -background none -fill none -stroke none -strokewidth 3 -draw \@$mvg -fill none -stroke none -strokewidth 1 -draw \@$mvg \\) -compose Over -composite $final_path";

	system( $cmd );

print STDERR "\n\n[IconBuilder] Failed Stage 7\n\n" unless (-e $final_path);
	unlink($canvas2);
	unlink($mask);
	unlink($lighting);
	unlink($glass_bubble);
	unlink($mvg);

	return $final_path;

}


sub delete_old_files 
{
	use File::stat;
	use Time::localtime;
	use File::Path qw(rmtree);

	my ( $self ) = @_;
	
	my $repository = $self->{repository};

	my $doc_path = $repository->get_conf( "arc_path" ) . "/" . $repository->get_id . "/cfg/static/images/temp_logos/";

	my @files = <$doc_path/*>;
	foreach my $file (@files) 
	{
		next unless (-d $file);

		my $date_string = substr($file,rindex($file,"_")+1,length($file));

		my $ten_minutes_ago = time() - 600;

		if ($date_string < $ten_minutes_ago) {
			rmtree($file);
		}

	}
	
}

# What to display
sub render
{
	my( $self ) = @_;

	$self->delete_old_files();

	my $repository = $self->{repository};

	my $ret = $repository->make_doc_fragment();
	my $br = $repository->make_element("br");

	if (!defined $fh) {
		my $p = $repository->make_element( "p" );
		$p->appendChild($self->html_phrase("upload"));
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
		
		$p = $repository->make_element( "p" );
		$p->appendChild( $repository->make_element( "br" ));
		$p->appendChild($self->html_phrase("upload2"));
		$p->appendChild( $repository->make_element( "br" ));
		$ret->appendChild($p);
	} 
	else 
	{
		my $p = $repository->make_element( "p" );
		$p->appendChild( $repository->make_element( "br" ));
		$p->appendChild($self->html_phrase("processing_description"));
		$p->appendChild( $repository->make_element( "br" ));
		$ret->appendChild($p);
		
		my $image_path;
		if ($color && $fh) {
			$image_path = $self->generate_image($color);
		} else {
			$image_path = $self->generate_image(undef);
		}
		
		my $upload_form = $repository->render_form("POST");
		my $table = $repository->make_element("table", style=>"width: 100%;", align=>"center");
		my $tr = $repository->make_element( "tr" );
		my $td = $repository->make_element( "td", style=>"width: 50%;" );
		$td->appendChild($self->html_phrase("uploaded_image"));
			
		$td->appendChild($repository->make_element("br"));
		$td->appendChild($repository->make_element("br"));

		my $div = $repository->make_element( "div", align=>"center" );
		$td->appendChild($div);
		
		my $img = $repository->make_element( "img", src => "/images/temp_logos/$folder/$fh", width=> "290px" );

		my $color_value = $color;

		$div->appendChild($img);
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
		
		my $folder_handle = $repository->make_element(
					"input",
					name => "folder_handle",
					value => $folder,
					type => "hidden"
					);
		$td->appendChild($folder_handle);

		$td->appendChild($self->html_phrase("color_chooser"));
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
			$td->appendChild($repository->make_element("br"));
			$td->appendChild($repository->make_element("br"));
			
			my $div = $repository->make_element("div", align=>"center");
			$td->appendChild($div);
			$img = $repository->make_element( "img", src => "/images/temp_logos/$folder/".$fh."_$color.png", width=>"240px" );
			$div->appendChild($img);
		}

		$upload_form->appendChild($repository->make_element("br"));
		$upload_form->appendChild($repository->make_element("br"));
		
		$upload_form->appendChild($self->html_phrase("generated_icons"));
		$upload_form->appendChild($repository->make_element("br"));
		
		my $table2 = $repository->make_element( "table", width=>"100%" );
		$upload_form->appendChild($table2);

		my $tr2 = $repository->make_element( "tr" );
		$table2->appendChild($tr2);
		
		my @colors = ( "cccccc", "666666", "990099", "00ffff", "0000ff", "00ff00", "ffff00", "ff9933", "ff0000", "ff33ff" );

		foreach my $color2 (@colors) {
			my $td = $repository->make_element( "td", width=>"10%" );
			$image_path = $self->generate_image($color2);
			$img = $repository->make_element( "img", src => "/images/temp_logos/$folder/".$fh."_$color2.png", width=>"68px" );
			$td->appendChild($img);
			$tr2->appendChild($td);	
		}

		$ret->appendChild($upload_form);

	}

	return $ret;

}

1;
