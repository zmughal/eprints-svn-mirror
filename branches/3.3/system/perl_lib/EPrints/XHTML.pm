######################################################################
#
# EPrints::XHTML
#
######################################################################
#
#
######################################################################


=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::XHTML> - XHTML Module

=head1 SYNOPSIS

	$xhtml = $repo->xhtml;

	$utf8_string = $xhtml->to_xhtml( $dom_node, %opts );

	$xhtml_dom_node = $xhtml->input_field( $name, $value, type => "text" );
	$xhtml_dom_node = $xhtml->hidden_field( $name, $value );
	$xhtml_dom_node = $xhtml->text_area_field( $name, $value, rows => 4 );
	$xhtml_dom_node = $xhtml->form( "get", $url );

	$xhtml_dom_node = $xhtml->data_element( $name, $value, indent => 4 );

	$page = $xhtml->page( %opts );

=head2 tree()

	$xhtml->tree([ # dl
		[ "fruit", # dt
			[ "apple", "orange", ], # ul {li, li}
		],
		[ "vegetable", # dt
			[ "potato", "carrot", ], # ul {li, li}
		],
		[ "animal", # dt
			[ "cat", # dt
				[ "lion", "leopard", ], # ul {li, li}
			],
		],
		"soup", # ul {li}
		$xml->create_element( "p" ), # <p> is appended
	]);
	
	<dl>
		<dt>fruit</dt>
		<dd>
			<ul>
				<li>apple</li>
				<li>orange</li>
			</ul>
		</dd>
		<dt>vegetable</dt>
		<dd>
			<ul>
				<li>potato</li>
				<li>carrot</li>
			</ul>
		</dd>
		<dt>animal</dt>
		<dd>
			<dl>
				<dt>cat</dt>
				<dd>
					<ul>
						<li>lion</li>
						<li>leopard</li>
					</ul>
				</dd>
			</dl>
		</dd>
	</dl>
	<ul>
		<li>soup</li>
	</ul>
	<p />

=head1 DESCRIPTION

The XHTML object facilitates the creation of XHTML objects.

=head1 METHODS

=over 4

=cut

package EPrints::XHTML;

use EPrints::Const qw( :xml ); # XML node type constants
use strict;

@EPrints::XHTML::COMPRESS_TAGS = qw/br hr img link input meta/;
%EPrints::XHTML::COMPRESS_TAG = map { $_ => 1 } @EPrints::XHTML::COMPRESS_TAGS;

# $xhtml = new EPrints::XHTML( $repository )
#
# Contructor, should be called by Repository only.

sub new($$)
{
	my( $class, $repository ) = @_;

	my $self = bless { repository => $repository }, $class;

	Scalar::Util::weaken( $self->{repository} )
		if defined &Scalar::Util::weaken;

	return $self;
}

=item $node = $xhtml->form( $method [, $action] )

Returns an XHTML form. If $action isn't defined uses the current URL.

=cut

sub form
{
	my( $self, $method, $action ) = @_;
	
	$method = lc($method);
	if( !defined $action )
	{
		$action = $self->{repository}->current_url( query => 0 );
	}

	my $form = $self->{repository}->xml->create_element( "form",
		method => $method,
		'accept-charset' => "utf-8",
		action => $action,
		);
	if( $method eq "post" )
	{
		$form->setAttribute( enctype => "multipart/form-data" );
	}

	return $form;
}

=item $node = $xhtml->input_field( $name, $value, %opts )

	$node = $xhtml->input_field( "name", "Bob", type => "text" );

Returns an XHTML input field with name $name and value $value. Specify "noenter" to prevent the form being submitted when the user presses the enter key.

=cut

sub input_field
{
	my( $self, $name, $value, @opts ) = @_;

	my $noenter;
	for(my $i = 0; $i < @opts; $i+=2)
	{
		if( $opts[$i] eq 'noenter' )
		{
			(undef, $noenter) = splice(@opts,$i,2);
			last;
		}
	}
	if( $noenter )
	{
		push @opts, onKeyPress => 'return EPJS_block_enter( event )';
	}

	return $self->{repository}->xml->create_element( "input",
		name => $name,
		id => $name,
		value => $value,
		@opts );
}

=item $node = $xhtml->hidden_field( $name, $value, %opts );

Returns an XHTML hidden input field.

=cut

sub hidden_field
{
	my( $self, $name, $value, @opts ) = @_;

	return $self->{repository}->xml->create_element( "input",
		name => $name,
		id => $name,
		value => $value,
		type => "hidden",
		@opts );
}

=item $node = $xhtml->action_button( $name, $value, %opts )

Creates a submit button that is styled to an EPrints form button.

$value is the text shown on the button.

=cut

sub action_button
{
	my( $self, $name, $value, %opts ) = @_;

	$opts{class} = join ' ', 'ep_form_action_button', ($opts{class}||());

	return $self->{repository}->xml->create_element( "input",
		name => "_action_$name",
		value => $value,
		type => "submit",
		%opts,
	);
}

=item $node = $xhtml->text_area_field( $name, $value, %opts )

Returns an XHTML textarea input.

=cut

sub text_area_field
{
	my( $self, $name, $value, @opts ) = @_;

	my $node = $self->{repository}->xml->create_element( "textarea",
		name => $name,
		id => $name,
		@opts );
	$node->appendChild( $self->{repository}->xml->create_text_node( $value ) );

	return $node;
}

=item $node = $xhtml->data_element( $name, $value, %opts )

Create a new element named $name containing a text node containing $value.

Options:
	indent - amount of whitespace to indent by

=cut

sub data_element
{
	my( $self, $name, $value, @opts ) = @_;

	my $indent;
	for(my $i = 0; $i < @opts; $i+=2)
	{
		if( $opts[$i] eq 'indent' )
		{
			(undef, $indent ) = splice(@opts,$i,2);
			last;
		}
	}

	my $node = $self->{repository}->xml->create_element( $name, @opts );
	$node->appendChild( $self->{repository}->xml->create_text_node( $value ) );

	if( defined $indent )
	{
		my $f = $self->{repository}->xml->create_document_fragment;
		$f->appendChild( $self->{repository}->xml->create_text_node(
			"\n"." "x$indent
			) );
		$f->appendChild( $node );
		return $f;
	}

	return $node;
}

=item $utf8_string = $xhtml->to_xhtml( $node, %opts )

Returns $node as valid XHTML.

=cut

sub to_xhtml
{
	my( $self, $node, %opts ) = @_;

	&_to_xhtml( $node );
}

my %HTML_ENTITIES = (
	'&' => '&amp;',
	'>' => '&gt;',
	'<' => '&lt;',
	'"' => '&quot;',
);

# may take options in the future
sub _to_xhtml
{
	my( $node ) = @_;

	# a single call to "nodeType" is quicker than lots of calls to is()?
	my $type = $node->nodeType;

	my @n = ();
	if( $type == XML_ELEMENT_NODE )
	{
		my $tagname = $node->localName; # ignore prefixes

		$tagname = lc($tagname);

		push @n, '<', $tagname;
		my $seen = {};

		if( $tagname eq "html" )
		{
			push @n, ' xmlns="http://www.w3.org/1999/xhtml"';
		}

		foreach my $attr ( $node->attributes )
		{
			my $name = $attr->nodeName;
			# strip all namespace definitions and prefixes
			next if $name =~ /^xmlns/;
			$name =~ s/^.+://;

			next if( exists $seen->{$name} );
			$seen->{$name} = 1;

			my $value = $attr->nodeValue;
			$value =~ s/([&<>"])/$HTML_ENTITIES{$1}/g;
			utf8::decode($value) unless utf8::is_utf8($value);
			push @n, ' ', $name, '="', $value, '"';
		}

		if( $node->hasChildNodes )
		{
			push @n, '>';
			foreach my $kid ( $node->childNodes )
			{
				push @n, &_to_xhtml( $kid );
			}
			push @n, '</', $tagname, '>';
		}
		elsif( $EPrints::XHTML::COMPRESS_TAG{$tagname} )
		{
			push @n, ' />';
		}
		elsif( $tagname eq "script" )
		{
			push @n, '>// <!-- No script --></', $tagname, '>';
		}
		else
		{
			push @n, '></', $tagname, '>';
		}
	}
	elsif( $type == XML_DOCUMENT_FRAGMENT_NODE )
	{
		foreach my $kid ( $node->getChildNodes )
		{
			push @n, &_to_xhtml( $kid );
		}
	}
	elsif( $type == XML_DOCUMENT_NODE )
	{
		push @n, &_to_xhtml( $node->documentElement );
	}
	else
	{
		push @n, $node->toString; 
		utf8::decode($n[$#n]) unless utf8::is_utf8($n[$#n]);
	}

	return wantarray ? @n : join('', @n);
}

=item $string = $xhtml->to_text_dump( $tree, %opts )

Dumps the XHTML contents of $tree as a utf8 string, stripping tags and converting common HTML layout elements into their plain-text equivalent.

Options:

	width - word-wrap after the given number of columns
	show_links - see below
	preformatted - equivalent to wrapping $tree in <pre></pre>

XHTML elements are removed with the following exceptions:

<br /> is replaced by a newline.

<p>...</p> will have a blank line above and below.

<img /> is replaced with the content of the I<alt> attribute.

<hr /> will insert a line of dashes if B<width> is set.

<a href="foo">bar</a> will be replaced by "bar <foo>" if B<show_links> is set.

=cut

######################################################################

sub to_text_dump
{
	my( $self, $node, %opts ) = @_;

	my $width = exists $opts{width} ? $opts{width} : undef;
	my $show_links = exists $opts{show_links} ? $opts{show_links} : 0;
	my $pre = exists $opts{preformatted} ? $opts{preformatted} : 0;

	my $str = "";
	$self->_to_text_dump( \$str, $node, $width, $pre, $show_links );
	utf8::decode($str) unless utf8::is_utf8($str);

	return $str;
}

sub _to_text_dump
{
	my( $self, $str, $node, $width, $pre, $show_links ) = @_;

	if( $self->{repository}->{xml}->is( $node, 'Text', 'CDataSection' ) )
	{
		my $v = $node->nodeValue();
		$v =~ s/[\s\r\n\t]+/ /g unless( $pre );
		$$str .= $v;
		return;
	}
	elsif( $self->{repository}->{xml}->is( $node, 'NodeList' ) )
	{
# Hmm, a node list, not a node.
		for( my $i=0 ; $i<$node->length ; ++$i )
		{
			$self->_to_text_dump(
					$str,
					$node->item( $i ), 
					$width,
					$pre,
					$show_links );
		}
		return;
	}

	my $name = $node->localName();
	# documentFragment has no localName
	$name = defined $name ? lc($name) : "";

	# empty tags
	if( $name eq 'hr' )
	{
		# <hr /> only makes sense if we are generating a known width.
		$$str .= "\n"."-"x$width."\n" if $width;
		return;
	}
	elsif( $name eq 'br' )
	{
		$$str .= "\n";
		return;
	}

	my $contents = "";
	for( $node->childNodes )
	{
		$self->_to_text_dump( 
				\$contents,
				$_,
				$width, 
				( $pre || $name eq "pre" || $name eq "mail" ),
				$show_links );
	}

	# Handle wrapping block elements if a width was set.
	if( $width && ( $name eq "p" || $name eq "mail" ) )
	{
		$contents = EPrints::Utils::wrap_text( $contents, $width );
	}

	if( $name eq "fallback" )
	{
		$contents = "*".$contents."*";
	}
	elsif( $name eq "p" )
	{
		$contents =~ s/^(?:\n\n)?/\n\n/ if $$str !~ /\n\n$/;
		$contents =~ s/(?:\n)?$/\n/;
	}
	elsif( $name eq "img" )
	{
		$contents = $node->getAttribute( "alt" );
		$contents = "" if !defined $contents;
	}
	elsif( $name eq "a" )
	{
		if( $show_links )
		{
			my $href = $node->getAttribute( "href" );
			$contents .= " <$href>" if( defined $href );
		}
	}

	$$str .= $contents;

	return;
}

=item $page = $xhtml->page( $map, %opts )

Returns an EPrints::Page object describing an XHTML page filled out with the templates provided in $map.

$map is a hash of XHTML DOM fragments. At least "title" and "page" should be defined. Use "links" to add items to the header.

Option "page_id" set's the XML id of the <body> to be "page_YOURID". Useful when you want to use CSS to tweak elements on one page only.

Option "template" uses a different template to "default.xml".

=cut


sub page
{
	my( $self, $map, %options ) = @_;

	# This first bit is a really heinous hack, back it provides two really useful
	# functions, the contextual phrase editor and the "mainonly" feature making pages
	# easy to embed.
	
	unless( $self->{repository}->{offline} || !defined $self->{repository}->{query} )
	{
		my $mo = $self->{repository}->param( "mainonly" );
		if( defined $mo && $mo eq "yes" )
		{
			return EPrints::Page::DOM->new( $self->{repository}, $map->{page}, add_doctype=>0 );
		}

		my $dp = $self->{repository}->param( "edit_phrases" );
		# phrase debugging code.

		if( defined $dp && $dp eq "yes" )
		{
			my $current_user = $self->{repository}->current_user;	
			if( defined $current_user && $current_user->allow( "config/edit/phrase" ) )
			{
				my $phrase_screen = $self->{repository}->plugin( "Screen::Admin::Phrases",
		  			phrase_ids => [ sort keys %{$self->{repository}->{used_phrases}} ] );
				$map->{page} = $self->{repository}->xml->create_document_fragment;
				my $url = $self->{repository}->get_full_url;
				my( $a, $b ) = split( /\?/, $url );
				my @parts = ();
				foreach my $part ( split( "&", $b ) )	
				{
					next if( $part =~ m/^edit(_|\%5F)phrases=yes$/ );
					push @parts, $part;
				}
				$url = $a."?".join( "&", @parts );
				my $div = $self->{repository}->xml->create_element( "div", style=>"margin-bottom: 1em" );
				$map->{page}->appendChild( $div );
				$div->appendChild( $self->{repository}->html_phrase( "lib/session:phrase_edit_back",
					link => $self->{repository}->render_link( $url ),
					page_title => $self->{repository}->clone_for_me( $map->{title},1 ) ) );
				$map->{page}->appendChild( $phrase_screen->render );
				$map->{title} = $self->{repository}->html_phrase( "lib/session:phrase_edit_title",
					page_title => $map->{title} );
			}
		}
	}

	# provide CSS/JS settings to show/hide content based on login status
	if( defined $self->{repository}->current_user )
	{
		$map->{login_status_header} = $self->{repository}->html_phrase( "dynamic:logged_in_header" );
	}
	else
	{
		$map->{login_status_header} = $self->{repository}->html_phrase( "dynamic:not_logged_in_header" );
	}

	# languages pin
	my $plugin = $self->{repository}->plugin( "Screen::SetLang" );
	if( defined $plugin )
	{
		$map->{languages} = $plugin->render_action_link;
	}
	
	if( $self->{repository}->config( "dynamic_template","enable" ) )
	{
		if( $self->{repository}->can_call( "dynamic_template", "function" ) )
		{
			$self->{repository}->call( [ "dynamic_template", "function" ],
				$self->{repository},
				$map );
		}
	}

	# we've been called by an older script
	if( !defined $map->{login_status} )
	{
		$map->{login_status} = EPrints::ScreenProcessor->new(
			session => $self->{repository},
		)->render_toolbar;
	}

	my $pagehooks = $self->{repository}->config( "pagehooks" );
	$pagehooks = {} if !defined $pagehooks;
	my $ph = $pagehooks->{$options{page_id}} if defined $options{page_id};
	$ph = {} if !defined $ph;
	if( defined $options{page_id} )
	{
		$ph->{bodyattr}->{id} = "page_".$options{page_id};
	}

	# only really useful for head & pagetop, but it might as
	# well support the others

	foreach( keys %{$map} )
	{
		next if( !defined $ph->{$_} );

		my $pt = $self->{repository}->xml->create_document_fragment;
		$pt->appendChild( $map->{$_} );
		my $ptnew = $self->{repository}->clone_for_me(
			$ph->{$_},
			1 );
		$pt->appendChild( $ptnew );
		$map->{$_} = $pt;
	}

	if( !defined $options{template} )
	{
		if( $self->{repository}->get_secure )
		{
			$options{template} = "secure";
		}
		else
		{
			$options{template} = "default";
		}
	}

	my $parts = $self->{repository}->get_template_parts( 
				$self->{repository}->get_langid, 
				$options{template} );
	my @output = ();
	my $is_html = 0;

	foreach my $bit ( @{$parts} )
	{
		$is_html = !$is_html;

		if( $is_html )
		{
			push @output, $bit;
			next;
		}

		# either 
		#  print:epscript-expr
		#  pin:id-of-a-pin
		#  pin:id-of-a-pin.textonly
		#  phrase:id-of-a-phrase
		my( $type, $rest ) = split /:/, $bit, 2;

		if( $type eq "print" )
		{
			my $result = EPrints::XML::to_string( EPrints::Script::print( $rest, { session=>$self->{repository} } ), undef, 1 );
			push @output, $result;
			next;
		}

		if( $type eq "phrase" )
		{	
			push @output, EPrints::XML::to_string( $self->{repository}->html_phrase( $rest ), undef, 1 );
			next;
		}

		if( $type eq "pin" )
		{	
			my( $pinid, $modifier ) = split /:/, $rest, 2;
			if( defined $modifier && $modifier eq "textonly" )
			{
				my $text;
				if( defined $map->{"utf-8.".$pinid.".textonly"} )
				{
					$text = $map->{"utf-8.".$pinid.".textonly"};
				}
				elsif( defined $map->{$pinid} )
				{
					# don't convert href's to <http://...>'s
					$text = EPrints::Utils::tree_to_utf8( $map->{$pinid}, undef, undef, undef, 1 ); 
				}

				# else no title
				next unless defined $text;

				# escape any entities in the text (<>&" etc.)
				my $xml = $self->{repository}->xml->create_text_node( $text );
				push @output, EPrints::XML::to_string( $xml, undef, 1 );
				EPrints::XML::dispose( $xml );
				next;
			}
	
			if( defined $map->{"utf-8.".$pinid} )
			{
				push @output, $map->{"utf-8.".$pinid};
			}
			elsif( defined $map->{$pinid} )
			{
#EPrints::XML::tidy( $map->{$pinid} );
				push @output, EPrints::XML::to_string( $map->{$pinid}, undef, 1 );
			}
		}

		# otherwise this element is missing. Leave it blank.
	
	}

	return EPrints::Page::Text->new( $self->{repository}, join( "", @output ) );
}

=item $node = $xhtml->tabs( $labels, $contents, %opts )

Render a tabbed box where:

 labels - an array of label XHTML fragments
 contents - an array of content XHTML fragments

Options:

 base_url - the link to follow under non-JS (default = current URL)
 basename - prefix for tab identifiers (default = "ep_tabs")
 current - index of tab to show first (default = 0)
 expensive - array of tabs to not javascript-link
 aliases - map tab index to alias name

=cut

sub tabs
{
	my( $self, $labels, $contents, %opts ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
	my $online = $repo->get_online;

	my $frag = $xml->create_document_fragment;

	my $base_url = exists($opts{base_url}) || !$online ? $opts{base_url} : $repo->current_url( query => 1 );
	my $basename = exists($opts{basename}) ? $opts{basename} : "ep_tabs";

	# compatibility with Session::render_tabs()
	my $aliases = $opts{aliases};
	my $links = $opts{links};

	# our special parameter
	my $q_current = $basename."_current";

	if( defined $base_url )
	{
		$base_url = URI->new( $base_url );
		# strip our parameter from the base URL
		my @q = $base_url->query_form;
		for(reverse 0..$#q)
		{
			next if $_ % 2;
			splice(@q, $_, 2) if $q[$_] eq $q_current;
		}
		$base_url->query_form( @q );
	}

	# render the current page according to the request (javascript might alter
	# the actual page shown)
	my $current = $opts{current};
	if( $online && defined($repo->param( $q_current )) )
	{
		$current = $repo->param( $q_current );
	}
	$current = 0 if !$current;
	if( defined $aliases )
	{
		my %raliases = reverse %$aliases;
		$current = exists $raliases{$current} ? $raliases{$current} : 0;
	}

	my $ul = $xml->create_element( "ul",
		id=>$basename."_tabs",
		class => "ep_tab_bar",
	);
	$frag->appendChild( $ul );

	my $panel;
	if( @$contents )
	{
		$panel = $xml->create_element( "div", 
				id => $basename."_panels",
				class => "ep_tab_panel" );
		$frag->appendChild( $panel );
	}

	my %expensive = map { $_ => 1 } @{$opts{expensive}||[]};

	for(0..$#$labels)
	{
		my $label = defined($aliases) ? $aliases->{$_} : $_;
		my $width = int( 100 / @$labels );
		$width += 100 % @$labels if $_ == 0;
		my $tab = $ul->appendChild( $xml->create_element( "li",
			($current == $_ ? (class => "ep_tab_selected") : ()),
			id => $basename."_tab_".$label,
			style => "width: $width\%",
		) );

		my $href;
		if( $online )
		{
			$href = $base_url->clone();
			$href->query_form(
				$href->query_form,
				$q_current => $label,
			);
		}
		if( defined $links && defined $links->{$label} )
		{
			$href = $links->{$label};
		}
#		$href->fragment( "ep_tabs:".$basename.":".$_ );

		my $link = $tab->appendChild( $xml->create_data_element( "a",
			$labels->[$_],
			href => $href,
			onclick => "return ep_showTab('$basename','$label',".($expensive{$_}?1:0).");",
		) );

		if( defined $panel )
		{
			my $inner_panel = $xml->create_element( "div", 
				id => $basename."_panel_".$label,
			);
			if( $_ != $current )
			{
				# padding for non-javascript enabled browsers
				$panel->appendChild( $xml->create_element( "div",
					class=>"ep_no_js",
					style => "height: 1em",
				) );
				$inner_panel->setAttribute( class => "ep_no_js" );
			}
			$panel->appendChild( $inner_panel );
			$inner_panel->appendChild( $contents->[$_] );
		}
	}

	return $frag;
}

=item $node = $xhtml->tree( $root, OPTIONS )
 
Render a tree using definition lists (DLs).

Options:

	prefix - id to use for the parent <div> and class prefix
	render_value - custom renderer for values

=cut

sub tree
{
	my( $self, $root, %opts ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;

	my $frag = $xml->create_document_fragment;

	$frag->appendChild( $xml->create_data_element( "div",
		$self->tree2( $root,
			class => $opts{prefix},
			%opts,
		),
		id => $opts{prefix},
		class => $opts{prefix},
	) );
	$frag->appendChild( $repo->make_javascript(<<"EOJ") );
Event.observe( window, 'load', function() {
	ep_js_init_dl_tree('$opts{prefix}', '$opts{prefix}_open');
});
EOJ

	return $frag;
}

sub tree2
{
	my( $self, $root, %opts ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;

	my $frag = $xml->create_document_fragment;
	return $frag if !defined $root || !scalar(@$root);

	$opts{render_value} ||= sub { $xml->create_text_node( $_[0] ) };

	my $dl = $frag->appendChild( $xml->create_element( "dl" ) );
	
	foreach my $node (@$root)
	{
		if( ref($node) eq "ARRAY" )
		{
			my( $key, $children, %nopts ) = @$node;

			$dl->appendChild( $xml->create_data_element( "dt",
				$opts{render_value}( @$node ),
				class => ($nopts{show} ? "$opts{class} $opts{class}_open" : $opts{class}),
			) );
			$dl->appendChild( $xml->create_data_element( "dd",
				$self->tree2( $children, %opts ),
				class => ($nopts{show} ? "" : "ep_no_js"),
			) );
		}
		else
		{
			$dl->appendChild( $xml->create_data_element( "dt",
				$opts{render_value}( $node ),
			) );
			$dl->appendChild( $xml->create_element( "dd",
				class => "ep_no_js",
			) );
		}
	}

	return $dl;
}

######################################################################
=pod

=back

=cut
######################################################################

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

