=head1 NAME

EPrints::Plugin::Screen::Merge

=head1 DESCRIPTION

Merge the contents of two records together.

=cut


package EPrints::Plugin::Screen::Merge;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ swap succeed compare merge merge_all add_all /];

	$self->{icon} = "action_merge.png";

	$self->{appears} = [
		{
			place => "eprint_item_actions",
			position => 250,
		},
		{
			place => "eprint_review_actions",
			position => 250,
		},
	];

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	$self->SUPER::properties_from;

	my $repo = $self->repository;
	my $processor = $self->{processor};

	my $dataset;

	my $eprintid = $repo->param( "eprintid" );
	if( $eprintid )
	{
		my $dataset = $repo->dataset( "eprint" );
		$processor->{dataset} = $dataset;
		$processor->{dataobj} = $dataset->dataobj( $eprintid );
	}
	else
	{
		my $datasetid = $repo->param( "dataset" );
		$dataset = $repo->dataset( $datasetid );
		$processor->{dataset} = $dataset;

		if( my $leftid = $repo->param( "dataobj" ) )
		{
			$processor->{dataobj} = $dataset->dataobj( $leftid );
		}
	}

	my $rightid = $repo->param( "right" );
	if( $rightid )
	{
		$processor->{right} = $dataset->dataobj( $rightid );
	}
	else
	{
		$processor->{results} = $processor->{dataobj}->duplicates;
	}
}

sub can_be_viewed
{
	my( $self ) = @_;

	my $dataobj = $self->{processor}->{dataobj} || $self->{processor}->{eprint};
	return 0 if !defined $dataobj;

	my $dataset = $dataobj->{dataset};

	my $right = $self->{processor}->{right};
	if( defined $right )
	{
		return 0 if !$self->allow( $dataset->base_id . "/view", $right );
	}
	else
	{
		return 0 if $dataobj->duplicates->count == 0;
	}

	return $self->allow( $dataset->base_id . "/edit", $dataobj );
}

sub hidden_bits
{
	my( $self ) = @_;

	my $processor = $self->{processor};

	return(
		$self->SUPER::hidden_bits,
		dataset => $processor->{dataset}->id,
		dataobj => defined( $processor->{dataobj} ) ? $processor->{dataobj}->id : undef,
		defined( $processor->{right} ) ? (right => $processor->{right}->id) : (),
	);
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	my $uri = $self->repository->current_url;
	$uri->query_form( $self->hidden_bits );
	if( defined $self->{processor}->{field} )
	{
		$uri->fragment( $self->{processor}->{field}->name )
	}

	return $uri;
}

sub from
{
	my( $self ) = @_;

	my $processor = $self->{processor};

	my $action = $processor->{action};
	if( $action )
	{
		if( $action =~ s/^merge_(.+)$// )
		{
			$processor->{action} = "merge";
			$processor->{field} = $processor->{dataset}->field( $1 );
		}
		elsif( $action =~ s/^compare_(.+)$// )
		{
			$processor->{action} = "compare";
			$processor->{right} = $processor->{dataset}->dataobj( $1 );
		}
	}

	$self->SUPER::from;
}

sub allow_swap { shift->can_be_viewed }
sub allow_merge_all { shift->can_be_viewed }
sub allow_add_all { shift->allow_merge_all }
sub allow_compare { shift->can_be_viewed }
sub allow_succeed
{
	my( $self ) = @_;

	return 0 if !$self->allow( "eprint/derive_version", $self->{processor}->{right} );

	return $self->can_be_viewed;
}

sub allow_merge
{
	my ( $self ) = @_;

	my $processor = $self->{processor};
	my $field = $processor->{field};

	return 0 if !defined $field;
	return 0 if !$field->property( "import" );
	return 0 if $field->property( "sub_name" );

	return $self->allow_merge_all;
}

sub action_swap
{
	my( $self ) = @_;

	my $processor = $self->{processor};

	($processor->{dataobj}, $processor->{right}) = ($processor->{right}, $processor->{dataobj});
}

sub action_merge
{
	my( $self ) = @_;

	my $processor = $self->{processor};

	my $field = $processor->{field};

	$processor->{dataobj}->set_value(
			$field->name,
			$processor->{right}->value( $field->name )
		);
	$processor->{dataobj}->commit;
}

sub action_merge_all
{
	my( $self ) = @_;

	my $processor = $self->{processor};

	foreach my $field ($self->fields)
	{
		next if !$processor->{right}->is_set( $field->name );

		$processor->{dataobj}->set_value(
				$field->name,
				$processor->{right}->value( $field->name )
			);
	}
	$processor->{dataobj}->commit;
}

sub action_add_all
{
	my( $self ) = @_;

	my $processor = $self->{processor};

	foreach my $field ($self->fields)
	{
		next if $processor->{dataobj}->is_set( $field->name );
		next if !$processor->{right}->is_set( $field->name );

		$processor->{dataobj}->set_value(
				$field->name,
				$processor->{right}->value( $field->name )
			);
	}
	$processor->{dataobj}->commit;
}

# taken care of in from()
sub action_compare {}

sub action_succeed
{
	my( $self ) = @_;

	my $dataset = $self->{processor}->{dataset};
	my $dataobj = $self->{processor}->{dataobj};
	my $right = $self->{processor}->{right};

	$dataobj->set_value( "succeeds", $right->id );
	$dataobj->commit;
}

sub fields
{
	my( $self ) = @_;

	my $repo = $self->repository;
	my $dataset = $self->{processor}->{dataset};

	return grep {
			$_->property( "import" ) && !$_->property( "sub_name" ) && !$_->isa( "EPrints::MetaField::Subobject" )
		} $dataset->fields;
}

sub render
{
	my( $self ) = @_;

	my $repo = $self->repository;
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $dataset = $self->{processor}->{dataset};
	my $dataobj = $self->{processor}->{dataobj};
	my $right = $self->{processor}->{right};

	my $f = $xml->create_document_fragment;

	if( defined $right )
	{
		$f->appendChild( $self->render_merge );
	}
	else
	{
		my $dupes = $self->{processor}->{results};
		if( $dupes->count == 1 )
		{
			$self->{processor}->{right} = $dupes->item( 0 );
			$f->appendChild( $self->render_merge );
		}
		else
		{
			$f->appendChild( $xml->create_data_element( "div",
					$dataobj->render_citation_link,
				) );
			$f->appendChild( $self->render_duplicates );
		}
	}

	return $f;
}

sub render_dataobj_actions
{
	my( $self, $dataobj ) = @_;

	my $repo = $self->repository;
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $dataset = $self->{processor}->{dataset};

	local $self->{processor}->{dataobj} = $dataobj;
	local $self->{processor}->{right};

	# eprints have their own world of screens
	if( $dataset->base_id eq "eprint" )
	{
		local $self->{processor}->{eprint} = $dataobj;

		return $self->render_action_list_icons( "eprint_item_actions", {
				eprintid => $dataobj->id,
			} );
	}

	return $self->render_action_list_icons( [$dataset->base_id . "_item_actions", "dataobj_actions"], {
				dataset => $dataset->base_id,
				dataobj => $dataobj->id,
			} );
}

sub render_common_action_buttons
{
	my( $self ) = @_;

	my $repo = $self->repository;
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $dataset = $self->{processor}->{dataset};
	my $dataobj = $self->{processor}->{dataobj};
	my $right = $self->{processor}->{right};

	my $frag = $xml->create_document_fragment;

	$frag->appendChild( my $form = $self->render_form );

	$form->appendChild( my $div = $xml->create_element( "div", class => "ep_block" ) );

	my @actions;
	my @order;

	if( $dataset->base_id eq "eprint" && !$dataobj->is_set( "succeeds" ) )
	{
		push @actions, succeed => $self->phrase( "action:succeed:title",
						dataobj => $dataobj->id,
						right => $right->id,
					);
		push @order, "succeed";
	}

	$div->appendChild( $repo->render_action_buttons( @actions, _order => \@order ) );

	return $frag;
}

sub render_merge
{
	my( $self ) = @_;

	my $repo = $self->repository;
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $dataset = $self->{processor}->{dataset};
	my $dataobj = $self->{processor}->{dataobj};
	my $right = $self->{processor}->{right};

	my $frag = $xml->create_document_fragment;

	$frag->appendChild( $self->render_common_action_buttons );

	$frag->appendChild( my $form = $self->render_form );

	$form->appendChild( my $table = $xml->create_element( "table" ) );

	my $listing = $repo->plugin( "Screen::Listing",
			processor => $self->{processor},
		);

	my( $tr, $th, $td );

	$table->appendChild( $tr = $xml->create_element( "tr" ) );
	$tr->appendChild( $xml->create_element( "th", class => "ep_row" ) );
	$tr->appendChild( $xml->create_data_element( "td",
			$dataset->base_id . "." . $dataobj->id,
			align => "center",
			class => "ep_row",
		) );
	$tr->appendChild( $xml->create_element( "td", class => "ep_row" ) );
	$tr->appendChild( $xml->create_data_element( "td",
			$dataset->base_id . "." . $right->id,
			align => "center",
			class => "ep_row",
		) );

	$table->appendChild( $tr = $xml->create_element( "tr" ) );
	$tr->appendChild( $xml->create_element( "th", class => "ep_row" ) );
	$tr->appendChild( $xml->create_data_element(
			"td",
			$self->render_dataobj_actions( $dataobj ),
			class => "ep_row",
		) );
	{
		local $self->{processor}->{dataobj} = $right;
		if( $self->can_be_viewed )
		{
			$tr->appendChild( $xml->create_data_element( "td",
					$xhtml->action_icon(
						"swap",
						$repo->current_url( path => "static", "style/images/action_swap.png" ),
						alt => $self->phrase( "action:swap:title" ),
						title => $self->phrase( "action:swap:title" ),
					),
					class => "ep_row",
				) );
		}
		else
		{
			$tr->appendChild( $xml->create_element( "td", class => "ep_row" ) );
		}
	}
	$tr->appendChild( $xml->create_data_element(
			"td",
			$self->render_dataobj_actions( $right ),
			class => "ep_row",
		) );

	my $has_diff = 0;

	foreach my $field ($self->fields)
	{
		my $fieldid = $field->name;

		my $left_value = $field->get_value( $dataobj );
		my $right_value = $field->get_value( $right );

		my $is_set = 0;
		$is_set |= 1 if EPrints::Utils::is_set( $left_value );
		$is_set |= 2 if EPrints::Utils::is_set( $right_value );
		$is_set |= 4 if EPrints::Utils::cmp_deeply( $left_value, $right_value );

		next if $is_set == 4;

		$has_diff = 1 if !($is_set & 4);

		$table->appendChild( my $tr = $xml->create_element( "tr", id => $fieldid ) );
		$tr->appendChild( $xml->create_data_element( "th", [
					[ "a", undef, name => $fieldid, ],
					[ "span", $field->render_name( $repo ), ],
				],
				class => "ep_row",
			) );
		$tr->appendChild( my $td_left = $xml->create_data_element( "td",
				$field->render_value( $repo, $left_value ),
				class => "ep_row",
			) );
		$tr->appendChild( my $td_actions = $xml->create_element( "td",
				class => "ep_row",
			) );
		$tr->appendChild( my $td_right = $xml->create_data_element( "td",
				$field->render_value( $repo, $right_value ),
				class => "ep_row"
			) );

		my @actions;

		if( $is_set == 1 )
		{
			$td_left->setAttribute( class => "ep_row ep_diff_add" );
		}
		elsif( $is_set == 2 )
		{
			$td_right->setAttribute( class => "ep_row ep_diff_add" );
			push @actions, "merge";
		}
		elsif( $is_set == 3 )
		{
			$td_left->setAttribute( class => "ep_row ep_diff_change" );
			$td_right->setAttribute( class => "ep_row ep_diff_change" );
			push @actions, "merge";
		}
		else
		{
			$td_left->setAttribute( colspan => 3 );
			$xml->dispose( $tr->removeChild( $td_actions ) );
			$xml->dispose( $tr->removeChild( $td_right ) );
		}

		my @buttons;
		my @order;
		for(@actions)
		{
			push @order, "$_\_$fieldid";
			push @buttons,
				"$_\_$fieldid" => $self->phrase( "action:$_:title" );
		}
		$td_actions->appendChild( $repo->render_action_buttons(
				@buttons,
				_order => \@order,
			) );
	}

	if( $has_diff )
	{
		$form->appendChild( $xml->create_data_element( "div",
			$repo->render_action_buttons(
				add_all => $self->phrase( "action:add_all:title" ),
				merge_all => $self->phrase( "action:merge_all:title" ),
				_order => [qw( add_all merge_all )]
			),
			class => "ep_block"
		) );
	}

	return $frag;
}

# WARNING! Also called by Screen::EPrint::Duplicates
sub render_duplicates
{
	my( $self ) = @_;

	my $repo = $self->repository;
	my $xml = $repo->xml;
	my $xhtml = $repo->xhtml;

	my $dataset = $self->{processor}->{dataset};
	my $dataobj = $self->{processor}->{dataobj};
	my $dupes = $self->{processor}->{results};

	my $frag = $xml->create_document_fragment;

	$frag->appendChild( my $form = $self->render_form );

	$form->appendChild( my $table = $xml->create_element( "table" ) );

	my $i = 1;

	$dupes->map(sub {
		(undef, undef, my $dupe) = @_;

		$table->appendChild( my $tr = $xml->create_element( "tr" ) );

		$tr->appendChild( $xml->create_data_element( "th",
				$xml->create_text_node( $i++ ),
				class => "ep_row",
			) );

		$tr->appendChild( $xml->create_data_element( "td",
				$dupe->render_citation( undef, url => $dupe->uri ),
				class => "ep_row",
			) );

		$tr->appendChild( $xml->create_data_element( "td",
				$repo->render_action_buttons(
						"compare_".$dupe->id => $self->phrase( "action:compare:title" ),
					),
				class => "ep_row",
			) );
	});

	if( $dupes->count == 0 )
	{
		$form->appendChild( $repo->render_message(
			"warning",
			$self->html_phrase( "no_dupes" ),
		) );
	}

	$form->appendChild( $table = $xml->create_element( "table" ) );

	$table->appendChild( my $tr = $xml->create_element( "tr" ) );

	my $key_field = $dataset->key_field;
	my $input_field = $key_field->clone;
	$input_field->set_property( name => "right" );

	$form->appendChild( $self->html_phrase( "select_right_form",
			name => $key_field->render_name( $repo ),
			input => $input_field->render_input_field( $repo ),
			buttons => $repo->render_action_buttons(
				compare => $self->phrase( "action:compare:title" ),
			),
		) );


	return $frag;
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

