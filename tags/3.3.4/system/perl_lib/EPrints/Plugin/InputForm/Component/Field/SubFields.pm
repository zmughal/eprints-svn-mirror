=head1 NAME

EPrints::Plugin::InputForm::Component::Field::SubFields

=cut

package EPrints::Plugin::InputForm::Component::Field::SubFields;

use EPrints::Plugin::InputForm::Component::Field;
@ISA = qw( EPrints::Plugin::InputForm::Component::Field );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );
	
	$self->{name} = "Subfields Selector";
	$self->{visible} = "all";
	$self->{visdepth} = 1;

	return $self;
}

sub update_from_form
{
	my( $self, $processor ) = @_;

	my $session = $self->{session};
	my $metafield = $self->{dataobj};
	my $mfdatasetid = $metafield->get_value( "mfdatasetid" );

	my $dataset = $session->dataset( $mfdatasetid );

	my $potential = $self->potential_metafields;

	foreach my $sub_name (keys %$potential)
	{
		my $mf = $potential->{$sub_name};
		my $selected = $mf->is_set( "parent" );
		my $name = $mf->value( "name" );

		my $id = $self->{prefix} . "_" . $name;

		$selected = EPrints::Utils::is_set( $session->param( $id ) );

		if( $selected )
		{
			$mf->set_value( "parent", $metafield->id );
		}
		else
		{
			$mf->set_value( "parent", undef );
		}
		$mf->commit;
	}
}

sub render_content
{
	my( $self, $surround ) = @_;

	my $session = $self->{session};
	my $field = $self->{config}->{field};
	my $metafield = $self->{dataobj};

	my $value = $metafield->get_value( $field->get_name );
	my @value = @$value;

	my $frag = $session->make_doc_fragment;

	my $dataset = $session->dataset( $metafield->get_value( "mfdatasetid" ) );

	my $potential = $self->potential_metafields;

	foreach my $sub_name (sort keys %$potential)
	{
		my $mf = $potential->{$sub_name};
		my $selected = $mf->is_set( "parent" ) && $mf->value( "parent" ) == $metafield->id;
		my $name = $mf->value( "name" );

		my $id = $self->{prefix} . "_" . $name;

		my $label = $session->make_element( "label" );
		my $input = $session->render_input_field(
			type => "checkbox",
			name => $id,
			value => $name,
			($selected ? (checked => "checked") : ()),
		);
		$label->appendChild( $input );
		$label->appendChild( $session->make_text( $name ) );
		$frag->appendChild( $label );
		$frag->appendChild( $session->make_element( "br" ) );
	}

	return $frag;
}

sub potential_metafields
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $field = $self->{config}->{field};
	my $metafield = $self->{dataobj};
	my $prefix = $metafield->get_value( "name" ) . "_";

	my $dataset = $metafield->get_dataset;

	my $results = $dataset->search(
		filters => [
			{ meta_fields => ["provenance"], value => "user" },
			{ meta_fields => ["mfdatasetid"], value => $metafield->value( "mfdatasetid" ) },
		]);

	my %potential;
	$results->map( sub {
		my( undef, undef, $mf ) = @_;

		my $name = $mf->get_value( "name" );
		return unless $name =~ s/^$prefix//;

		my $field = $mf->make_field_object;
		return if !defined $field;
		return if $field->isa( "EPrints::MetaField::Compound" );

		$potential{$name} = $mf;
	} );

	return \%potential;
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

