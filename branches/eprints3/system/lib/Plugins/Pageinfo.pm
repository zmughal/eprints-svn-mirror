
package EPrints::Plugins::Pageinfo;

use EPrints::Session;

use strict;

# pageinfo format is a perl array containing 3 dom structurs
# The first dom sturct is the XML of the body of the page
# The second dom sturct is the XML of the title of the page (usually text but can
#   contain an image if there is latex etc.
# The third is optional and is included in the header, it is used for metadata etc.


EPrints::Plugins::register( 'convert/obj.eprint/pageinfo/default', \&eprint_to_pageinfo );
EPrints::Plugins::register( 'convert/obj.eprint/pageinfo/archive', \&eprint_to_pageinfo_otherstates );
EPrints::Plugins::register( 'convert/obj.eprint/pageinfo/inbox', \&eprint_to_pageinfo_otherstates );
EPrints::Plugins::register( 'convert/obj.eprint/pageinfo/buffer', \&eprint_to_pageinfo_otherstates );
EPrints::Plugins::register( 'convert/obj.eprint/pageinfo/deletion', \&eprint_to_pageinfo_deletion );
EPrints::Plugins::register( 'convert/obj.eprint/pageinfo/full', \&eprint_to_pageinfo_full );
EPrints::Plugins::register( 'convert/obj.user/pageinfo/default', \&user_to_pageinfo );
EPrints::Plugins::register( 'convert/obj.user/pageinfo/full', \&user_to_pageinfo_full );

# should be registered by archive
sub eprint_to_pageinfo_otherstates
{
	my( $eprint ) = @_;

	return &ARCHIVE->call( 
		"eprint_render", 
		$eprint,
		&SESSION );
}

sub eprint_to_pageinfo_deletion
{
	my( $eprint ) = @_;

        my( $dom, $title, $links );
	$title = &SESSION->html_phrase( 
		"lib/eprint:eprint_gone_title" );
	$dom = &SESSION->make_doc_fragment();
	$dom->appendChild( &SESSION->html_phrase( 
		"lib/eprint:eprint_gone" ) );
	my $replacement = new EPrints::EPrint(
		$eprint->get_value( "replacedby" ),
		&ARCHIVE->get_dataset( "archive" ) );
	if( defined $replacement )
	{
		my $cite = $replacement->render_citation_link();
		$dom->appendChild( 
			&SESSION->html_phrase( 
				"lib/eprint:later_version", 
				citation => $cite ) );
	}
       	return( $dom, $title, $links );
}


sub eprint_to_pageinfo
{
	my( $eprint ) = @_;

	my $ds_id = $eprint->{dataset}->id();

	return &ARCHIVE->plugin(
		'convert/obj.eprint/pageinfo/'.$ds_id,
		$eprint );
}


sub eprint_to_pageinfo_full
{
	my( $eprint ) = @_;

	return &ARCHIVE->call( 
		"eprint_render_full", 
		$eprint,
		&SESSION );
}


sub user_to_pageinfo
{
	my( $user ) = @_;

	my( $dom, $title ) = &ARCHIVE->call( 
		"user_render", 
		$user,
		&SESSION );

	if( !defined $title )
	{
		$title = $user->render_description;
	}

	return( $dom, $title );
}


sub user_to_pageinfo_full
{
	my( $user ) = @_;

	my( $dom, $title ) = &ARCHIVE->call( 
		"user_render_full", 
		$user,
		&SESSION );

	if( !defined $title )
	{
		$title = $user->render_description;
	}

	return( $dom, $title );
}

1;
