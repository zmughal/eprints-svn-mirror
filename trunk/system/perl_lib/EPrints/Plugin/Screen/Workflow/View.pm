=head1 NAME

EPrints::Plugin::Screen::Workflow::View

=cut

package EPrints::Plugin::Screen::Workflow::View;

@ISA = ( 'EPrints::Plugin::Screen::Workflow' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_view.png";

	$self->{appears} = [
		{
			place => "dataobj_actions",
			position => 200,
		},
	];

	$self->{actions} = [qw/ /];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( $self->{processor}->{dataset}->id."/view" );
}

sub wishes_to_export { shift->{repository}->param( "ajax" ) }

sub export_mime_type { "text/html;charset=utf-8" }

sub export
{
	my( $self ) = @_;

	my $dataset = $self->{processor}->{dataset};

	my $id_prefix = "ep_workflow_views";

	my $current = $self->{session}->param( "${id_prefix}_current" );
	$current = 0 if !defined $current;

	my @items = (
		$self->list_items( "dataobj_view_tabs", filter => 0 ),
		$self->list_items( "dataobj_".$dataset->id."_view_tabs", filter => 0 ),
	);

	my @screens;
	foreach my $item ( @items )
	{
		next if !($item->{screen}->can_be_viewed & $self->who_filter);
		next if $item->{action} && !$item->{screen}->allow_action( $item->{action} );
		push @screens, $item->{screen};
	}

	my $content = $screens[$current]->render;
	binmode(STDOUT, ":utf8");
	print $self->{repository}->xhtml->to_xhtml( $content );
	$self->{repository}->xml->dispose( $content );
}

sub render_title
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $screen = $self->view_screen();

	my $dataset = $self->{processor}->{dataset};
	my $dataobj = $self->{processor}->{dataobj};

	my $listing;
	my $priv = $dataset->id . "/view";
	if( $self->EPrints::Plugin::Screen::allow( $priv ) )
	{
		my $url = URI->new( $session->current_url );
		$url->query_form(
			screen => $self->listing_screen,
			dataset => $dataset->id
		);
		$listing = $session->render_link( $url );
		$listing->appendChild( $dataset->render_name( $session ) );
	}
	else
	{
		$listing = $dataset->render_name( $session );
	}

	my $desc = $dataobj->render_description();

	return $self->html_phrase( "page_title",
		listing => $listing,
		desc => $desc,
	);
}

sub render
{
	my( $self ) = @_;

	my $dataset = $self->{processor}->{dataset};

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->render_status );

	$chunk->appendChild( $self->render_common_action_links );

	my $buttons = $self->render_common_action_buttons;
	$chunk->appendChild( $buttons );

	# if in archive and can request delete then do that here TODO

	# current view to show
	my $view = $self->{session}->param( "view" );
	if( defined $view )
	{
		$view = "Screen::$view";
	}

	my $id_prefix = "ep_workflow_views";

	my $current = $self->{session}->param( "${id_prefix}_current" );
	$current = 0 if !defined $current;

	my @items = (
		$self->list_items( "dataobj_view_tabs", filter => 0 ),
		$self->list_items( "dataobj_".$dataset->id."_view_tabs", filter => 0 ),
		);

	my @screens;
	foreach my $item (@items)
	{
		next if !($item->{screen}->can_be_viewed & $self->who_filter);
		next if $item->{action} && !$item->{screen}->allow_action( $item->{action} );
		push @screens, $item->{screen};
	}

	if( !@screens )
	{
		return $chunk;
	}

	my @labels;
	my @contents;
	my @expensive;

	for(my $i = 0; $i < @screens; ++$i)
	{
		my $screen = $screens[$i];
		push @labels, $screen->render_tab_title;
		push @expensive, $i if $screen->{expensive};
		if( $screen->{expensive} && $i != $current )
		{
			push @contents, $self->{session}->html_phrase(
				"cgi/users/edit_eprint:loading"
			);
		}
		else
		{
			push @contents, $screen->render;
		}
	}

	$chunk->appendChild( $self->{session}->xhtml->tabs(
		\@labels,
		\@contents,
		basename => $id_prefix,
		current => $current,
		expensive => \@expensive,
		) );

#	$chunk->appendChild( $buttons->cloneNode(1) );
	return $chunk;
}

sub render_status
{
	my( $self ) = @_;

	my $dataobj = $self->{processor}->{dataobj};

	my $url = $dataobj->uri;

	my $div = $self->{session}->make_element( "div", class=>"ep_block" );

	my $link = $self->{session}->render_link( $url );
	$div->appendChild( $link );
	$link->appendChild( $self->{session}->make_text( $url ) );

	return $div;
}

sub render_common_action_links
{
	my( $self ) = @_;

	my $datasetid = $self->{processor}->{dataset}->id;

	return $self->{processor}->render_item_list(
			[
				$self->{processor}->list_items( "${datasetid}_view_action_links" ),
				$self->{processor}->list_items( "dataobj_view_action_links" ),
			],
			class => "ep_user_tasks",
		);
}

sub render_common_action_buttons
{
	my( $self ) = @_;

	my $datasetid = $self->{processor}->{dataset}->id;

	return $self->render_action_list_bar( ["${datasetid}_view_actions", "dataobj_view_actions"], {
					dataset => $datasetid,
					dataobj => $self->{processor}->{dataobj}->id,
				} );
}

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

