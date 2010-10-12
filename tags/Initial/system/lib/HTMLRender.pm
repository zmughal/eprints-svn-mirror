######################################################################
#
# EPrints HTML Renderer Module
#
#   Renders common HTML components
#
######################################################################
#
# 01/10/99 - Created by Robert Tansley
#
######################################################################

package EPrints::HTMLRender;

use EPrints::SubjectList;
use EPrints::Name;

use EPrintSite::SiteInfo;

use strict;
use CGI;


# Width of text fields
$EPrints::HTMLRender::form_width = 60;
$EPrints::HTMLRender::search_form_width = 40;

# Width of name fields
$EPrints::HTMLRender::form_name_width = 20;

# Max number of chars in (single-line) text fields
$EPrints::HTMLRender::field_max = 255;

# Max height of scrolling list
$EPrints::HTMLRender::list_height_max = 20;

# Number of extra spaces for names to add when user clicks on "More Spaces"
$EPrints::HTMLRender::add_boxes = 3;

# Months
my @months = ( "00",
               "01",
               "02",
               "03",
               "04",
               "05",
               "06",
               "07",
               "08",
               "09",
               "10",
               "11",
               "12" );

# Month names
my %monthnames =
(
	"00"     => "Unspecified",
	"01"     => "January",
	"02"     => "February",
	"03"     => "March",
	"04"     => "April",
	"05"     => "May",
	"06"     => "June",
	"07"     => "July",
	"08"     => "August",
	"09"     => "September",
	"10"     => "October",
	"11"     => "November",
	"12"     => "December"
);


######################################################################
#
# new( $session, $offline)
#
#  Create an HTML Renderer. If $offline is true, won't try to read
#  form values.
#
######################################################################

sub new
{
	my( $class, $session, $offline ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	if( $offline )
	{
		$self->{offline} = 1;
		$self->{query} = new CGI( {} );
	}
	else
	{
		$self->{query} = CGI->new();
	}
	
	$self->{session} = $session;


	# Get name boxcount stuff
	$self->{namebuttonpressed} = 0;

	$self->{nameinfo} = {};
	my @names = $self->{query}->param();
	my $n;

	foreach $n (@names)
	{
#EPrints::Log->debug( "HTMLRender", "Checking: $n" );
		if( substr($n, 0, 5) eq "name_" )
		{
#EPrints::Log->debug( "HTMLRender", "In it goes" );
			$self->{nameinfo}->{$n} = $self->{query}->param( $n );
		}
		if( substr($n, 0, 10) eq "name_more_" )
		{
#EPrints::Log->debug( "HTMLRender", "Name Button Pressed" );
			$self->{namebuttonpressed} = 1;
		}
	}
	

	return( $self );
}


######################################################################
#
# $html = start_html( $title )
#
#  Return a standard HTML header, with any title or logo we might
#   want
#
######################################################################

sub start_html
{
	my( $self, $title ) = @_;

	my $html = "";
	
	# mod_perl already writes most of the stuff we need. We need only specify
	# a MIME-type...
	$html .= "Content-type: text/html \r\n\r\n" unless( $self->{offline} );
	
	# Now the HTML itself.
	$html .= $self->{query}->start_html(
		-AUTHOR=>"$EPrintSite::SiteInfo::author",
		-BGCOLOR=>"$EPrintSite::SiteInfo::html_bgcolor",
		-FGCOLOR=>"$EPrintSite::SiteInfo::html_fgcolor",
		-TITLE=>"$EPrintSite::SiteInfo::sitename\: $title" );

	# Logo
	my $banner = $EPrintSite::SiteInfo::html_banner;
	$banner =~ s/TITLE_PLACEHOLDER/$title/g;

	$html .= "$banner\n";

	return( $html );
}


######################################################################
#
# end_html()
#
#  Write out stuff at the bottom of the page. Any standard navigational
#  stuff might go in here.
#
######################################################################

sub end_html
{
	my( $self ) = @_;
	
	# End of HTML gubbins
	my $html = "$EPrintSite::SiteInfo::html_tail\n";
	$html .= $self->{query}->end_html;

	return( $html );
}


######################################################################
#
# $url = url()
#
#  Returns the URL of the current script
#
######################################################################

sub url
{
	my( $self ) = @_;
	
	return( $self->{query}->url() );
}


######################################################################
#
# $consumed = internal_button_pressed()
#
#  Important function: if this returns true, then the button pressed on
#  the form was an internal form state button, so whatever form you
#  rendered should be re-rendered to show the updated state info.
#
######################################################################

sub internal_button_pressed
{
	my( $self ) = @_;
	
	return( $self->{namebuttonpressed} );
}


######################################################################
#
# render_error( $error_text, $back_to, $back_to_text )
#
#  Renders an error page with the given error text. A link, with the
#  text $back_to_text, is offered, the destination of this is $back_to,
#  which should take the user somewhere sensible.
#
######################################################################

sub render_error
{
	my( $self, $error_text, $back_to, $back_to_text ) = @_;

	print $self->start_html( "Error" );

	print "<P>$EPrintSite::SiteInfo::sitename has encountered an error:</P>\n";
	print "<P>$error_text</P>\n";
	print "<P>Feel free to contact <A HREF=\"mailto:$EPrintSite::SiteInfo::admin\">$EPrintSite::SiteInfo::sitename administration</A> with details.</P>\n";
	print "<P><CENTER><A HREF=\"$back_to\">$back_to_text</A></CENTER></P>\n";
	
	print $self->end_html();
}

######################################################################
#
# $html = format_field( $field, $value )
#
#  format a field. Returns the formatted HTML as a string (doesn't
#  actually print it.)
#
######################################################################

sub format_field
{
	my( $self, $field, $value ) = @_;

	my $type = $field->{type};
	my $html;
	
	if( $type eq "text" || $type eq "int" )
	{
		# Render text
		$html = "$value";
	}
	elsif( $type eq "enum" || $type eq "eprinttype" )
	{
		$html = $field->{labels}->{$value};
	}
	elsif( $type eq "boolean" )
	{
		$html = ( $value eq "TRUE" ? "Yes" : "No" );
	}
	elsif( $type eq "multitext" )
	{
		$html = "$value";
	}
	elsif( $type eq "date" )
	{
		my @elements = split /\-/, $value;

		if( $elements[0]==0 )
		{
			$html = "UNSPECIFIED";
		}
		elsif( $#elements != 2 || $elements[1] < 1 || $elements[1] > 12 )
		{
			$html = "INVALID";
		}
		else
		{
			$html = $elements[2]." ".$monthnames{$elements[1]}." ".$elements[0];
		}
	}
	elsif( $type eq "url" )
	{
		$html = "<A HREF=\"$value\">$value</A>";
	}
	elsif( $type eq "email" )
	{
		$html = "<A HREF=\"mailto:$value\">$value</A>";
	}
	elsif( $type eq "subjects" )
	{
		$html = "";

		my $subject_list = EPrints::SubjectList->new( $value );
		my @subjects = $subject_list->get_tags();
		
		my $sub;
		my $first = 0;

		foreach $sub (@subjects)
		{
			if( $first==0 )
			{
				$first = 1;
			}
			else
			{
				$html .= ",";
			}
			
			$html .= EPrints::Subject->subject_name( $self->{session}, $sub );
		}
	}
	elsif( $type eq "set" )
	{
		$html = "";
		my @setvalues = split /:/, $value;
		my $first = 0;

		foreach (@setvalues)
		{
			if( $_ ne "" )
			{
				$html .=  ", " unless( $first );
				$first=1 if( $first );
				$html .= $field->{labels}->{$_};
			}
		}
	}
	elsif( $type eq "pagerange" )
	{
		$html = $value;
	}
	elsif( $type eq "year" )
	{
		$html = $value;
	}
	elsif( $type eq "multiurl" )
	{
		my @urls = split /[\,\s]+/, $value;
		my $url;
		
		foreach $url (@urls)
		{
			print "<A HREF=\"$url\">$url</A> ";
		}
	}
	elsif( $type eq "name" )
	{
		$html = EPrints::Name->format_name( $value );
	}
	else
	{
		$EPrints::Log->log_entry(
			"HTMLRender",
			"Error: Don't know how to render field of type $type" );
	}

	return( $html );
}


######################################################################
#
# $html = input_field( $field, $value )
#
#  Returns the HTML to produce an input field. $field is a reference
#  to the usual metadata field, and $value is the initial value.
#
######################################################################

sub input_field
{
	my( $self, $field, $value ) = @_;
	
	my $type = $field->{type};

#	EPrints::Log->debug( "HTMLRender", "Rendering form for $field->{name} type $field->{type}" );
#	EPrints::Log->debug( "HTMLRender", "type is $type" );
#	EPrints::Log->debug( "HTMLRender", "Value I have is $value" );

	my $html;

	if( $type eq "text" || $type eq "url" || $type eq "email" )
	{
		my $maxlength = ( defined $field->{maxlength} ? $field->{maxlength}
			: $EPrints::HTMLRender::field_max );
		my $size = ( $maxlength > $EPrints::HTMLRender::form_width ?
			$EPrints::HTMLRender::form_width : $maxlength );
	
		$html = $self->{query}->textfield(
			-name=>$field->{name},
			-default=>$value,
			-size=>$size,
			-maxlength=>$maxlength );
	}
	elsif( $type eq "date" )
	{
		my( $year, $month, $day ) = ("", "", "");
		if( defined $value && $value ne "" )
		{
			($year, $month, $day) = split /-/, $value;
			($year, $month, $day) = ("", "00", "") if( $month == 0 );
		}

		$html = "Year:";
		$html .= $self->{query}->textfield( -name=>"$field->{name}_year",
		                                    -default=>$year,
		                                    -size=>4,
		                                    -maxlength=>4 );
		$html .= " Month:";
		$html .= $self->{query}->popup_menu( -name=>"$field->{name}_month",
		                                     -values=>\@months,
		                                     -default=>$month,
		                                     -labels=>\%monthnames );
		$html .= " Day:";
		$html .= $self->{query}->textfield( -name=>"$field->{name}_day",
		                                    -default=>$day,
		                                    -size=>2,
		                                    -maxlength=>2 );
	}
	elsif( $type eq "int" )
	{
		$html = $self->{query}->textfield( -name=>$field->{name},
		                                   -default=>$value,
		                                   -size=>$field->{displaydigits},
		                                   -maxlength=>$field->{displaydigits} );
	}
	elsif( $type eq "enum" )
	{
		my $def_val = ( !defined $value || $value eq "" ?
			${$field->{tags}}[0] : $value );
	
		$html = $self->{query}->popup_menu( -name=>$field->{name},
		                                    -values=>$field->{tags},
		                                    -default=>$def_val,
		                                    -labels=>$field->{labels} );
	}
	elsif( $type eq "boolean" )
	{
		$html = $self->{query}->checkbox(
			-name=>$field->{name},
			-checked=>( $value eq "TRUE" ? "checked" : undef ),
			-value=>"TRUE",
			-label=>"" );
	}
	elsif( $type eq "multitext" )
	{
		$html = $self->{query}->textarea(
			-name=>$field->{name},
			-default=>$value,
			-rows=>$field->{displaylines},
			-columns=>$EPrints::HTMLRender::form_width );
	}
	elsif( $type eq "set" )
	{
		my @actual = split /:/, $value;

		# Get rid of beginning and end empty values
		shift @actual if( defined $actual[0] && $actual[0] eq "" );
		pop @actual if( defined $actual[$#actual] && $actual[$#actual] eq "" );

		$html = $self->{query}->scrolling_list(
			-name=>$field->{name},
			-values=>$field->{tags},
			-default=>\@actual,
			-size=>( $field->{displaylines} ),
			-multiple=>( $field->{multiple} ? 'true' : undef ),
			-labels=>$field->{labels} );
	}
	elsif( $type eq "pagerange" )
	{
		my @pages = split /-/, $value;
		
		$html = $self->{query}->textfield( -name=>"$field->{name}_from",
		                                   -default=>$pages[0],
		                                   -size=>6,
		                                   -maxlength=>10 );

		$html .= "&nbsp;to&nbsp;";

		$html .= $self->{query}->textfield( -name=>"$field->{name}_to",
		                                    -default=>$pages[1],
		                                    -size=>6,
		                                    -maxlength=>10 );
	}
	elsif( $type eq "year" )
	{
		$html = $self->{query}->textfield( -name=>$field->{name},
		                                   -default=>$value,
		                                   -size=>4,
		                                   -maxlength=>4 );
	}
	elsif( $type eq "multiurl" )
	{
		$html = $self->{query}->textarea(
			-name=>$field->{name},
			-default=>$value,
			-rows=>$field->{displaylines},
			-columns=>$EPrints::HTMLRender::form_width );
	}
	elsif( $type eq "eprinttype" )
	{
		my @eprint_types = EPrints::MetaInfo->get_eprint_types();
		my $labels = EPrints::MetaInfo->get_eprint_type_names();

		my $actual = [ ( !defined $value || $value eq "" ?
			$eprint_types[0] : $value ) ];
		my $height = ( $EPrints::HTMLRender::list_height_max < $#eprint_types+1 ?
		               $EPrints::HTMLRender::list_height_max : $#eprint_types+1 );

		$html = $self->{query}->scrolling_list(
			-name=>$field->{name},
			-values=>\@eprint_types,
			-default=>$actual,
			-size=>$height,
			-labels=>$labels );
	}
	elsif( $type eq "subjects" )
	{
		my $subject_list = EPrints::SubjectList->new( $value );

		# If in the future more user-specific subject tuning is needed,
		# will need to put the current user in the place of undef.
		my( $sub_tags, $sub_labels ) = EPrints::Subject->get_postable( 
				$self->{session}, 
				EPrints::User->current_user( $self->{session} ) );

		my $height = ( $EPrints::HTMLRender::list_height_max < $#{$sub_tags}+1 ?
		               $EPrints::HTMLRender::list_height_max : $#{$sub_tags}+1 );

		my @selected_tags = $subject_list->get_tags();

		$html = $self->{query}->scrolling_list(
			-name=>$field->{name},
			-values=>$sub_tags,
			-default=>\@selected_tags,
			-size=>$height,
			-multiple=>( $field->{multiple} ? "true" : undef ),
			-labels=>$sub_labels );
	}
	elsif( $type eq "name" )
	{
		# Get the names out
		my @names = EPrints::Name->extract( $value );

#EPrints::Log->debug( "HTMLRender", "input_field got $#names from $value" );

		my $boxcount = $self->{nameinfo}->{"name_boxes_$field->{name}"};

		if( defined $self->{nameinfo}->{"name_more_$field->{name}"} )
		{
			$boxcount += $EPrints::HTMLRender::add_boxes;
		}

		# Ensure at least 1...
		$boxcount = 1 if( !defined $boxcount );
		# And that there's enough to fit all the names in
		$boxcount = $#names+1 if( $boxcount < $#names+1 );

		# Render the boxes
		$html = "<table border=0><tr><th>Surname</th><th>First names</th>";
		
		my $i;
		for( $i = 0; $i < $boxcount; $i++ )
		{
			my( $surname, $firstnames );
			
			if( $i <= $#names )
			{
				( $surname, $firstnames ) = @{$names[$i]};
			}
					
			$html .= "</tr>\n<tr><td>";
			$html .= $self->{query}->textfield(
				-name=>"name_surname_$i"."_$field->{name}",
				-default=>$surname,
				-size=>$EPrints::HTMLRender::form_name_width,
				-maxlength=>$EPrints::HTMLRender::field_max );
			$html .= "</td><td>";
			$html .= $self->{query}->textfield(
				-name=>"name_firstname_$i"."_$field->{name}",
				-default=>$firstnames,
				-size=>$EPrints::HTMLRender::form_name_width,
				-maxlength=>$EPrints::HTMLRender::field_max );
			$html .= "</td>";
		}
		
		if( $field->{multiple} )
		{
			$html .= "<td>".$self->named_submit_button( "name_more_$field->{name}",
		                                          	  "More Spaces" );
			$html .= $self->hidden_field( "name_boxes_$field->{name}", $boxcount );
			$html .= "</td>";

#			$self->{query}->param( -name=>"name_boxes_$field->{name}",
#			                       -value=>$boxcount );
		}
		
		$html .= "</tr>\n</table>\n";
	}
	else
	{
		$html = "N/A";

		EPrints::Log->log_entry(
			"HTMLRender",
			"Don't know how to render input field for type $type" );
	}
	
	return( $html );
}


######################################################################
#
# render_form( $fields,              #array_ref
#              $values,              #array_ref
#              $show_names,
#              $show_help,
#              $submit_buttons,      #array_ref
#              $hidden_fields,       #hash_ref
#              $dest
#
#  Renders an HTML form. $fields is a reference to metadata fields
#  in the usual format. $values should map field names to existing values.
#  This function also puts in a hidden parameter "seen" and sets it to
#  true. That way, a calling script can check the value of the parameter
#  "seen" to see if the users seen and responded to the form.
#
#  Submit buttons are specified in a reference to an array of names.
#  If $submit_buttons isn't passed in (or is undefined), a simple
#  default "Submit" button is slapped on.
#
#  $dest should contain the URL of the destination
#
######################################################################

sub render_form
{
	my( $self, $fields, $values, $show_names, $show_help, $submit_buttons,
	    $hidden_fields, $dest ) = @_;

	my $query = $self->{query};
	
	print $self->start_form( $dest );

	print "<CENTER><P><TABLE BORDER=0>\n";

	my $colspan = ($show_names ? " COLSPAN=2" : "" );
	my $align = ($show_names ? "" : " ALIGN=CENTER" );
	
	my $field;

	foreach $field (@$fields)
	{
		# Field name should have a star next to it if it is required
		my $required_string = ( $field->{required} ? "*" : "" );

		if( $show_help )
		{
			print "<TR><TD$colspan>&nbsp;</TD></TR>\n";
			print "<TR><TD$colspan><CENTER><EM>$field->{help}</EM></CENTER></TD></TR>\n";
		}

		print "<TR><TD$align>";
		
		print "<STRONG>$field->{displayname}$required_string</STRONG></TD><TD>" if $show_names;

		print $self->input_field( $field, $values->{$field->{name}} );

		print "</TD></TR>\n";

	}

	print "</TABLE></P></CENTER>\n";

	# Hidden field, so caller can tell whether or not anything's
	# been POSTed
	print $self->hidden_field( "seen", "true" );

	if( defined $hidden_fields )
	{
		my $hf;

		foreach $hf (keys %{$hidden_fields})
		{
			print $self->hidden_field( $hf, $hidden_fields->{$hf} );
		}
	}

	print "\n<CENTER>";

	print $self->submit_buttons( $submit_buttons );

	print "</CENTER>\n";
	print $self->end_form();
}


######################################################################
#
# $html = submit_buttons( $submit_buttons )
#                           array_ref
#
#  Returns HTML for buttons all with the name "submit" but with the
#  values given in the array. A single "Submit" button is printed
#  if the buttons aren't specified.
#
######################################################################

sub submit_buttons
{
	my( $self, $submit_buttons ) = @_;

	my $html = "";
	my $first = 1;
	
	if( defined $submit_buttons )
	{
		my $button;
		foreach $button (@$submit_buttons)
		{
			# Some space between them
			$html .= "&nbsp;&nbsp;" if( $first==0 );

			$html .=  $self->{query}->submit( -name=>"submit", -value=>$button );
			$first = 0 if( $first );
		}
	}
	else
	{
		$html = $self->{query}->submit( -name=>"submit", -value=>"Submit" );
	}

	return( $html );
}


######################################################################
#
# $html = named_submit_button( $name, $value )
#
#  Returns HTML for a single submit button with a given name and value
#
######################################################################

sub named_submit_button
{
	my( $self, $name, $value ) = @_;
	
	return( $self->{query}->submit( -name=>$name, -value=>$value ) );
}


######################################################################
#
# $html = start_form( $dest )
#
#  Return (multipart) form preamble.
#
######################################################################

sub start_form
{
	my( $self, $dest ) = @_;
	
	if( defined $dest )
	{
		return( $self->{query}->start_multipart_form( -action=>$dest ) );
	}
	else
	{
		return( $self->{query}->start_multipart_form() );
	}
}


######################################################################
#
# $html = start_get_form( $dest )
#
#  Return form preamble, using GET method. 
#
######################################################################

sub start_get_form
{
	my( $self, $dest ) = @_;
	
	if( defined $dest )
	{
		return( $self->{query}->start_form( -method=>"GET",
		                                    -action=>$dest ) );
	}
	else
	{
		return( $self->{query}->start_form( -method=>"GET" ) );
	}
}


######################################################################
#
# $html = end_form()
#
#  Return end of form HTML stuff.
#
######################################################################

sub end_form
{
	my( $self ) = @_;
	return( $self->{query}->endform );
}


######################################################################
#
# $html = hidden_field( $name, $value )
#
#  Insert a hidden field, for passing around state information. If
#  $value is undefined, the hidden field will inherit the value from
#  the last script invocation.
#
######################################################################

sub hidden_field
{
	my( $self, $name, $value ) = @_;
	
	return( $self->{query}->hidden( -name=>$name,
	                                -default=>$value,
	                                -override=>1 ) ) if( defined $value );

	return( $self->{query}->hidden( -name=>$name ) );
}


######################################################################
#
# $html = upload_field( $name )
#
#  Return the HTML for a file upload field with the given name.
#
######################################################################

sub upload_field
{
	my( $self, $name ) = @_;
	
	return( $self->{query}->filefield(
		-name=>$name,
		-default=>"",
		-size=>$EPrints::HTMLRender::form_width,
		-maxlength=>$EPrints::HTMLRender::field_max ) );
}

######################################################################
#
# $seen = seen_form()
#
#  Returns 1 if form data has been posted; i.e. if the script has already
#  been called and the user has entered data and clicked "submit."
#
######################################################################

sub seen_form
{
	my( $self ) = @_;
	
	my $result = 0;

	$result = 1 if( $self->{query}->param( 'seen' ) eq 'true' );

	return( $result );
}


######################################################################
#
# redirect( $url )
#
#  Redirects the browser to $url. If any other text is to be written,
#  (in case a browser doesn't accept the redirection) this must be
#  called BEFORE start_html().
#
######################################################################

sub redirect
{
	my( $self, $url ) = @_;
	
	return( $self->{query}->redirect( $url ) );
}


######################################################################
#
# $param = param( $name )
#
#  Return a query parameter.
#
######################################################################

sub param
{
	my( $self, $name ) = @_;

	return( $self->{query}->param( $name ) ) unless wantarray;
	
	# Called in an array context
	my @result;

	if( defined $name )
	{
		@result = $self->{query}->param( $name );
	}
	else
	{
		@result = $self->{query}->param();
	}

	return( @result );

}


######################################################################
#
# set_param( $name, $value )
#
#  Set a query parameter, in case you want to change the default
#  for a form.
#
######################################################################

sub set_param
{
	my( $self, $name, $value ) = @_;

	$self->{query}->param( -name=>$name, -value=>$value );
}


######################################################################
#
# $value = form_value( $field )
#
#  A complement to param(). This reads in values from the form,
#  and puts them back into a value appropriate for the field type.
#
######################################################################

sub form_value
{
	my( $self, $field ) = @_;
	
	my $value = undef;
	
	if( $field->{type} eq "pagerange" )
	{
		my $from = $self->param( "$field->{name}_from" );
		my $to = $self->param( "$field->{name}_to" );

#EPrints::Log->debug ( "HTMLRender", "from: $from  to: $to" );

		if( !defined $to || $to eq "" )
		{
			$value = $from;
		}
		else
		{
			$value = $from . "-" . $to;
		}
	}
	elsif( $field->{type} eq "boolean" )
	{
		my $form_val = $self->param( $field->{name} );
		$value = ( defined $form_val ? "TRUE" : "FALSE" );
	}
	elsif( $field->{type} eq "date" )
	{
		my $day = $self->param( "$field->{name}_day" );
		my $month = $self->param( "$field->{name}_month" );
		my $year = $self->param( "$field->{name}_year" );

		if( defined $day && $month ne "00" && defined $year )
		{
			$value = $year."-".$month."-".$day;
		}
	}
	elsif( $field->{type} eq "set" )
	{
		my @tags = $self->{query}->param( $field->{name} );

		if( defined @tags )
		{
			$value = join ",", @tags;
			$value = ":$value:";
		}
	}
	elsif( $field->{type} eq "subjects" )
	{
		my $subject_list = EPrints::SubjectList->new();

		my @tags = $self->{query}->param( $field->{name} );
		
		if( defined @tags )
		{
			$subject_list->set_tags( \@tags );

			$value = $subject_list->to_string();
		}
		else
		{
			$value = undef;
		}
	}
	elsif( $field->{type} eq "name" )
	{
		my $i = 0;
		my $total = ( $field->{multiple} ? 
			$self->param( "name_boxes_$field->{name}" ) : 1 );
		
		for( $i=0; $i<$total; $i++ )
		{
			my $surname = $self->param( "name_surname_$i"."_$field->{name}" );
			if( defined $surname && $surname ne "" )
			{
				$value = EPrints::Name->add_name( $value,
					$surname,
					$self->param( "name_firstname_$i"."_$field->{name}" ) );
			}
		}
	}
	else
	{
		$value = $self->param( $field->{name} );
		$value = undef if( $value eq "" );
	}
	
	return( $value );
}


######################################################################
#
# clear()
#
#  Clears the form data.
#
######################################################################

sub clear
{
	my( $self ) = @_;
	
	$self->{query}->delete_all();
}



######################################################################
#
# $html = render_eprint_full( $eprint )
#
#  Return the EPrint, with all appropriate fields and formats
#  displayed.  Delegates to the site-specific routine to display the
#  record itself.
#
######################################################################

sub render_eprint_full
{
	my( $self, $eprint ) = @_;

	my $html = EPrintSite::SiteRoutines->eprint_render_full( $eprint );

	# Available formats
	my @documents = $eprint->get_all_documents();
	my $doc;

	$html .= "<P><CENTER><STRONG>Available Download Formats</STRONG>".
		"</CENTER></P>\n";

	$html .= "<CENTER><TABLE BORDER=0 CELLPADDING=3>\n";
	
	foreach $doc (@documents)
	{
		# Get the icon
		my $icon_filename = "doc-$doc->{format}.gif";
		
		# Does that specialised one exist?
		unless( -e
			$EPrintSite::SiteInfo::local_html_root . "/images/" . $icon_filename )
		{
			# Use the default
			$icon_filename = "doc-default.gif";
		}
		
		my $url = $doc->url();

		my $description =
			$EPrintSite::SiteInfo::supported_format_names{$doc->{format}};
		$description = $doc->{formatdesc}
			if( $doc->{format} eq $EPrints::Document::other );

		$html .= "<TR><TD><A HREF=\"$url\"><IMG ".
			"SRC=\"$EPrintSite::SiteInfo::server_static/images/$icon_filename\"".
			" ALT=\"$doc->{format}\" BORDER=0></A></TD><TD><A HREF=\"$url\">".
			"$description</A>".
			"</TD></TR>\n";
	}

	$html .= "</TABLE></CENTER>\n";

	return( $html );
}


######################################################################
#
# $html = render_eprint_citation( $eprint, $linked )
#
#  Render a citation for the given EPrint. If $linked is non-zero,
#  the citation will be rendered within a link to the static page.
#
######################################################################

sub render_eprint_citation
{
	my( $self, $eprint, $linked ) = @_;
	
	my $html = EPrintSite::SiteRoutines->eprint_render_citation( $eprint );
	
	if( $linked )
	{
		$html = "<A HREF=\"".$eprint->static_page_url()."\">$html</A>";
	}
	
	return( $html );
}


######################################################################
#
# $html = render_user( $user, $public )
#
#  Render a user as HTML. if $public==1, only public fields
#  will be shown.
#
######################################################################

sub render_user
{
	my( $self, $user, $public ) = @_;

	my $html= "<p><table border=0>\n";

	# Lob the row data into the relevant fields
	my @fields = EPrints::MetaInfo->get_user_fields();
	my $field;
	
	foreach $field (@fields)
	{
		if( !$public || $field->{visible} )
		{
			$html .= "<TR><TD>$field->{displayname}</TD><TD>";
			
			$html .= $self->format_field(
				$field,
				$user->{$field->{name}} );

			$html .= "</TD></TR>\n";
		}
	}
	
	$html .= "</table></p>\n";
	
	return( $html );
}


######################################################################
#
# $html = render_user_name( $user, $linked )
#
#  Render the current user as HTML. if $public==1, only public fields
#  will be shown.
#
######################################################################

sub render_user_name
{
	my( $self, $user, $linked ) = @_;

	my $html = "";
	
	$html = "<A HREF=\"$EPrintSite::SiteInfo::server_perl/cgi/staff/".
		"view_user?username=$user->{username}\">" if( $linked );

	$html .= EPrintSite::SiteRoutines->user_display_name( $user );

	$html .= "</A>" if( $linked );
	
	return( $html );
}


######################################################################
#
# $html = subject_tree( $subject )
#
#  Return HTML for a subject tree for the given subject. If $subject is
#  undef, the root subject is assumed.
#
#  The tree will feature the current tree, the parents up to the root,
#  and all children.
#
######################################################################

sub subject_tree
{
	my( $self, $subject ) = @_;

#EPrints::Log->debug( "HTMLRender", "Called with subject $subject->{subjectid}" );
	
	my $opened_lists = 0;
	my $html = "";
	
	# Get the parents
	my $parent = $subject->parent();
	my @parents;
	
	while( defined $parent )
	{
		push @parents, $parent;
		$parent = $parent->parent();
	}
	
	# Render the parents
	while( $#parents >= 0 )
	{
		$parent = pop @parents;
		
#EPrints::Log->debug( "HTMLRender", "Parent: $parent->{subjectid}" );

		$html .= "<UL>\n<LI>".$self->subject_desc( $parent, 1 )."</LI>\n";
		$opened_lists++;
	}
	
	# Render this subject
	if( defined $subject &&
		( $subject->{subjectid} ne $EPrints::Subject::root_subject ) )
	{
		$html .= "<UL>\n<LI>".$self->subject_desc( $subject, 0 )."</LI>\n";
		$opened_lists++;
	}
	
	# Render children
	$html .= $self->_render_children( $subject );

	my $i;

	for( $i = 0; $i < $opened_lists; $i++ )
	{
		$html .= "</UL>\n";
	}

	return( $html );
}

######################################################################
#
# $html = _render_children( $subject )
#
#  Recursively render the children of the given subject into HTML lists.
#
######################################################################

sub _render_children
{
	my( $self, $subject ) = @_;

#EPrints::Log->debug( "HTMLRender", "_render_children: $subject->{subjectid}" );

	my $html = "";
	my @children = $subject->children();

	if( $#children >= 0 )
	{
		$html .="<UL>\n";
	
		foreach (@children)
		{
			$html .= "<LI>".$self->subject_desc( $_, 1 )."\n";
			
			$html .= $self->_render_children( $_ );
			$html .= "</LI>\n";
		}
		
		$html .= "</UL>\n";
	}
	
	return( $html );
}


######################################################################
#
# $html = subject_desc( $subject, $link )
#
#  Return the HTML to render the title of $subject. If $link is non-zero,
#  the title is linked to the static subject view.
#
######################################################################

sub subject_desc
{
	my( $self, $subject, $link ) = @_;
	
#EPrints::Log->debug( "HTMLRender", "subject_desc: $subject->{subjectid}" );

	my $html = "";
	
	$html .= "<A HREF=\"$EPrintSite::SiteInfo::server_subject_view_stem"
		.$subject->{subjectid}.".html\">" if( $link );

	$html .= $subject->{name};
	
	$html .= "</A>" if( $link );

	if( $subject->{depositable} eq "TRUE" )
	{
		$html .= " (" .
			$subject->count_eprints( $EPrints::Database::table_archive ) . ")";
	}
	
	return( $html );
}

1; # For use/require success