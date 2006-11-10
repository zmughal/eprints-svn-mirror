
package EPrints::Plugin::Screen::Review;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "key_tools",
			position => 400,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "editorial_review" );
}

sub render_links
{
	my( $self ) = @_;

	my $style = $self->{session}->make_element( "style", type=>"text/css" );
	$style->appendChild( $self->{session}->make_text( ".ep_tm_main { width: 90%; }" ) );

	return $style;
}


sub render
{
	my( $self ) = @_;

	my $user = $self->{session}->current_user;
	my $page = $self->{session}->make_doc_fragment();

	# Get EPrints in the submission buffer
	my $list = $user->get_editable_eprints();

	if( $list->count == 0 )
	{
		# Empty list
		return $self->{session}->html_phrase( "cgi/users/buffer:no_entries", scope=>$self->_get_scope( $user ) );
	}

	$page->appendChild( $self->{session}->html_phrase( 
		"cgi/users/buffer:buffer_blurb",
		scope=>$self->_get_scope( $user ) ) );

	# Paginate list
	my %opts = (
		params => {
			screen => "Review",
		},
		columns => $self->{session}->current_user->get_value( "review_fields" ),
		render_result_params => {
			row => 1,
		},
		render_result => sub {
			my( $session, $e, $info ) = @_;

			my $tr = $session->make_element( "tr", class=>"row_".($info->{row}%2?"b":"a") );

			my $cols = $session->current_user->get_value( "review_fields" );
			my $first = 1;
			for( @$cols )
			{
				my $td = $session->make_element( "td", class=>"ep_columns_cell".($first?" ep_columns_cell_first":"") );
				$first = 0;
				$tr->appendChild( $td );
				my $a = $session->render_link( "?eprintid=".$e->get_id."&screen=EPrint::View::Editor" );
				$td->appendChild( $a );
				$a->appendChild( $e->render_value( $_ ) );
			}

			++$info->{row};

			return $tr;
		},
	);
#	my $h2 = $self->{session}->make_element( "h2",class=>"ep_search_desc" );
#	$h2->appendChild( $self->html_phrase( "list_desc" ) );
#	$page->appendChild( $h2 );
	$page->appendChild( EPrints::Paginate::Columns->paginate_list( $self->{session}, "_review", $list, %opts ) );

	return $page;
}

sub _get_scope
{
	my( $self, $user ) = @_;
	if( $user->is_set( "editperms" ) )
	{
		return $user->render_value( "editperms" );
	}
	else
	{
		return $self->{session}->html_phrase( "lib/metafield:unspecified_editperms" );
	}
}

# ignore the form. We're screwed at this point, and are just reporting.
sub from
{
	my( $self ) = @_;

	return;
}




1;
