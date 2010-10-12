package EPrints::Plugin::Export::AddToShelf;

use EPrints::Plugin::Export::Tool;

@ISA = ( "EPrints::Plugin::Export::Tool" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{icon} = "tool_add_to_shelf_16.png";
	$self->{name} = "Add To Shelf...";
	$self->{accept} = [ 'list/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".html";
	$self->{mimetype} = "text/html; charset=utf-8";
	
	return $self;
}


sub output_list
{
	my( $plugin, %opts ) = @_;

	my $session = $plugin->{session};

	my $list = $opts{list};

	$list = EPrints::List->new(
		%$list,
		keep_cache => 1,
	);

	my $uri = URI->new("");
	$uri->path( $session->get_repository->get_conf( "rel_cgipath" ) . "/users/home" );
	$uri->query_form(
		screen => "AddToShelf",
		cache => $list->get_cache_id,
	);

	if( $session->get_online )
	{
		$session->redirect( $uri );
	}
	else
	{
		$uri = URI->new_abs( $uri, $session->get_repository->get_conf( "http_url" ));
		if( $opts{fh} )
		{
			print {$opts{fh}} "$uri\n";
		}
		else
		{
			return "$uri";
		}
	}

	return "";
}

1;