######################################################################
#
# EPrints::Session
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=head1 NAME

B<EPrints::Session> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{foo}
#     undefined
#
######################################################################

######################################################################
#
# EPrint Session
#
######################################################################
#
#  __LICENSE__
#
######################################################################

# CGI scripts must be no-cache. Hmmm.

# cjg
# - Make sure user is ePrints for sessions
# - Check for df on startup

# cjg: Can INT be indexed but NULL'able???

package EPrints::Session;

use EPrints::Database;
use EPrints::Language;
use EPrints::Archive;
use EPrints::XML;

use Unicode::String qw(utf8 latin1);
use Apache;
use CGI;
use URI::Escape;

use strict;
#require 'sys/syscall.ph';

######################################################################
#
# new( $offline )
#
#  Start a new EPrints session, opening a database connection,
#  creating a CGI query object and any other necessary session state
#  things.
#
#  Command line scripts should pass in true for $offline.
#  Apache-invoked scripts can omit it or pass in 0.
#
######################################################################


######################################################################
=pod

=item $thing = EPrints::Session->new( $mode, $param, $noise, $nocheckdb )

undocumented

=cut
######################################################################

sub new
{
	my( $class, $mode, $param, $noise, $nocheckdb ) = @_;
	# mode = 0    - We are online (CGI script)
	# mode = 1    - We are offline (bin script) param is archiveid
	# mode = 2    - We are online (auth) param is host and path.	
	my $self = {};
	bless $self, $class;

	$noise = 0 unless defined( $noise );
	$self->{noise} = $noise;

	if( $mode == 0 || !defined $mode )
	{
		$self->{request} = Apache->request();
		$self->{query} = new CGI;
		$self->{offline} = 0;
		my $hp=$self->{request}->hostname.$self->{request}->uri;
		$self->{archive} = EPrints::Archive->new_archive_by_host_and_path( $hp );
		if( !defined $self->{archive} )
		{
			EPrints::Config::abort( "Can't load archive module for URL: ".
				$self->{query}->url()."\n"." ( hpcode=$hp, mode=0 )" );
		}
	}
	elsif( $mode == 1 )
	{
		$self->{query} = new CGI( {} );
		$self->{offline} = 1;
		if( !defined $param || $param eq "" )
		{
			print STDERR "No archive id specified.\n";
			return undef;
		}
		$self->{archive} = EPrints::Archive->new_archive_by_id( $param );
		if( !defined $self->{archive} )
		{
			print STDERR "Can't load archive module for: $param\n";
			return undef;
		}
	}
	elsif( $mode == 2 )
	{
		$self->{query} = new CGI( {} );
		$self->{offline} = 1;
		$self->{archive} = EPrints::Archive->new_archive_by_host_and_path( $param );
		if( !defined $self->{archive} )
		{
			EPrints::Config::abort( "Can't load archive module for URL: ".
				$self->{query}->url()."\n"." ( hpcode=$param, mode=2 )" );
		}
	}
	else
	{
		print STDERR "Unknown session mode: $mode\n";
		return undef;
	}

	#### Got Archive Config Module ###

	if( $self->{noise} >= 2 ) { print "\nStarting EPrints Session.\n"; }

	# What language is this session in?

	my $langcookie = $self->{query}->cookie( $self->{archive}->get_conf( "lang_cookie_name") );
	if( defined $langcookie && !grep( /^$langcookie$/, @{$self->{archive}->get_conf( "languages" )} ) )
	{
		$langcookie = undef;
	}

	$self->change_lang( $langcookie );
	#really only (cjg) ONLINE mode should have
	#a language set automatically.
	
	$self->{doc} = EPrints::XML::make_document;

	# Create a database connection
	if( $self->{noise} >= 2 ) { print "Connecting to DB ... "; }
	$self->{database} = EPrints::Database->new( $self );
	if( !defined $self->{database} )
	{
		# Database connection failure - noooo!
		$self->render_error( $self->html_phrase( 
			"lib/session:fail_db_connect" ) );
		return undef;
	}

	#cjg make this a method of EPrints::Database?
	unless( $nocheckdb )
	{
		# Check there are some tables.
		# Well, check for the most important table, which 
		# if it's not there is a show stopper.
		unless( $self->{database}->is_latest_version )
		{ 
			if( $self->{database}->has_table( "archive" ) )
			{	
				$self->get_archive()->log( 
	"Database tables are in old configuration. Please run bin/upgrade" );
			}
			else
			{
				$self->get_archive()->log( 
					"No tables in the MySQL database! ".
					"Did you run create_tables?" );
			}
			$self->{database}->disconnect();
			return undef;
		}
	}
	if( $self->{noise} >= 2 ) { print "done.\n"; }
	
	$self->{archive}->call( "session_init", $self, $self->{offline} );

	return( $self );
}

#
# terminate()
#
#  Perform any cleaning up necessary
#


######################################################################
=pod

=item $foo = $thing->terminate

undocumented

=cut
######################################################################

sub terminate
{
	my( $self ) = @_;
	
	$self->{database}->garbage_collect();
	$self->{archive}->call( "session_close", $self );
	$self->{database}->disconnect();

	# If we've not printed the XML page, we need to dispose of
	# it now.
	EPrints::XML::dispose( $self->{doc} );

	if( $self->{noise} >= 2 ) { print "Ending EPrints Session.\n\n"; }
}

#############################################################
#
# LANGUAGE FUNCTIONS
#
#############################################################


######################################################################
=pod

=item $foo = $thing->change_lang( $newlangid )

undocumented

=cut
######################################################################

sub change_lang
{
	my( $self, $newlangid ) = @_;

	if( !defined $newlangid )
	{
		$newlangid = $self->{archive}->get_conf( "defaultlanguage" );
	}
	$self->{lang} = $self->{archive}->get_language( $newlangid );

	if( !defined $self->{lang} )
	{
		die "Unknown language: $newlangid, can't go on!";
		# cjg (maybe should try english first...?)
	}
}


######################################################################
=pod

=item $foo = $thing->html_phrase( $phraseid, %inserts )

undocumented

=cut
######################################################################

sub html_phrase
{
	my( $self, $phraseid , %inserts ) = @_;
	# $phraseid [ASCII] 
	# %inserts [HASH: ASCII->DOM]
	#
	# returns [DOM]	

        my $r = $self->{lang}->phrase( $phraseid , \%inserts , $self );

	return $r;
}


######################################################################
=pod

=item $foo = $thing->phrase( $phraseid, %inserts )

undocumented

=cut
######################################################################

sub phrase
{
	my( $self, $phraseid, %inserts ) = @_;

	foreach( keys %inserts )
	{
		$inserts{$_} = $self->make_text( $inserts{$_} );
	}
        my $r = $self->{lang}->phrase( $phraseid, \%inserts , $self);
	my $string =  EPrints::Utils::tree_to_utf8( $r, 40 );
	EPrints::XML::dispose( $r );
	return $string;
}


######################################################################
=pod

=item $foo = $thing->get_langid

undocumented

=cut
######################################################################

sub get_langid
{
	my( $self ) = @_;

	return $self->{lang}->get_id();
}

#cjg: should be a util? or even a property of archive?

######################################################################
=pod

=item EPrints::Session::best_language( $archive, $lang, %values )

undocumented

=cut
######################################################################

sub best_language
{
	my( $archive, $lang, %values ) = @_;

	# no options?
	return undef if( scalar keys %values == 0 );

	# The language of the current session is best
	return $values{$lang} if( defined $lang && defined $values{$lang} );

	# The default language of the archive is second best	
	my $defaultlangid = $archive->get_conf( "defaultlanguage" );
	return $values{$defaultlangid} if( defined $values{$defaultlangid} );

	# Bit of personal bias: We'll try English before we just
	# pick the first of the heap.
	return $values{en} if( defined $values{en} );

	# Anything is better than nothing.
	my $akey = (keys %values)[0];
	return $values{$akey};
}


######################################################################
=pod

=item $foo = $thing->get_order_names( $dataset )

undocumented

=cut
######################################################################

sub get_order_names
{
	my( $self, $dataset ) = @_;
		
	my %names = ();
	foreach( keys %{$self->{archive}->get_conf(
			"order_methods",
			$dataset->confid() )} )
	{
		$names{$_}=$self->get_order_name( $dataset, $_ );
	}
	return( \%names );
}


######################################################################
=pod

=item $foo = $thing->get_order_name( $dataset, $orderid )

undocumented

=cut
######################################################################

sub get_order_name
{
	my( $self, $dataset, $orderid ) = @_;
	
        return $self->phrase( 
		"ordername_".$dataset->confid()."_".$orderid );
}


######################################################################
=pod

=item $foo = $thing->get_view_name( $dataset, $viewid )

undocumented

=cut
######################################################################

sub get_view_name
{
	my( $self, $dataset, $viewid ) = @_;

        return $self->phrase( 
		"viewname_".$dataset->confid()."_".$viewid );
}



#############################################################
#
# ACCESSOR(sp cjg) FUNCTIONS
#
#############################################################


######################################################################
=pod

=item $foo = $thing->get_db

undocumented

=cut
######################################################################

sub get_db
{
	my( $self ) = @_;
	return $self->{database};
}


######################################################################
=pod

=item $foo = $thing->get_query

undocumented

=cut
######################################################################

sub get_query
{
	my( $self ) = @_;
	return $self->{query};
}


######################################################################
=pod

=item $foo = $thing->get_archive

undocumented

=cut
######################################################################

sub get_archive
{
	my( $self ) = @_;
	return $self->{archive};
}

#
# $url = url()
#
#  Returns the URL of the current script
#


######################################################################
=pod

=item $foo = $thing->get_url

undocumented

=cut
######################################################################

sub get_url
{
	my( $self ) = @_;
	
	return( $self->{query}->url() );
}


######################################################################
=pod

=item $foo = $thing->get_noise

undocumented

=cut
######################################################################

sub get_noise
{
	my( $self ) = @_;
	
	return( $self->{noise} );
}


######################################################################
=pod

=item $foo = $thing->get_online

undocumented

=cut
######################################################################

sub get_online
{
	my( $self ) = @_;
	
	return( $self->{online} );
}



#############################################################
#
# DOM FUNCTIONS
#
#############################################################


######################################################################
=pod

=item $foo = $thing->make_element( $ename, %params )

undocumented

=cut
######################################################################

sub make_element
{
	my( $self , $ename , %params ) = @_;

	my $element = $self->{doc}->createElement( $ename );
	foreach( keys %params )
	{
		next unless( defined $params{$_} );
		$element->setAttribute( $_ , $params{$_} );
	}

	return $element;
}


######################################################################
=pod

=item $foo = $thing->make_indent( $width )

undocumented

=cut
######################################################################

sub make_indent
{
	my( $self, $width ) = @_;

	return $self->{doc}->createTextNode( "\n"." "x$width );
}

######################################################################
=pod

=item $foo = $thing->make_comment( $text )

undocumented

=cut
######################################################################

sub make_comment
{
	my( $self, $text ) = @_;

	return $self->{doc}->createComment( $text );
}
	

# $text is a UTF8 String!

######################################################################
=pod

=item $foo = $thing->make_text( $text )

undocumented

=cut
######################################################################

sub make_text
{
	my( $self , $text ) = @_;

	# patch up an issue with Unicode::String containing
	# an empty string -> seems to upset XML::GDOME
	if( !defined $text || $text eq "" )
	{
		$text = "";
	}
        
        $text =~ s/[\x00-\x08\x0B\x0C\x0E-\x1F]//g;

	my $textnode = $self->{doc}->createTextNode( $text );

	return $textnode;
}


######################################################################
=pod

=item $foo = $thing->make_doc_fragment

undocumented

=cut
######################################################################

sub make_doc_fragment
{
	my( $self ) = @_;

	return $self->{doc}->createDocumentFragment;
}



#############################################################
#
# XHTML FUNCTIONS
#
#############################################################


######################################################################
=pod

=item $foo = $thing->render_ruler

undocumented

=cut
######################################################################

sub render_ruler
{
	my( $self ) = @_;

	my $ruler = $self->{archive}->get_ruler();
	
	return $self->clone_for_me( $ruler, 1 );

	return $ruler;
}


######################################################################
=pod

=item $foo = $thing->render_data_element( $indent, $elementname, $value, %opts )

undocumented

=cut
######################################################################

sub render_data_element
{
	my( $self, $indent, $elementname, $value, %opts ) = @_;

	my $f = $self->make_doc_fragment();
	my $el = $self->make_element( $elementname, %opts );
	$el->appendChild( $self->make_text( $value ) );
	$f->appendChild( $self->make_indent( $indent ) );
	$f->appendChild( $el );

	return $f;
}


######################################################################
=pod

=item $foo = $thing->render_link( $uri, $target )

undocumented

=cut
######################################################################

sub render_link
{
	my( $self, $uri, $target ) = @_;

	return $self->make_element(
		"a",
		href=>EPrints::Utils::url_escape( $uri ),
		target=>$target );
}

######################################################################
=pod

=item $thing->render_name( $name, [$familylast] )

undocumented

=cut
######################################################################

sub render_name
{
	my( $self, $name, $familylast ) = @_;

	my $namestr = EPrints::Utils::make_name_string( $name, $familylast );
		
	return $self->make_text( $namestr );
}

######################################################################
=pod

=item $foo = $thing->render_option_list( %params )

undocumented

=cut
######################################################################

sub render_option_list
{
	my( $self , %params ) = @_;

	#params:
	# default  : array or scalar
	# height   :
	# multiple : allow multiple selections
	# pairs    :
	# values   :
	# labels   :
	# name     :

	my %defaults = ();
	if( ref( $params{default} ) eq "ARRAY" )
	{
		foreach( @{$params{default}} )
		{
			$defaults{$_} = 1;
		}
	}
	else
	{
		$defaults{$params{default}} = 1;
	}

	my $element = $self->make_element( "select" , name => $params{name} );
	if( defined $params{multiple} )
	{
		$element->setAttribute( "multiple" , $params{multiple} );
	}
	my $size = 0;
	if( defined $params{pairs} )
	{
		my $pair;
		foreach $pair ( @{$params{pairs}} )
		{
			$element->appendChild( 
				$self->render_single_option(
					$pair->[0],
					$pair->[1],
					$defaults{$pair->[0]} ) );
			$size++;
		}
	}
	else
	{
		foreach( @{$params{values}} )
		{
			$element->appendChild( 
				$self->render_single_option(
					$_,
					$params{labels}->{$_},
					$defaults{$_} ) );
			$size++;
			
						
		}
	}

	if( defined $params{height} )
	{
		if( $params{height} ne "ALL" )
		{
			$size = $params{height} if( $params{height} < $size );
			$size = 2 if( $params{height} > 1 && $size==1 );
		}
		$element->setAttribute( "size" , $size );
	}
	return $element;
}


######################################################################
=pod

=item $foo = $thing->render_single_option( $key, $desc, $selected )

undocumented

=cut
######################################################################

sub render_single_option
{
	my( $self, $key, $desc, $selected ) = @_;

	my $opt = $self->make_element( "option", value => $key );
	$opt->appendChild( $self->{doc}->createTextNode( $desc ) );

	if( $selected )
	{
		$opt->setAttribute( "selected" , "selected" );
	}
	return $opt;
}


######################################################################
=pod

=item $foo = $thing->render_hidden_field( $name, $value )

undocumented

=cut
######################################################################

sub render_hidden_field
{
	my( $self , $name , $value ) = @_;

	if( !defined $value ) 
	{
		$value = $self->param( $name );
	}

	return $self->make_element( "input",
		"accept-charset" => "utf-8",
		name => $name,
		value => $value,
		type => "hidden" );
}


######################################################################
=pod

=item $foo = $thing->render_upload_field( $name )

undocumented

=cut
######################################################################

sub render_upload_field
{
	my( $self, $name ) = @_;

	my $div = $self->make_element( "div" ); #no class cjg	
	$div->appendChild( $self->make_element(
		"input", 
		name => $name,
		type => "file" ) );
	return $div;
}


######################################################################
=pod

=item $foo = $thing->render_action_buttons( %buttons )

undocumented

=cut
######################################################################

sub render_action_buttons
{
	my( $self, %buttons ) = @_;

	return $self->_render_buttons_aux( "action" , %buttons );
}


######################################################################
=pod

=item $foo = $thing->render_internal_buttons( %buttons )

undocumented

=cut
######################################################################

sub render_internal_buttons
{
	my( $self, %buttons ) = @_;

	return $self->_render_buttons_aux( "internal" , %buttons );
}


# cjg buttons nead an order... They are done by a hash
######################################################################
# 
# $foo = $thing->_render_buttons_aux( $btype, %buttons )
#
# undocumented
#
######################################################################

sub _render_buttons_aux
{
	my( $self, $btype, %buttons ) = @_;

	#my $frag = $self->make_doc_fragment();
	my $frag = $self->make_element( "div", class=>"buttons" );

	my @order = keys %buttons;
	if( defined $buttons{_order} )
	{
		@order = @{$buttons{_order}};
	}

	my $button_id;
	foreach $button_id ( @order )
	{
		$frag->appendChild(
			$self->make_element( "input",
				class => $btype."button",
				type => "submit",
				name => "_".$btype."_".$button_id,
				value => $buttons{$button_id} ) );

		# Some space between butons.
		$frag->appendChild( $self->make_text( " " ) );
	}

	return( $frag );
}

## (dest is optional)
#cjg "POST" forms must be utf8 and multipart

######################################################################
=pod

=item $foo = $thing->render_form( $method, $dest )

undocumented

=cut
######################################################################

sub render_form
{
	my( $self, $method, $dest ) = @_;
	
	my $form = $self->{doc}->createElement( "form" );
	$form->setAttribute( "method", $method );
	$form->setAttribute( "accept-charset", "utf-8" );
	$dest = $ENV{SCRIPT_NAME} if( !defined $dest );
	$form->setAttribute( "action", $dest );
	if( "\L$method" eq "post" )
	{
		$form->setAttribute( "enctype", "multipart/form-data" );
	}
	return $form;
}


######################################################################
=pod

=item $foo = $thing->render_subjects( $subject_list, $baseid, $current, $linkmode, $sizes )

undocumented

=cut
######################################################################

sub render_subjects
{
	my( $self, $subject_list, $baseid, $current, $linkmode, $sizes ) = @_;

	# If sizes is defined then it contains a hash subjectid->#of subjects
	# we don't do this ourselves.

#cjg NO SUBJECT_LIST = ALL SUBJECTS under baseid!
	if( !defined $baseid )
	{
		$baseid = $EPrints::Subject::root_subject;
	}

	my %subs = ();
	foreach( @{$subject_list}, $baseid )
	{
		$subs{$_} = EPrints::Subject->new( $self, $_ );
	}

	return $self->_render_subjects_aux( \%subs, $baseid, $current, $linkmode, $sizes );
}

######################################################################
# 
# $foo = $thing->_render_subjects_aux( $subjects, $id, $current, $linkmode, $sizes )
#
# undocumented
#
######################################################################

sub _render_subjects_aux
{
	my( $self, $subjects, $id, $current, $linkmode, $sizes ) = @_;

	my( $ul, $li, $elementx );
	$ul = $self->make_element( "ul" );
	$li = $self->make_element( "li" );
	$ul->appendChild( $li );
	if( defined $current && $id eq $current )
	{
		$elementx = $self->make_element( "strong" );
	}
	else
	{
		if( $linkmode == 1 )
		{
			$elementx = $self->render_link( "edit_subject?subjectid=".$id ); 
		}
		elsif( $linkmode == 2 )
		{
			$elementx = $self->render_link( "$id.html" ); 
		}
		else
		{
			$elementx = $self->make_element( "span" );
		}
	}
	$li->appendChild( $elementx );
	$elementx->appendChild( $subjects->{$id}->render_description() );
	if( defined $sizes && $sizes->{$id} > 0 )
	{
		$elementx->appendChild( $self->make_text( " (".$sizes->{$id}.")" ) );
	}
		
	foreach( $subjects->{$id}->children() )
	{
		my $thisid = $_->get_value( "subjectid" );
		next unless( defined $subjects->{$thisid} );
		$li->appendChild( $self->_render_subjects_aux( $subjects, $thisid, $current, $linkmode, $sizes ) );
	}
	
	return $ul;
}



#
# $xhtml = render_subject_desc( $subject, $link, $full, $count )
#
#  Return the HTML to render the title of $subject. If $link is non-zero,
#  the title is linked to the static subject view. If $full is non-zero,
#  the full name of the subject is given. If $count is non-zero, the
#  number of eprints in that subject is appended in brackets.
#

# cjg icky call!

######################################################################
=pod

=item $foo = $thing->render_subject_desc( $subject, $link, $full, $count )

undocumented

=cut
######################################################################

sub render_subject_desc
{
	my( $self, $subject, $link, $full, $count ) = @_;
	
	my $frag;
	if( $link )
	{
		$frag = $self->render_link( $self->get_archive()->get_conf( "base_url" )."/view/".$subject->{subjectid}.".html" );
	}
	else
	{
		$frag = $self->make_doc_fragment();
	}
	

	if( defined $full && $full )
	{
		$frag->appendChild( $self->make_text(
			EPrints::Subject::subject_label(  #cjg!!
						$self,
		                                $subject->{subjectid} ) ) );
	}
	else
	{
		$frag->appendChild( $self->make_text( $subject->{name} ) );
	}
		
	if( $count && $subject->{depositable} eq "TRUE" )
	{
		my $text = $self->make_text( 
			latin1(" (" .$subject->count_eprints( 
				$self->get_archive()->get_dataset( "archive" ) ).
				")" ) );
		$frag->appendChild( $text );
	}
	
	return( $frag );
}


#
# $xhtml = render_error( $error_text, $back_to, $back_to_text )
#
#  Renders an error page with the given error text. A link, with the
#  text $back_to_text, is offered, the destination of this is $back_to,
#  which should take the user somewhere sensible.
#


######################################################################
=pod

=item $foo = $thing->render_error( $error_text, $back_to, $back_to_text )

undocumented

=cut
######################################################################

sub render_error
{
	my( $self, $error_text, $back_to, $back_to_text ) = @_;
	
	if( !defined $back_to )
	{
		$back_to = $self->get_archive()->get_conf( "frontpage" );
	}
	if( !defined $back_to_text )
	{
 #XXX INTL cjg not DOM
		$back_to_text = $self->make_text( "Continue" );
	}

	if ( $self->{offline} )
	{
		print $self->phrase( "lib/session:some_error" );
		print EPrints::Utils::tree_to_utf8( $error_text, 76 );
		print "\n";
		return;
	} 

	my( $p, $page, $a );
	$page = $self->make_doc_fragment();

	$page->appendChild( $self->html_phrase( "lib/session:some_error"));

	$p = $self->make_element( "p" );
	$p->appendChild( $error_text );
	$page->appendChild( $p );

	$page->appendChild( $self->html_phrase( "lib/session:contact" ) );
				
	$p = $self->make_element( "p" );
	$a = $self->render_link( $back_to ); 
	$a->appendChild( $back_to_text );
	$p->appendChild( $a );
	$page->appendChild( $p );

	$self->build_page(	
		$self->html_phrase( "lib/session:error_title" ),
		$page,
		"error" );

	$self->send_page();
}

#
# render_input_form( $fields,              #array_ref
#              $values,              #hash_ref
#              $show_names,
#              $show_help,
#              $action_buttons,      #array_ref
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
#  If $action_buttons isn't passed in (or is undefined), a simple
#  default "Submit" button is slapped on.
#
#  $dest should contain the URL of the destination
#

my %INPUT_FORM_DEFAULTS = (
	dataset => undef,
	type	=> undef,
	fields => [],
	values => {},
	show_names => 0,
	show_help => 0,
	staff => 0,
	buttons => {},
	hidden_fields => {},
	comments => {},
	dest => undef,
	default_action => undef
);


######################################################################
=pod

=item $foo = $thing->render_input_form( %p )

undocumented

=cut
######################################################################

sub render_input_form
{
	my( $self, %p ) = @_;

	foreach( %INPUT_FORM_DEFAULTS )
	{
		next if( defined $p{$_} );
		$p{$_} = $INPUT_FORM_DEFAULTS{$_};
	}

	my $query = $self->{query};

	my( $form );

	$form =	$self->render_form( "post", $p{dest} );
	if( defined $p{default_action} && $self->client() ne "LYNX" )
	{
		# This button will be the first on the page, so
		# if a user hits return and the browser auto-
		# submits then it will be this image button, not
		# the action buttons we look for.

		# It should be a small white on pixel PNG.
		# (a transparent GIF would be slightly better, but
		# GNU has a problem with GIF).
		# The style stops it rendering on modern broswers.
		# under lynx it looks bad. Lynx does not
		# submit when a user hits return so it's 
		# not needed anyway.
		$form->appendChild( $self->make_element( 
			"input", 
			type => "image", 
			width => 1, 
			height => 1, 
			border => 0,
			style => "display: none",
			src => $self->{archive}->get_conf( "base_url" )."/images/whitedot.png",
			name => "_default", 
			alt => $p{buttons}->{$p{default_action}} ) );
		$form->appendChild( $self->render_hidden_field(
			"_default_action",
			$p{default_action} ) );
	}

	my $field;	
	foreach $field (@{$p{fields}})
	{
		$form->appendChild( $self->_render_input_form_field( 
			$field,
			$p{values}->{$field->get_name()},
			$p{show_names},
			$p{show_help},
			$p{comments}->{$field->get_name()},
			$p{dataset},
			$p{type},
			$p{staff} ) );
	}

	# Hidden field, so caller can tell whether or not anything's
	# been POSTed
	$form->appendChild( $self->render_hidden_field( "_seen", "true" ) );

	foreach (keys %{$p{hidden_fields}})
	{
		$form->appendChild( $self->render_hidden_field( 
					$_, 
					$p{hidden_fields}->{$_} ) );
	}

	$form->appendChild( $self->render_action_buttons( %{$p{buttons}} ) );

	return $form;
}


######################################################################
# 
# $foo = $thing->_render_input_form_field( $field, $value, $show_names, $show_help, $comment, $dataset, $type, $staff )
#
# undocumented
#
######################################################################

sub _render_input_form_field
{
	my( $self, $field, $value, $show_names, $show_help, $comment,
			$dataset, $type, $staff ) = @_;
	
	my( $div, $html, $span );

	$html = $self->make_doc_fragment();

	my $req = $field->get_property( "required" );
	if( defined $dataset && defined $type )
	{
		$req = $dataset->field_required_in_type( $field, $type );
	}

	if( $show_names )
	{
		$div = $self->make_element( "div", class => "formfieldname" );

		# Field name should have a star next to it if it is required
		# special case for booleans - even if they're required it
		# dosn't make much sense to highlight them.	

		$div->appendChild( 
			$self->make_text( $field->display_name( $self ) ) );

		if( $req && !$field->is_type( "boolean" ) )
		{
			$span = $self->make_element( 
					"span", 
					class => "requiredstar" );	
			$span->appendChild( $self->make_text( "*" ) );	
			$div->appendChild( $self->make_text( " " ) );	
			$div->appendChild( $span );
		}
		$html->appendChild( $div );
	}

	if( $show_help )
	{
		my $help = $field->display_help( $self );

		$div = $self->make_element( "div", class => "formfieldhelp" );

		$div->appendChild( $self->make_text( $help ) );
		$html->appendChild( $div );
	}

	$div = $self->make_element( 
		"div", 
		class => "formfieldinput",
		id => "inputfield_".$field->get_name );
	$div->appendChild( $field->render_input_field( 
		$self, $value, $dataset, $type, $staff ) );
	$html->appendChild( $div );

	if( substr( $self->get_internal_button(), 0, length($field->get_name())+1 ) eq $field->get_name()."_" ) 
	{
		my $a = $self->make_element( "a", name=>"t" );
		$a->appendChild( $html );
		$html = $a;
	}
				
	return( $html );
}	













#############################################################
#
# CURRENT XHTML PAGE FUNCTIONS
#
#############################################################


######################################################################
=pod

=item $foo = $thing->build_page( $title, $mainbit, [$pageid], [$links] )

undocumented

=cut
######################################################################

sub build_page
{
	my( $self, $title, $mainbit, $pageid, $links ) = @_;

	if( defined $self->param( "mainonly" ) && $self->param( "mainonly" ) eq "yes" )
	{
		$self->{page} = $mainbit;
		return;
	}
	my $topofpage;

	my $map = {
		title => $title,
		page => $mainbit,
		pagetop => $topofpage,
		head => $links 
	};

	foreach( keys %{$map} )
	{
		if( !defined $map->{$_} )
		{
			$map->{$_} = $self->make_doc_fragment();
		}
	}

	my $pagehooks = $self->get_archive->get_conf( "pagehooks" );
	$pagehooks = {} if !defined $pagehooks;
	my $ph = $pagehooks->{$pageid} if defined $pageid;
	$ph = {} if !defined $ph;

	# only really useful for head & pagetop, but it might as
	# well support the others

	foreach( keys %{$map} )
	{
		if( defined $ph->{$_} )
		{
			my $pt = $self->make_doc_fragment;
			$pt->appendChild( $map->{$_} );
			my $ptnew = $self->clone_for_me(
				$ph->{$_},
				1 );
			$pt->appendChild( $ptnew );
			$map->{$_} = $pt;
		}
	}

	my $used = {};
	$self->{page} = $self->_process_page( 
		$self->{archive}->get_template( $self->get_langid ),
		$map,
		$used,
		$ph );

	foreach( keys %{$used} )
	{
		next if $used->{$_};
		EPrints::XML::dispose( $map->{$_} );
	}
	return;
}

sub _process_page
{
	my( $self, $node, $map, $used, $ph ) = @_;


	if( EPrints::XML::is_dom( $node, "Element" ) )
	{
		my $name = $node->getTagName;
		$name =~ s/^ep://;
		if( $name eq "pin" )
		{
			my $ref = $node->getAttribute( "ref" );
			my $insert = $map->{$ref};

			if( !defined $insert )
			{
				return $self->make_text(
					"[Missing pin: $ref]" );
			}

			if( $node->getAttribute( "textonly" ) eq "yes" )
			{
				return $self->make_text(
					EPrints::Utils::tree_to_utf8( 
						$insert ) );
			}

			if( !$used->{$ref} )
			{
				$used->{$ref} = 1;
				return $insert;
			}

			return EPrints::XML::clone_node( $insert );
		}
	}

	my $element = $self->clone_for_me( $node, 0 );


	# Handle extra attributes for <body> tag page hook.

	if( 	EPrints::XML::is_dom( $node, "Element" ) && 
		$node->getTagName eq "body" &&
		defined $ph->{bodyattr} )
	{
		foreach( keys %{$ph->{bodyattr}} )
		{
			$element->setAttribute( 
				$_, 
				$ph->{bodyattr}->{$_} );	
		}
	}

	
	foreach my $c ( $node->getChildNodes )
	{
		$element->appendChild(
			$self->_process_page(
				$c, 
				$map, 
				$used, 
				$ph ) );
	}
	return $element;
}


######################################################################
=pod

=item $foo = $thing->send_page( %httpopts )

undocumented

=cut
######################################################################

sub send_page
{
	my( $self, %httpopts ) = @_;
	$self->send_http_header( %httpopts );
	print EPrints::XML::to_string( $self->{page} );
	EPrints::XML::dispose( $self->{page} );
	delete $self->{page};
}


######################################################################
=pod

=item $foo = $thing->page_to_file( $filename )

undocumented

=cut
######################################################################

sub page_to_file
{
	my( $self , $filename ) = @_;
	
	EPrints::XML::write_xml_file( $self->{page}, $filename );
	EPrints::XML::dispose( $self->{page} );
	delete $self->{page};
}


######################################################################
=pod

=item $foo = $thing->set_page( $newhtml )

undocumented

=cut
######################################################################

sub set_page
{
	my( $self, $newhtml ) = @_;
	
	if( defined $self->{page} )
	{
		EPrints::XML::dispose( $self->{page} );
	}
	$self->{page} = $newhtml;
}


######################################################################
=pod

=item $foo = $thing->clone_for_me( $node, $deep )

undocumented

=cut
######################################################################

sub clone_for_me
{
	my( $self, $node, $deep ) = @_;

	return EPrints::XML::clone_and_own( $node, $self->{doc}, $deep );
}




###########################################################
#
# FUNCTIONS WHICH HANDLE INPUT FROM THE USER, BROWSER AND
# APACHE
#
###########################################################




#
# $param = param( $name )
#
#  Return a query parameter.
#


######################################################################
=pod

=item $foo = $thing->param( $name )

undocumented

=cut
######################################################################

sub param
{
	my( $self, $name ) = @_;

	if( !wantarray )
	{
		my $value = ( $self->{query}->param( $name ) );
		return $value;
	}
	
	# Called in an array context
	my @result;

	if( defined $name )
	{
		@result = $self->{query}->param( $name );
	}
	else
	{
		@result = $self->{query}->param;
	}

	return( @result );

}

# $bool = have_parameters()
#
#  Return true if the current script had any parameters (POST or GET)
#


######################################################################
=pod

=item $foo = $thing->have_parameters

undocumented

=cut
######################################################################

sub have_parameters
{
	my( $self ) = @_;
	
	my @names = $self->{query}->param();

	return( scalar @names > 0 );
}






######################################################################
=pod

=item $foo = $thing->auth_check( $resource )

undocumented

=cut
######################################################################

sub auth_check
{
	my( $self , $resource ) = @_;

	my $user = $self->current_user;

	if( !defined $user )
	{
		$self->render_error( $self->html_phrase( "lib/session:no_login" ) );
		return 0;
	}

	# Don't need to do any more if we aren't checking for a specific
	# resource.
	if( !defined $resource )
	{
		return 1;
	}

	unless( $user->has_priv( $resource ) )
	{
		$self->render_error( $self->html_phrase( "lib/session:no_priv" ) );
		return 0;
	}
	return 1;
}



######################################################################
=pod

=item $foo = $thing->current_user

undocumented

=cut
######################################################################

sub current_user
{
	my( $self ) = @_;

	my $user = undef;

	# If we've already done this once, no point
	# in doing it again.
	unless( defined $self->{currentuser} )
	{	
		my $username = $ENV{'REMOTE_USER'};

		if( defined $username && $username ne "" )
		{
			$self->{currentuser} = 
				EPrints::User::user_with_username( $self, $username );
		}
	}

	return $self->{currentuser};
}



######################################################################
=pod

=item $foo = $thing->seen_form

undocumented

=cut
######################################################################

sub seen_form
{
	my( $self ) = @_;
	
	my $result = 0;

	$result = 1 if( defined $self->{query}->param( "_seen" ) &&
	                $self->{query}->param( "_seen" ) eq "true" );

	return( $result );
}


######################################################################
=pod

=item $foo = $thing->internal_button_pressed( $buttonid )

undocumented

=cut
######################################################################

sub internal_button_pressed
{
	my( $self, $buttonid ) = @_;

	if( defined $buttonid )
	{
		return( defined $self->param( "_internal_".$buttonid ) );
	}

	# Have not yet worked this out?
	if( !defined $self->{internalbuttonpressed} )
	{
		my $p;
		# $p = string
		
		$self->{internalbuttonpressed} = 0;

		foreach $p ( $self->param() )
		{
			if( $p =~ m/^_internal/ )
			{
				$self->{internalbuttonpressed} = 1;
				last;
			}

		}	
	}

	return $self->{internalbuttonpressed};
}


######################################################################
=pod

=item $foo = $thing->get_action_button

undocumented

=cut
######################################################################

sub get_action_button
{
	my( $self ) = @_;

	my $p;
	# $p = string
	foreach $p ( $self->param() )
	{
		if( $p =~ m/^_action_/ )
		{
			return substr($p,8);
		}
	}

	# undef if _default is not set.
	return $self->param("_default_action");
}



######################################################################
=pod

=item $foo = $thing->get_internal_button

undocumented

=cut
######################################################################

sub get_internal_button
{
	my( $self ) = @_;

	if( defined $self->{internalbutton} )
	{
		return $self->{internalbutton};
	}

	my $p;
	# $p = string
	foreach $p ( $self->param() )
	{
		if( $p =~ m/^_internal_/ )
		{
			$self->{internalbutton} = substr($p,10);
			return $self->{internalbutton};
		}
	}

	$self->{internalbutton} = "";
	return $self->{internalbutton};
}

###########################################################
#
# OTHER FUNCTIONS
#
###########################################################


######################################################################
=pod

=item $foo = $thing->get_citation_spec( $dataset, $ctype )

undocumented

=cut
######################################################################

sub get_citation_spec
{
	my( $self, $dataset, $ctype ) = @_;

	my $citation_id = $dataset->confid();
	$citation_id.="_".$ctype if( defined $ctype );

	my $citespec = $self->{archive}->get_citation_spec( 
					$self->{lang}->get_id(), 
					$citation_id );

	if( !defined $citespec )
	{
		return $self->make_text( "Error: Unknown Citation Style \"$citation_id\"" );
	}
	
	my $r = $self->clone_for_me( $citespec, 1 );

	return $r;
}


######################################################################
=pod

=item EPrints::Session::microtime( microtime )

undocumented

=cut
######################################################################

sub microtime
{
        # disabled due to bug.
        return time();

        my $TIMEVAL_T = "LL";
	my $t = "";
	my @t = ();

        $t = pack($TIMEVAL_T, ());

      syscall( &SYS_gettimeofday, $t, 0) != -1
                or die "gettimeofday: $!";

        @t = unpack($TIMEVAL_T, $t);
        $t[1] /= 1_000_000;

        return $t[0]+$t[1];
}


#
# redirect( $url )
#
#  Redirects the browser to $url.
#


######################################################################
=pod

=item $foo = $thing->redirect( $url )

undocumented

=cut
######################################################################

sub redirect
{
	my( $self, $url ) = @_;

	# Write HTTP headers if appropriate
	unless( $self->{offline} )
	{
		# For some reason, redirection doesn't work with CGI::Apache.
		# We have to use CGI.
		print $self->{query}->redirect( -uri=>$url );
	}

}

#
# mail_administrator( $subject, $message )
#
#  Sends a mail to the archive administrator with the given subject and
#  message body.
#


######################################################################
=pod

=item $foo = $thing->mail_administrator( $subjectid, $messageid, %inserts )

undocumented

=cut
######################################################################

sub mail_administrator
{
	my( $self,   $subjectid, $messageid, %inserts ) = @_;
	#   Session, string,     string,     string->DOM

	# Mail the admin in the default language
	my $langid = $self->{archive}->get_conf( "defaultlanguage" );
	my $lang = $self->{archive}->get_language( $langid );

	return EPrints::Utils::send_mail(
		$self->{archive},
		$langid,
		EPrints::Utils::tree_to_utf8( 
			$lang->phrase( "lib/session:archive_admin", {}, $self ) ),
		$self->{archive}->get_conf( "adminemail" ),
		EPrints::Utils::tree_to_utf8( 
			$lang->phrase( $subjectid, {}, $self ) ),
		$lang->phrase( $messageid, \%inserts, $self ), 
		$lang->phrase( "mail_sig", {}, $self ) ); 
}


######################################################################
=pod

=item $foo = $thing->send_http_header( %opts )

undocumented

=cut
######################################################################

sub send_http_header
{
	my( $self, %opts ) = @_;

	# Write HTTP headers if appropriate
	if( $self->{offline} )
	{
		$self->{archive}->log( "Attempt to send HTTP Header while offline" );
		return;
	}

	if( !defined $opts{content_type} )
	{
		$opts{content_type} = 'text/html; charset=UTF-8';
	}
	$self->{request}->content_type( $opts{content_type} );

	$self->{request}->header_out( "Cache-Control"=>"must-revalidate" );

	#$self->{request}->header_out( "Cache-Control"=>"no-cache, must-revalidate" );
	# $self->{request}->header_out( "Pragma"=>"no-cache" );

	if( defined $opts{lang} )
	{
		my $cookie = $self->{query}->cookie(
			-name    => $self->{archive}->get_conf("lang_cookie_name"),
			-path    => "/",
			-value   => $opts{lang},
			-expires => "+10y", # really long time
			-domain  => $self->{archive}->get_conf("lang_cookie_domain") );
		$self->{request}->header_out( "Set-Cookie"=>$cookie ); 
	}
	$self->{request}->send_http_header;
}


######################################################################
=pod

=item $foo = $thing->client

undocumented

=cut
######################################################################

sub client
{
	my( $self ) = @_;

	my $client = $ENV{HTTP_USER_AGENT};

	# we return gecko, rather than mozilla, as
	# other browsers may use gecko renderer and
	# that's what why tailor output, on how it gets
	# rendered.

	# This isn't very rich in it's responses!

	return "GECKO" if( $client=~m/Gecko/i );
	return "LYNX" if( $client=~m/Lynx/i );
	return "MSIE4" if( $client=~m/MSIE 4/i );
	return "MSIE5" if( $client=~m/MSIE 5/i );
	return "MSIE6" if( $client=~m/MSIE 6/i );

	return "?";
}

# return the HTTP status.

######################################################################
=pod

=item $foo = $thing->get_http_status

undocumented

=cut
######################################################################

sub get_http_status
{
	my( $self ) = @_;

	return $self->{request}->status();
}


######################################################################
=pod

=item $foo = $thing->DESTROY

undocumented

=cut
######################################################################

sub DESTROY
{
	my( $self ) = @_;

	EPrints::Utils::destroy( $self );
}

######################################################################
=pod

=back

=cut

