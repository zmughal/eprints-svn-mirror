package EPrints::Plugin::Export::BatchEdit;

use EPrints::Plugin::Export::Tool;

@ISA = ( "EPrints::Plugin::Export::Tool" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Batch Edit";
	$self->{accept} = [ 'list/eprint' ];
	$self->{visible} = "staff";
	$self->{suffix} = ".html";
	$self->{mimetype} = "text/html; charset=utf-8";
	
	return $self;
}


sub output_list
{
	my( $plugin, %opts ) = @_;

	my $handle = $plugin->{handle};

	my $list = $opts{list};

	$list = EPrints::List->new(
		%$list,
		keep_cache => 1,
	);

	my $uri = URI->new("");
	$uri->path( $handle->get_repository->get_conf( "rel_cgipath" ) . "/users/home" );
	$uri->query_form(
		screen => "BatchEdit",
		cache => $list->get_cache_id,
	);

	if( $handle->get_online )
	{
		$handle->redirect( $uri );
	}
	else
	{
		$uri = URI->new_abs( $uri, $handle->get_repository->get_conf( "http_url" ));
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
