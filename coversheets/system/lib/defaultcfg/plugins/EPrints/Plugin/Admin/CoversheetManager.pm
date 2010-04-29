
package EPrints::Plugin::Screen::Admin::CoversheetManager;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "admin_actions",
			position => 1,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "coversheet/view" );
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $page = $self->{session}->make_doc_fragment();


	my $searchexp = EPrints::Search->new(
			allow_blank => 1,
			dataset => $session->get_repository->get_dataset('coversheet'),
			session => $session );
	my $list = $searchexp->perform_search;


	my $imagesurl = $session->get_repository->get_conf( "rel_path" )."/style/images";

	my %options;
 	$options{session} = $session;
	$options{id} = "ep_coversheet_manager_instructions";
	$options{title} = $session->html_phrase( "Plugin/Screen/Admin/CoversheetManager:help_title" );
	$options{content} = $session->html_phrase( "Plugin/Screen/Admin/CoversheetManager:help" );
	$options{collapsed} = 1;
	$options{show_icon_url} = "$imagesurl/help.gif";
	my $box = $session->make_element( "div", style=>"text-align: left" );
	$box->appendChild( EPrints::Box::render( %options ) );
	$page->appendChild( $box );

	my $columns = [ "coversheetid","status","name","frontfile","backfile" ];

	my $len = scalar @{$columns};

	my $final_row = undef;

	# Paginate list
	my %opts = (
		params => {
			screen => "Admin::CoversheetManager",
		},
		columns => [@{$columns}, undef ],
		render_result_params => {
			row => 1,
		},
		render_result => sub {
			my( $session, $dataobj, $info ) = @_;

			my $tr = $session->make_element( "tr", class=>"row_".($info->{row}%2?"b":"a") );

 			my $cols = $columns,

			my $first = 1;
			for( @$cols )
			{
				my $td = $session->make_element( "td", class=>"ep_columns_cell".($first?" ep_columns_cell_first":"")." ep_columns_cell_$_"  );
				$first = 0;
				$tr->appendChild( $td );
				$td->appendChild( $dataobj->render_value( $_ ) );
			}

			$self->{processor}->{coversheet} = $dataobj;
			$self->{processor}->{coversheetid} = $dataobj->get_id;
			my $td = $session->make_element( "td", class=>"ep_columns_cell ep_columns_cell_last", align=>"left" );
			$tr->appendChild( $td );
			$td->appendChild( 
				$self->render_action_list_icons( "coversheet_manager_actions", ['coversheetid'] ) );
			delete $self->{processor}->{coversheet};


			++$info->{row};

			return $tr;
		},
	);
	$page->appendChild( EPrints::Paginate::Columns->paginate_list( $self->{session}, "_coversheetmanager", $list, %opts ) );

	$page->appendChild( $self->render_action_list_bar( "coversheet_tools" ) );

	return $page;
}



1;
