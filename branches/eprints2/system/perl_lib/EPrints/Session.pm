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

B<EPrints::Session> - Single connection to the EPrints system

=head1 DESCRIPTION

This module is not really a session. The name is out of date, but
hard to change.

EPrints::Session represents a connection to the EPrints system. It
connects to a single EPrints repository, and the database used by
that repository. Thus it has an associated EPrints::Database and
EPrints::Archive object.

Each "session" has a "current language". If you are running in a 
multilingual mode, this is used by the HTML rendering functions to
choose what language to return text in.

The "session" object also knows about the current apache connection,
if there is one, including the CGI parameters. 

If the connection requires a username and password then it can also 
give access to the EPrints::User object representing the user who is
causing this request. 

The session object also provides many methods for creating XHTML 
results which can be returned via the web interface. 

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{archive}
#     The EPrints::Archive object this session relates to.
#
#  $self->{database}
#     A EPrints::Database object representing this session's connection
#     to the database.
#
#  $self->{noise}
#     The "noise" level which this connection should run at. Zero 
#     will produce only error messages. Higher numbers will produce
#     more warnings and commentary.
#
#  $self->{request}
#     A mod_perl object representing the request to apache, if any.
#
#  $self->{query}
#     A CGI.pm object also representing the request, if any.
#
#  $self->{offline}
#     True if this is a command-line script.
#
#  $self->{doc}
#     A XML DOM document object. All XML created by this session will
#     be part of this document.
#
#  $self->{page}
#     Used to store the output XHTML page between "build_page" and
#     "send_page"
#
#  $self->{lang}
#     The current language that this session should use. eg. "en" or "fr"
#     It is used to determine which phrases and template will be used.
#
######################################################################

package EPrints::Session;

use EPrints::Database;
use EPrints::Language;
use EPrints::Archive;
use EPrints::XML;

use EPrints::DataObj;
use EPrints::User;
use EPrints::EPrint;
use EPrints::Subject;
use EPrints::License;
use EPrints::Document;
use EPrints::History;
use EPrints::Plugin;

use Unicode::String qw(utf8 latin1);
use EPrints::AnApache;

#use URI::Escape;
use CGI qw(-compile);

use strict;
#require 'sys/syscall.ph';



######################################################################
=pod

=item $session = EPrints::Session->new( $mode, [$archiveid], [$noise], [$nocheckdb] )

Create a connection to an EPrints repository which provides access 
to the database and to the repository configuration.

This method can be called in two modes. Setting $mode to 0 means this
is a connection via a CGI web page. $archiveid is ignored, instead
the value is taken from the "PerlSetVar EPrints_ArchiveID" option in
the apache configuration for the current directory.

If this is being called from a command line script, then $mode should
be 1, and $archiveid should be the ID of the repository we want to
connect to.

$noise is the level of debugging output.
0 - silent
1 - quietish
2 - noisy
3 - debug all SQL statements
4 - debug database connection
 
Under normal conditions use "0" for online and "1" for offline.

$nocheckdb - if this is set to 1 then a connection is made to the
database without checking that the tables exist. 

=cut
######################################################################

sub new
{
	my( $class, $mode, $archiveid, $noise, $nocheckdb ) = @_;
	# mode = 0    - We are online (CGI script)
	# mode = 1    - We are offline (bin script) $archiveid is archiveid
	# mode = 2    - We are online, but don't create a CGI query (so we
	#  don't consume the data).
	my $self = {};
	bless $self, $class;

	$mode = 0 unless defined( $mode );
	$noise = 0 unless defined( $noise );
	$self->{noise} = $noise;

	if( $mode == 0 || $mode == 2 || !defined $mode )
	{
		$self->{request} = EPrints::AnApache::get_request();
		if( $mode == 0 ) { $self->{query} = new CGI; }
		$self->{offline} = 0;
		$self->{archive} = EPrints::Archive->new_from_request( $self->{request} );
	}
	elsif( $mode == 1 )
	{
		$self->{offline} = 1;
		if( !defined $archiveid || $archiveid eq "" )
		{
			print STDERR "No archive id specified.\n";
			return undef;
		}
		$self->{archive} = EPrints::Archive->new_archive_by_id( $archiveid );
		if( !defined $self->{archive} )
		{
			print STDERR "Can't load archive module for: $archiveid\n";
			return undef;
		}
	}
	else
	{
		print STDERR "Unknown session mode: $mode\n";
		return undef;
	}

	#### Got Archive Config Module ###

	if( $self->{noise} >= 2 ) { print "\nStarting EPrints Session.\n"; }

	if( $self->{offline} )
	{
		# Set a script to use the default language unless it 
		# overrides it
		$self->change_lang( 
			$self->{archive}->get_conf( "defaultlanguage" ) );
	}
	else
	{
		# running as CGI, Lets work out what language the
		# client wants...
		$self->change_lang( get_session_language( 
			$self->{archive}, 
			$self->{request} ) );
	}
	
	$self->{doc} = EPrints::XML::make_document;

	# Create a database connection
	if( $self->{noise} >= 2 ) { print "Connecting to DB ... "; }
	$self->{database} = EPrints::Database->new( $self );
	if( !defined $self->{database} )
	{
		# Database connection failure - noooo!
		$self->render_error( $self->html_phrase( 
			"lib/session:fail_db_connect" ) );
#$self->get_archive->log( "Failed to connect to database." );
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

######################################################################
=pod

=item $request = $session->get_request;

Return the Apache request object (from mod_perl) or undefined if 
this isn't a CGI script.

=cut
######################################################################


sub get_request
{
	my( $self ) = @_;

	return $self->{request};
}

######################################################################
=pod

=item $query = $session->get_query;

Return the CGI.pm object describing the current HTTP query, or 
undefined if this isn't a CGI script.

=cut
######################################################################

sub get_query
{
	my( $self ) = @_;

	return $self->{query};
}

######################################################################
=pod

=item $session->terminate

Perform any cleaning up necessary, for example SQL cache tables which
are no longer needed.

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

	# give garbage collection a hand.
	foreach( keys %{$self} ) { delete $self->{$_}; } 
}



#############################################################
#############################################################
=pod

=back

=head2 Language Related Methods

=over 4

=cut
#############################################################
#############################################################


######################################################################
=pod

=item $langid = EPrints::Session::get_session_language( $archive, $request )

Given an archive object and a Apache (mod_perl) request object, this
method decides what language the session should be.

First it looks at the HTTP cookie "lang_cookie_name", failing that it
looks at the prefered language of the request from the HTTP header,
failing that it looks at the default language for the archive.

The language ID it returns is the highest on the list that the given
eprint archive actually supports.

=cut
######################################################################

sub get_session_language
{
	my( $archive, $request ) = @_; #$r should not really be passed???

	my @prefs;

	# IMPORTANT! This function must not consume
	# The post request, if any.

	my $cookies = EPrints::AnApache::header_in( 
				$request,
				'Cookie' );
	if( defined $cookies )
	{
		foreach my $cookie ( split( /;\s*/, $cookies ) )
		{
			my( $k, $v ) = split( '=', $cookie );
			if( $k eq $archive->get_conf( "lang_cookie_name") )
			{
				push @prefs, $v;
			}
		}
	}

	# then look at the accept language header
	my $accept_language = EPrints::AnApache::header_in( 
				$request,
				"Accept-Language" );

	if( defined $accept_language )
	{
		# Middle choice is exact browser setting
		foreach my $browser_lang ( split( /, */, $accept_language ) )
		{
			$browser_lang =~ s/;.*$//;
			push @prefs, $browser_lang;
		}
	
		# Next choice is general browser setting (so fr-ca matches
		#	'fr' rather than default to 'en')
		foreach my $browser_lang ( split( /, */, $accept_language ) )
		{
			$browser_lang =~ s/-.*$//;
			push @prefs, $browser_lang;
		}
	}
		
	# last choice is always...	
	push @prefs, $archive->get_conf( "defaultlanguage" );

	# So, which one to use....
	my $arc_langs = $archive->get_conf( "languages" );	
	foreach my $pref_lang ( @prefs )
	{
		foreach my $langid ( @{$arc_langs} )
		{
			if( $pref_lang eq $langid )
			{
				# it's a real language id, go with it!
				return $pref_lang;
			}
		}
	}

	print STDERR <<END;
Something odd happend in the language selection code... 
Did you make a default language which is not in the list of languages?
END
	return undef;
}

######################################################################
=pod

=item $session->change_lang( $newlangid )

Change the current language of the session. $newlangid should be a
valid country code for the current archive.

An invalid code will cause eprints to terminate with an error.

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

=item $xhtml_phrase = $session->html_phrase( $phraseid, %inserts )

Return an XHTML DOM object describing a phrase from the phrase files.

$phraseid is the id of the phrase to return. If the same ID appears
in both the archive-specific phrases file and the system phrases file
then the archive-specific one is used.

If the phrase contains <ep:pin> elements, then each one should have
an entry in %inserts where the key is the "ref" of the pin and the
value is an XHTML DOM object describing what the pin should be 
replaced with.

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

	#my $s = $self->make_element( "span", title=>$phraseid );
	#$s->appendChild( $r );
	#return $s;

	return $r;
}


######################################################################
=pod

=item $utf8_text = $session->phrase( $phraseid, %inserts )

Performs the same function as html_phrase, but returns plain text.

All HTML elements will be removed, <br> and <p> will be converted 
into breaks in the text. <img> tags will be replaced with their 
"alt" values.

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

=item $language = $session->get_lang

Return the EPrints::Language object for this sessions current 
language.

=cut
######################################################################

sub get_lang
{
	my( $self ) = @_;

	return $self->{lang};
}


######################################################################
=pod

=item $langid = $session->get_langid

Return the ID code of the current language of this session.

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

=item $value = EPrints::Session::best_language( $archive, $lang, %values )

$archive is the current archive. $lang is the prefered language.

%values contains keys which are language ids, and values which is
text or phrases in those languages, all translations of the same 
thing.

This function returns one of the values from %values based on the 
following logic:

If possible, return the value for $lang.

Otherwise, if possible return the value for the default language of
this archive.

Otherwise, if possible return the value for "en" (English).

Otherwise just return any one value.

This means that the view sees the best possible phrase. 

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

=item $names = $session->get_order_names( $dataset )

Return a reference to a hash.

The keys of this hash are the id's of the orderings of the dataset
available to the public. eg. "byyear", "title" etc.

The values are UTF8 strings containing the human-readable version,
eg. "By Year".

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

=item $name = $session->get_order_name( $dataset, $orderid )

Return a UTF8 encoded string describing the human readable name of
the ordering with ID $orderid in $dataset. For example, by default,
"byyearoldest" will return "By Year (Oldest First)"

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

=item $viewname = $session->get_view_name( $dataset, $viewid )

Return a UTF8 encoded string containing the human readable name
of the /view/ section with the ID $viewid.

=cut
######################################################################

sub get_view_name
{
	my( $self, $dataset, $viewid ) = @_;

        return $self->phrase( 
		"viewname_".$dataset->confid()."_".$viewid );
}




#############################################################
#############################################################
=pod

=back

=head2 Accessor Methods

=over 4

=cut
#############################################################
#############################################################


######################################################################
=pod

=item $db = $session->get_db

Return the current EPrints::Database connection.

=cut
######################################################################

sub get_db
{
	my( $self ) = @_;
	return $self->{database};
}



######################################################################
=pod

=item $archive = $session->get_archive

Return the EPrints::Archive object associated with the Session.

=cut
######################################################################

sub get_archive
{
	my( $self ) = @_;
	return $self->{archive};
}


######################################################################
=pod

=item $uri = $session->get_uri

Returns the URL of the current script. Or "undef".

=cut
######################################################################

sub get_uri
{
	my( $self ) = @_;

	return undef unless defined $self->{request};

	return( $self->{"request"}->uri );
}


######################################################################
=pod

=item $noise_level = $session->get_noise

Return the noise level for the current session. See the explaination
under EPrints::Session->new()

=cut
######################################################################

sub get_noise
{
	my( $self ) = @_;
	
	return( $self->{noise} );
}


######################################################################
=pod

=item $boolean = $session->get_online

Return true if this script is running via CGI, return false if we're
on the command line.

=cut
######################################################################

sub get_online
{
	my( $self ) = @_;
	
	return( $self->{online} );
}




#############################################################
#############################################################
=pod

=back

=head2 DOM Related Methods

These methods help build XML. Usually, but not always XHTML.

=over 4

=cut
#############################################################
#############################################################


######################################################################
=pod

=item $dom = $session->make_element( $element_name, %attribs )

Return a DOM element with name ename and the specified attributes.

eg. $session->make_element( "img", src => "/foo.gif", alt => "my pic" )

Will return the DOM object describing:

<img src="/foo.gif" alt="my pic" />

Note that in the call we use "=>" not "=".

=cut
######################################################################

sub make_element
{
	my( $self , $ename , %attribs ) = @_;

	my $element = $self->{doc}->createElement( $ename );
	foreach( keys %attribs )
	{
		next unless( defined $attribs{$_} );
		my $value = "$attribs{$_}"; # ensure it's just a string
		$element->setAttribute( $_ , $value );
	}

	return $element;
}


######################################################################
=pod

=item $dom = $session->make_indent( $width )

Return a DOM object describing a C.R. and then $width spaces. This
is used to make nice looking XML for things like the OAI interface.

=cut
######################################################################

sub make_indent
{
	my( $self, $width ) = @_;

	return $self->{doc}->createTextNode( "\n"." "x$width );
}

######################################################################
=pod

=item $dom = $session->make_comment( $text )

Return a DOM object describing a comment containing $text.

eg.

<!-- this is a comment -->

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

=item $DOM = $session->make_text( $text )

Return a DOM object containing the given text. $text should be
UTF-8 encoded.

Characters will be treated as _text_ including < > etc.

eg.

$session->make_text( "This is <b> an example" );

Would return a DOM object representing the XML:

"This is &lt;b&gt; an example"

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

=item $fragment = $session->make_doc_fragment

Return a new XML document fragment. This is an item which can have
XML elements added to it, but does not actually get rendered itself.

If appended to an element then it disappears and its children join
the element at that point.

=cut
######################################################################

sub make_doc_fragment
{
	my( $self ) = @_;

	return $self->{doc}->createDocumentFragment;
}






#############################################################
#############################################################
=pod

=back

=head2 XHTML Related Methods

These methods help build XHTML.

=over 4

=cut
#############################################################
#############################################################




######################################################################
=pod

=item $ruler = $session->render_ruler

Return the XHTML which this archive uses as a page divider. Configured
in ruler.xml

=cut
######################################################################

sub render_ruler
{
	my( $self ) = @_;

	my $ruler = $self->{archive}->get_ruler();
	
	return $self->clone_for_me( $ruler, 1 );
}

######################################################################
=pod

=item $nbsp = $session->render_nbsp

Return an XHTML &nbsp; character.

=cut
######################################################################

sub render_nbsp
{
	my( $self ) = @_;

	my $string = latin1(chr(160));

	return $self->make_text( $string );
}

######################################################################
=pod

=item $xhtml = $session->render_data_element( $indent, $elementname, $value, [%opts] )

This is used to help render neat XML data. It returns a fragment 
containing an element of name $elementname containing the value
$value, the element is indented by $indent spaces.

The %opts describe any extra attributes for the element

eg.
$session->render_data_element( 4, "foo", "bar", class=>"fred" )

would return a XML DOM object describing:
    <foo class="fred">bar</foo>

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

=item $xhtml = $session->render_link( $uri, [$target] )

Returns an HTML link to the given uri, with the optional $target if
it needs to point to a different frame or window.

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

=item $table_row = $session->render_row( $key, $value );

Return the key and value in a DOM encoded HTML table row. eg.

 <tr><th>$key:</th><td>$value</td></tr>

=cut
######################################################################

sub render_row
{
	my( $session, $key, $value ) = @_;

	my( $tr, $th, $td );

	$tr = $session->make_element( "tr" );

	$th = $session->make_element( "th", valign=>"top" ); 
	$th->appendChild( $key );
	$th->appendChild( $session->make_text( ":" ) );
	$tr->appendChild( $th );

	$td = $session->make_element( "td", valign=>"top" ); 
	$td->appendChild( $value );
	$tr->appendChild( $td );

	return $tr;
}



######################################################################
=pod

=item $xhtml = $session->render_language_name( $langid ) 
Return a DOM object containing the description of the specified language
in the current default language, or failing that from languages.xml

=cut
######################################################################

sub render_language_name
{
	my( $self, $langid ) = @_;

	my $phrasename = 'language:'.$langid;
	if( $self->get_lang->has_phrase( $phrasename ) )
	{	
		return $self->html_phrase( $phrasename );
	}

	return $self->make_text( EPrints::Config::lang_title( $langid ) );
}

######################################################################
=pod

=item $xhtml_name = $session->render_name( $name, [$familylast] )

$name is a ref. to a hash containing family, given etc.

Returns an XML DOM fragment with the name rendered in the manner
of the archive. Usually "John Smith".

If $familylast is set then the family and given parts are reversed, eg.
"Smith, John"

=cut
######################################################################

sub render_name
{
	my( $self, $name, $familylast ) = @_;

	my $namestr = EPrints::Utils::make_name_string( $name, $familylast );

	my $span = $self->make_element( "span", class=>"person_name" );
		
	$span->appendChild( $self->make_text( $namestr ) );

	return $span;
}

######################################################################
=pod

=item $xhtml_select = $session->render_option_list( %params )

This method renders an XHTML <select>. The options are complicated
and may change, so it's better not to use it.

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
	# defaults_at_top : move items already selected to top
	# 			of list, so they are visible.

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
	if( $params{multiple} )
	{
		$element->setAttribute( "multiple" , "multiple" );
	}

	my $dtop = defined $params{defaults_at_top} && $params{defaults_at_top};


	my @alist = ();
	my @list = ();
	my $pairs = $params{pairs};
	if( !defined $pairs )
	{
		foreach( @{$params{values}} )
		{
			push @{$pairs}, [ $_, $params{labels}->{$_} ];
		}
	}		
						
	if( $dtop && scalar keys %defaults )
	{
		my @pairsa;
		my @pairsb;
		foreach my $pair (@{$pairs})
		{
			if( $defaults{$pair->[0]} )
			{
				push @pairsa, $pair;
			}
			else
			{
				push @pairsb, $pair;
			}
		}
		$pairs = [ @pairsa, [ '-', '----------' ], @pairsb ];
	}


	my $size = 0;
	foreach my $pair ( @{$pairs} )
	{
		$element->appendChild( 
			$self->render_single_option(
				$pair->[0],
				$pair->[1],
				$defaults{$pair->[0]} ) );
		$size++;
	}

	if( defined $params{height} )
	{
		if( $params{height} ne "ALL" )
		{
			if( $params{height} < $size )
			{
				$size = $params{height};
			}
		}
		$element->setAttribute( "size" , $size );
	}
	return $element;
}



######################################################################
=pod

=item $option = $session->render_single_option( $key, $desc, $selected )

Used by render_option_list.

=cut
######################################################################

sub render_single_option
{
	my( $self, $key, $desc, $selected ) = @_;

	my $opt = $self->make_element( "option", value => $key );
	$opt->appendChild( $self->make_text( $desc ) );

	if( $selected )
	{
		$opt->setAttribute( "selected" , "selected" );
	}
	return $opt;
}


######################################################################
=pod

=item $xhtml_hidden = $session->render_hidden_field( $name, $value )

Return the XHTML DOM describing an <input> element of type "hidden"
and name and value as specified. eg.

<input type="hidden" accept-charset="utf-8" name="foo" value="bar" />

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

=item $xhtml_uploda = $session->render_upload_field( $name )

Render into XHTML DOM a file upload form button with the given name. 

eg.
<input type="file" name="foo" />

=cut
######################################################################

sub render_upload_field
{
	my( $self, $name ) = @_;

#	my $div = $self->make_element( "div" ); #no class cjg	
#	$div->appendChild( $self->make_element(
#		"input", 
#		name => $name,
#		type => "file" ) );
#	return $div;

	return $self->make_element(
		"input",
		name => $name,
		type => "file" );

}


######################################################################
=pod

=item $dom = $session->render_action_buttons( %buttons )

Returns a DOM object describing the set of buttons.

The keys of %buttons are the ids of the action that button will cause,
the values are UTF-8 text that should appear on the button.

Two optional additional keys may be used:

_order => [ "action1", "action2" ]

will force the buttons to appear in a set order.

_class => "my_css_class" 

will add a class attribute to the <div> containing the buttons to 
allow additional styling.

=cut
######################################################################

sub render_action_buttons
{
	my( $self, %buttons ) = @_;

	return $self->_render_buttons_aux( "action" , %buttons );
}


######################################################################
=pod

=item $dom = $session->render_internal_buttons( %buttons )

As for render_action_buttons, but creates buttons for actions which
will modify the state of the current form, not continue with whatever
process the form is part of.

eg. the "More Spaces" button and the up and down arrows on multiple
type fields.

=cut
######################################################################

sub render_internal_buttons
{
	my( $self, %buttons ) = @_;

	return $self->_render_buttons_aux( "internal" , %buttons );
}


######################################################################
# 
# $dom = $session->_render_buttons_aux( $btype, %buttons )
#
######################################################################

sub _render_buttons_aux
{
	my( $self, $btype, %buttons ) = @_;

	#my $frag = $self->make_doc_fragment();
	my $class = "buttons";
	if( defined $buttons{_class} )
	{
		$class = $buttons{_class};
	}
	my $div = $self->make_element( "div", class=>$class );

	my @order = keys %buttons;
	if( defined $buttons{_order} )
	{
		@order = @{$buttons{_order}};
	}

	my $button_id;
	foreach $button_id ( @order )
	{
		# skip options which start with a "_" they are params
		# not buttons.
		next if( $button_id eq '_class' );
		next if( $button_id eq '_order' );
		$div->appendChild(
			$self->make_element( "input",
				class => $btype."button",
				type => "submit",
				name => "_".$btype."_".$button_id,
				value => $buttons{$button_id} ) );

		# Some space between butons.
		$div->appendChild( $self->make_text( " " ) );
	}

	return( $div );
}

######################################################################
=pod

=item $dom = $session->render_form( $method, $dest )

Return a DOM object describing an HTML form element. 

$method should be "GET" or "POST"

$dest is the target of the form. By default the current page.

eg.

$session->render_form( "GET", "http://example.com/perl/foo" );

returns a DOM object representing:

<form method="GET" action="http://example.com/perl/foo" accept-charset="utf-8" />

If $method is "POST" then an addition attribute is set:
enctype="multipart/form-data" 

This just controls how the data is passed from the browser to the
CGI library. You don't need to worry about it.

=cut
######################################################################

sub render_form
{
	my( $self, $method, $dest ) = @_;
	
	my $form = $self->{doc}->createElement( "form" );
	$form->setAttribute( "method", $method );
	$form->setAttribute( "accept-charset", "utf-8" );
	if( !defined $dest )
	{
		$dest = $self->get_uri;
	}
	$form->setAttribute( "action", $dest );
	if( "\L$method" eq "post" )
	{
		$form->setAttribute( "enctype", "multipart/form-data" );
	}
	return $form;
}


######################################################################
=pod

=item $ul = $session->render_subjects( $subject_list, [$baseid], [$currentid], [$linkmode], [$sizes] )

Return as XHTML DOM a nested set of <ul> and <li> tags describing
part of a subject tree.

$subject_list is a array ref of subject ids to render.

$baseid is top top level node to render the tree from. If only a single
subject is in subject_list, all subjects up to $baseid will still be
rendered. Default is the ROOT element.

If $currentid is set then the subject with that ID is rendered in
<strong>

$linkmode can 0, 1, 2 or 3.

0. Don't link the subjects.

1. Links subjects to the URL which edits them in edit_subjects.

2. Links subjects to "subjectid.html" (where subjectid is the id of 
the subject)

3. Links the subjects to "subjectid/".  $sizes must be set. Only 
subjects with a size of more than one are linked.

$sizes may be a ref. to hash mapping the subjectid's to the number
of items in that subject which will be rendered in brackets next to
each subject.

=cut
######################################################################

sub render_subjects
{
	my( $self, $subject_list, $baseid, $currentid, $linkmode, $sizes ) = @_;

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

	return $self->_render_subjects_aux( \%subs, $baseid, $currentid, $linkmode, $sizes );
}

######################################################################
# 
# $ul = $session->_render_subjects_aux( $subjects, $id, $currentid, $linkmode, $sizes )
#
# Recursive subroutine needed by render_subjects.
#
######################################################################

sub _render_subjects_aux
{
	my( $self, $subjects, $id, $currentid, $linkmode, $sizes ) = @_;

	my( $ul, $li, $elementx );
	$ul = $self->make_element( "ul" );
	$li = $self->make_element( "li" );
	$ul->appendChild( $li );
	if( defined $currentid && $id eq $currentid )
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
			$elementx = $self->render_link( 
				EPrints::Utils::escape_filename( $id ).
					".html" ); 
		}
		elsif( $linkmode == 3 )
		{
			if( defined $sizes && defined $sizes->{$id} && $sizes->{$id} > 0 )
			{
				$elementx = $self->render_link( 
					EPrints::Utils::escape_filename( $id ).
						"/" ); 
			}
			else
			{
				$elementx = $self->make_element( "span" );
			}
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
		$li->appendChild( $self->_render_subjects_aux( $subjects, $thisid, $currentid, $linkmode, $sizes ) );
	}
	
	return $ul;
}



######################################################################
=pod

=item $session->render_error( $error_text, $back_to, $back_to_text )

Renders an error page with the given error text. A link, with the
text $back_to_text, is offered, the destination of this is $back_to,
which should take the user somewhere sensible.

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
		$back_to_text = $self->html_phrase( "lib/session:continue");
	}

	my $textversion = '';
	$textversion.= $self->phrase( "lib/session:some_error" );
	$textversion.= EPrints::Utils::tree_to_utf8( $error_text, 76 );
	$textversion.= "\n";

	if ( $self->{offline} )
	{
		print $textversion;
		return;
	} 

	# send text version to log
	$self->get_archive->log( $textversion );

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

=item $dom = $session->render_input_form( %params )

Return a DOM object representing an entire input form.

%params contains the following options:

dataset: The EPrints::Dataset to which the form relates, if any.

fields: a reference to an array of EPrint::MetaField objects,
which describe the fields to be added to the form.

values: a set of default values. A reference to a hash where
the keys are ID's of fields, and the values are the default
values for those fields.

show_help: if true, show the fieldhelp phrase for each input 
field.

show_name: if true, show the fieldname phrase for each input 
field.

buttons: a description of the buttons to appear at the bottom
of the form. See render_action_buttons for details.

top_buttons: a description of the buttons to appear at the top
of the form (optional).

default_action: the id of the action to be performed by default, 
ie. if the user pushes "return" in a text field.

dest: The URL of the target for this form. If not defined then
the current URI is used.

type: if this form relates to a user or an eprint, the type of
eprint/user can effect what fields are flagged as required. This
param contains the ID of the eprint/user if any, and if relevant.

staff: if true, this form is being presented to archive staff 
(admin, or editor). This may change which fields are required.

hidden_fields: reference to a hash. The keys of which are CGI keys
and the values are the values they are set to. This causes hidden
form elements to be set, so additional information can be passed.

comment: not yet used.

=cut
######################################################################

sub render_input_form
{
	my( $self, %p ) = @_;

	foreach( keys %INPUT_FORM_DEFAULTS )
	{
		next if( defined $p{$_} );
		$p{$_} = $INPUT_FORM_DEFAULTS{$_};
	}

	my( $form );

	$form =	$self->render_form( "post", $p{dest} );
	if( defined $p{default_action} && $self->client() ne "LYNX" )
	{
		my $imagesurl = $self->get_archive->get_conf( "base_url" )."/images";
		my $esec = $self->get_request->dir_config( "EPrints_Secure" );
		if( defined $esec && $esec eq "yes" )
		{
			$imagesurl = $self->get_archive->get_conf( "securepath" )."/images";
		}
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
			src => "$imagesurl/whitedot.png",
			name => "_default", 
			alt => $p{buttons}->{$p{default_action}} ) );
		$form->appendChild( $self->render_hidden_field(
			"_default_action",
			$p{default_action} ) );
	}

	if( defined $p{top_buttons} )
	{
		$form->appendChild( $self->render_action_buttons( %{$p{top_buttons}} ) );
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
			$p{staff},
			$p{hidden_fields} ) );
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
	if( defined $p{comments}->{above_buttons} )
	{
		$form->appendChild( $p{comments}->{above_buttons} );
	}

	$form->appendChild( $self->render_action_buttons( %{$p{buttons}} ) );

	return $form;
}


######################################################################
# 
# $xhtml_field = $session->_render_input_form_field( $field, $value, $show_names, $show_help, $comment, $dataset, $type, $staff, $hiddenfields )
#
# Render a single field in a form being rendered by render_input_form
#
######################################################################

sub _render_input_form_field
{
	my( $self, $field, $value, $show_names, $show_help, $comment,
			$dataset, $type, $staff, $hidden_fields ) = @_;
	
	my( $div, $html, $span );

	$html = $self->make_doc_fragment();

	if( substr( $self->get_internal_button(), 0, length($field->get_name())+1 ) eq $field->get_name()."_" ) 
	{
		my $a = $self->make_element( "a", name=>"t" );
		$html->appendChild( $a );
	}

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

		$div->appendChild( $field->render_name( $self ) );

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
		$div = $self->make_element( "div", class => "formfieldhelp" );

		$div->appendChild( $field->render_help( $self, $type ) );
		$div->appendChild( $self->make_text( "" ) );

		$html->appendChild( $div );
	}

	$div = $self->make_element( 
		"div", 
		class => "formfieldinput",
		id => "inputfield_".$field->get_name );
	$div->appendChild( $field->render_input_field( 
		$self, $value, $dataset, $type, $staff, $hidden_fields ) );
	$html->appendChild( $div );
				
	return( $html );
}	













#############################################################
#############################################################
=pod

=back

=head2 Methods relating to the current XHTML page

=over 4

=cut
#############################################################
#############################################################


######################################################################
=pod

=item $session->build_page( $title, $mainbit, [$pageid], [$links], [$template_id] )

Create an XHTML page for this session. 

$title, $mainbit, $pageid and $links are XHTML DOM objects which will
be inserted into the template in the positions of the relevant 
<ep:pin> elements.

If template_id is set then an alternate template file is used.

This function only builds the page it does not output it any way, see
the methods below for that.

=cut
######################################################################

sub build_page
{
	my( $self, $title, $mainbit, $pageid, $links, $template_id ) = @_;

	unless( $self->{offline} )
	{
		my $mo = $self->param( "mainonly" );
		if( defined $mo && $mo eq "yes" )
		{
			$self->{page} = $mainbit;
			return;
		}
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
	$ph->{bodyattr}->{id} = "page_$pageid";

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

	if( !defined $template_id )
	{
		my $secure = 0;
		unless( $self->{offline} )
		{
			my $esec = $self->{request}->dir_config( "EPrints_Secure" );
			$secure = (defined $esec && $esec eq "yes" );
		}
		if( $secure ) { $template_id = 'secure'; }
	}

	my $used = {};
	$self->{page} = $self->_process_page( 
		$self->{archive}->get_template( 
			$self->get_langid, 
			$template_id ),
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

# recursive method used to insert elements into the
# <pin> parts of the template.

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

=item $session->send_page( %httpopts )

Send a web page out by HTTP. Only relevant if this is a CGI script.
build_page must have been called first.

See send_http_header for an explanation of %httpopts

Dispose of the XML once it's sent out.

=cut
######################################################################

sub send_page
{
	my( $self, %httpopts ) = @_;
	$self->send_http_header( %httpopts );
	print <<END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
END
	print EPrints::XML::to_string( $self->{page}, undef, 1 );
	EPrints::XML::dispose( $self->{page} );
	delete $self->{page};
}


######################################################################
=pod

=item $session->page_to_file( $filename )

Write out the current webpage to the given filename.

build_page must have been called first.

Dispose of the XML once it's sent out.

=cut
######################################################################

sub page_to_file
{
	my( $self , $filename ) = @_;
	
	EPrints::XML::write_xhtml_file( $self->{page}, $filename );
	EPrints::XML::dispose( $self->{page} );
	delete $self->{page};
}


######################################################################
=pod

=item $session->set_page( $newhtml )

Erase the current page for this session, if any, and replace it with
the XML DOM structure described by $newhtml.

This page is what is output by page_to_file or send_page.

$newhtml is a normal DOM Element, not a document object.

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

=item $copy_of_node = $session->clone_for_me( $node, [$deep] )

XML DOM items can only be added to the document which they belong to.

A EPrints::Session has it's own XML DOM DOcument. 

This method copies an XML node from _any_ document. The copy belongs
to this sessions document.

If $deep is set then the children, (and their children etc.), are 
copied too.

=cut
######################################################################

sub clone_for_me
{
	my( $self, $node, $deep ) = @_;

	return EPrints::XML::clone_and_own( $node, $self->{doc}, $deep );
}


######################################################################
=pod

=item $session->redirect( $url )

Redirects the browser to $url.

=cut
######################################################################

sub redirect
{
	my( $self, $url ) = @_;

	# Write HTTP headers if appropriate
	if( $self->{"offline"} )
	{
		print STDERR "ODD! redirect called in offline script.\n";
		return;
	}

	$self->{"request"}->status_line( "302 Moved" );
	EPrints::AnApache::header_out( 
		$self->{"request"},
		"Location",
		$url );
	EPrints::AnApache::send_http_header( $self->{"request"} );
}


######################################################################
=pod

=item $session->send_http_header( %opts )

Send the HTTP header. Only makes sense if this is running as a CGI 
script.

Opts supported are:

content_type. Default value is "text/html; charset=UTF-8". This sets
the http content type header.

lang. If this is set then a cookie setting the language preference
is set in the http header.

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

	EPrints::AnApache::header_out( 
		$self->{"request"},
		"Cache-Control",
		"no-store, no-cache, must-revalidate" );

	if( defined $opts{lang} )
	{
		my $cookie = $self->{query}->cookie(
			-name    => $self->{archive}->get_conf("lang_cookie_name"),
			-path    => "/",
			-value   => $opts{lang},
			-expires => "+10y", # really long time
			-domain  => $self->{archive}->get_conf("lang_cookie_domain") );
		EPrints::AnApache::header_out( 
				$self->{"request"},
				"Set-Cookie",
				$cookie );
	}

	EPrints::AnApache::send_http_header( $self->{request} );
}




#############################################################
#############################################################
=pod

=back

=head2 Input Methods

These handle input from the user, browser and apache.

=over 4

=cut
#############################################################
#############################################################




######################################################################
=pod

=item $value or @values = $session->param( $name )

Passes through to CGI.pm param method.

$value = $session->param( $name ): returns the value of CGI parameter
$name.

$value = $session->param( $name ): returns the value of CGI parameter
$name.

@values = $session->param: returns an array of the names of all the
CGI parameters in the current request.

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



######################################################################
=pod

=item $bool = $session->have_parameters

Return true if the current script had any parameters (POST or GET)

=cut
######################################################################

sub have_parameters
{
	my( $self ) = @_;
	
	my @names = $self->param();

	return( scalar @names > 0 );
}




######################################################################
=pod

=item @roles = $session->has_privilege( $privilege [, $dataobj] )

Check the current user has $privilege (optionally also check on $dataobj).

=cut
######################################################################

sub has_privilege
{
	my( $self, $priv, $dataobj ) = @_;

	return EPrints::Auth::has_privilege( $self, $priv, $self->current_user, $dataobj );
}

######################################################################
=pod

=item $boolean = $session->auth_check( [$priv] )

Return true if this session has a correcly logged in user.

If it doesn't then send an error page and return false.

If $priv is set then only return true (and not print an error) if
the current user has the privilage $priv.

=cut
######################################################################

sub auth_check
{
	my( $self , $priv ) = @_;

	my $user = $self->current_user;

	if( !defined $user )
	{
		$self->render_error( $self->html_phrase( "lib/session:no_login" ) );
		return 0;
	}

	# Don't need to do any more if we aren't checking for a specific
	# priv.
	if( !defined $priv )
	{
		return 1;
	}

	unless( $user->has_priv( $priv ) )
	{
		$self->render_error( $self->html_phrase( "lib/session:no_priv" ) );
		return 0;
	}
	return 1;
}



######################################################################
=pod

=item $user = $session->current_user

Return the current EPrints::User for this session.

Return undef if there isn't one.

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
		if( !defined $self->{request} )
		{
			# not a cgi script.
			return undef;
		}

		my $username = $self->{request}->user;

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

=item $boolean = $session->seen_form

Return true if the current request contains the values from a
form generated by EPrints.

This is identified by a hidden field placed into forms named
_seen with value "true".

=cut
######################################################################

sub seen_form
{
	my( $self ) = @_;
	
	my $result = 0;

	$result = 1 if( defined $self->param( "_seen" ) &&
	                $self->param( "_seen" ) eq "true" );

	return( $result );
}


######################################################################
=pod

=item $boolean = $session->internal_button_pressed( $buttonid )

Return true if a button has been pressed in a form which is intended
to reload the current page with some change.

Examples include the "more spaces" button on multiple fields, the 
"lookup" button on succeeds, etc.

=cut
######################################################################

sub internal_button_pressed
{
	my( $self, $buttonid ) = @_;

	if( defined $buttonid )
	{
		return 1 if( defined $self->param( "_internal_".$buttonid ) );
		return 1 if( defined $self->param( "_internal_".$buttonid.".x" ) );
		return 0;
	}
	
	if( !defined $self->{internalbuttonpressed} )
	{
		my $p;
		# $p = string
		
		$self->{internalbuttonpressed} = 0;

		foreach $p ( $self->param() )
		{
			if( $p =~ m/^_internal/ && EPrints::Utils::is_set( $self->param($p) ) )
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

=item $action_id = $session->get_action_button

Return the ID of the eprint action button which has been pressed in
a form, if there was one. The name of the button is "_action_" 
followed by the id. 

This also handles the .x and .y inserted in image submit.

This is designed to get back the name of an action button created
by render_action_buttons.

=cut
######################################################################

sub get_action_button
{
	my( $self ) = @_;

	my $p;
	# $p = string
	foreach $p ( $self->param() )
	{
		if( $p =~ s/^_action_// )
		{
			$p =~ s/\.[xy]$//;
			return $p;
		}
	}

	# undef if _default is not set.
	return $self->param("_default_action");
}



######################################################################
=pod

=item $button_id = $session->get_internal_button

Return the id of the internal button which has been pushed, or 
undef if one wasn't.

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

######################################################################
=pod

=item $client = $session->client

Return a string representing the kind of browser that made the 
current request.

Options are GECKO, LYNX, MSIE4, MSIE5, MSIE6, ?.

GECKO covers mozilla and firefox.

? is what's returned if none of the others were matched.

These divisions are intended for modifying the way pages are rendered
not logging what browser was used. Hence merging mozilla and firefox.

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

=item $status = $session->get_http_status

Return the status of the current HTTP request.

=cut
######################################################################

sub get_http_status
{
	my( $self ) = @_;

	return $self->{request}->status();
}







#############################################################
#############################################################
=pod

=back

=head2 Methods related to Plugins

=over 4

=cut
#############################################################
#############################################################


######################################################################
=pod

=item $plugin = $session->plugin( $pluginid )

Return the plugin with the given pluginid, in this archive or, failing
that, from the system level plugins.

=cut
######################################################################

sub plugin
{
	my( $self, $pluginid, %params ) = @_;

	my $class = $self->{archive}->plugin_class( $pluginid );

	if( !defined $class )
	{
		$self->{archive}->log( "Plugin '$pluginid' not found." );
		return undef;
	}

	my $plugin = $class->new( session=>$self, %params );	

	return $plugin;
}



######################################################################
=pod

=item @plugin_ids  = $session->plugin_list( %restrictions )

Return either a list of all the plugins available to this archive or
return a list of available plugins which can accept the given 
restrictions.

Restictions:
 vary depending on the type of the plugin.

=cut
######################################################################

sub plugin_list
{
	my( $self, %restrictions ) = @_;

	my %pids = ();

	foreach( $self->{archive}->plugin_list() ) { $pids{$_}=1; }

	return sort keys %pids if( !scalar %restrictions );
	my @out = ();
	foreach my $plugin_id ( sort keys %pids ) 
	{
		my $plugin = $self->plugin( $plugin_id );

		# should we add this one to the list?
		my $add = 1;	
		foreach my $k ( keys %restrictions )
		{
			my $v = $restrictions{$k};
			next if( $plugin->matches( $k, $v ) );
			$add = 0;
		}
		
		next unless $add;	

		push @out, $plugin_id;
	}

	return @out;
}




#############################################################
#############################################################
=pod

=back

=head2 Other Methods

=over 4

=cut
#############################################################
#############################################################


######################################################################
=pod

=item $spec = $session->get_citation_spec( $dataset, [$ctype] )

Return the XML spec for the given dataset. If a $ctype is specified
then return the named citation style for that dataset. eg.
a $ctype of "foo" on the eprint dataset gives a copy of the citation
spec with ID "eprint_foo".

This returns a copy of the XML citation spec., so that it may be 
safely modified.

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

=item $time = EPrints::Session::microtime();

This function is currently buggy so just returns the time in seconds.

Return the time of day in seconds, but to a precision of microseconds.

Accuracy depends on the operating system etc.

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



######################################################################
=pod

=item $foo = $session->mail_administrator( $subjectid, $messageid, %inserts )

Sends a mail to the archive administrator with the given subject and
message body.

$subjectid is the name of a phrase in the phrase file to use
for the subject.

$messageid is the name of a phrase in the phrase file to use as the
basis for the mail body.

%inserts is a hash. The keys are the pins in the messageid phrase and
the values the utf8 strings to replace the pins with.

=cut
######################################################################

sub mail_administrator
{
	my( $self,   $subjectid, $messageid, %inserts ) = @_;

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

=item $session->DESTROY

Destructor. Don't call directly.

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

