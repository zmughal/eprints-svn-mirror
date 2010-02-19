######################################################################
#
# EPrints::Paginate::Columns
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

B<EPrints::Paginate::Columns> - Methods for rendering a paginated List as sortable columns

=head1 DESCRIPTION

=over 4

=cut

######################################################################
package EPrints::Paginate::UnsortedColumns;

@ISA = ( 'EPrints::Paginate' );

use URI::Escape;
use strict;

sub paginate_list
{
	my( $class, $session, $basename, $list, %opts ) = @_;

	my %newopts = %opts;
	
	# Build base URL
	my $url = $session->get_uri . "?";
	my @param_list;
	if( defined $opts{params} )
	{
		my $params = $opts{params};
		foreach my $key ( keys %$params )
		{
			my $value = $params->{$key};
			push @param_list, "$key=$value";
		}
	}
	$url .= join "&", @param_list;

	my $offset = $session->param( "$basename\_offset" ) + 0;
	$url .= "&$basename\_offset=$offset"; # $basename\_offset used by paginate_list

	# URL for images
	my $imagesurl = $session->get_repository->get_conf( "rel_path" )."/style/images";

	# Container for list
	my $table = $session->make_element( "table", border=>0, cellpadding=>4, cellspacing=>0, class=>"ep_columns" );
	my $tr = $session->make_element( "tr", class=>"header_plain" );
	$table->appendChild( $tr );

	my $len = scalar(@{$opts{columns}});

	for(my $i; $i<$len;++$i )
	{
		my $col = $opts{columns}->[$i];
		my $last = ($i == $len-1);
		# Column headings
		my $th = $session->make_element( "th", class=>"ep_columns_title".($last?" ep_columns_title_last":"") );
		$tr->appendChild( $th );
		next if !defined $col;
	
		my $itable = $session->make_element( "table", cellpadding=>0, border=>0, cellspacing=>0, width=>"100%" );
		my $itr = $session->make_element( "tr" );
		$itable->appendChild( $itr );
		my $itd1 = $session->make_element( "td" );
		$itr->appendChild( $itd1 );
		my $itd2 = $session->make_element( "td", style=>"padding-left: 1em; text-align: right" );
		$itr->appendChild( $itd2 );
		$itd1->appendChild( $list->get_dataset->get_field( $col )->render_name( $session ) );
		$th->appendChild( $itable );
	}
	
	my $info = {
		row => 1,
		columns => $opts{columns},
	};
	$newopts{container} = $table unless defined $newopts{container};
	$newopts{render_result_params} = $info unless defined $newopts{render_result_params};
	$newopts{render_result} = sub {
		my( $session, $e, $info ) = @_;

		my $tr = $session->make_element( "tr" );
		my $first = 1;
		foreach my $column ( @{ $info->{columns} } )
		{
			my $td = $session->make_element( "td", class=>"ep_columns_cell".($first?" ep_columns_cell_first":"") );
			$first = 0;
			$tr->appendChild( $td );
			$td->appendChild( $e->render_value( $column ) );
		}
		return $tr;
	} unless defined $newopts{render_result};

	$newopts{render_no_results} = sub {
		my( $session, $info, $phrase ) = @_;
		my $tr = $session->make_element( "tr" );
		my $td = $session->make_element( "td", class=>"ep_columns_no_items", colspan => scalar @{ $opts{columns} } );
		$td->appendChild( $phrase ); 
		$tr->appendChild( $td );
		return $tr;
	} unless defined $newopts{render_no_results};
	
	return EPrints::Paginate->paginate_list( $session, $basename, $list, %newopts );
}

1;

######################################################################
=pod

=back

=cut

