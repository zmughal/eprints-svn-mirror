=head1 NAME

EPrints::Plugin::Event::Indexer

=cut

package EPrints::Plugin::Event::Indexer;

@ISA = qw( EPrints::Plugin::Event );

use strict;

sub index
{
	my( $self, $dataobj, @fieldnames ) = @_;

	if( !defined $dataobj )
	{
		Carp::carp "Expected dataobj argument";
		return 0;
	}

	my $dataset = $dataobj->get_dataset;

	my @fields;
	for(@fieldnames)
	{
		next unless $dataset->has_field( $_ );
		push @fields, $dataset->get_field( $_ );
	}

	return $self->_index_fields( $dataobj, \@fields );
}

sub index_all
{
	my( $self, $dataobj ) = @_;

	if( !defined $dataobj )
	{
		Carp::carp "Expected dataobj argument";
		return 0;
	}

	my $dataset = $dataobj->get_dataset;

	return $self->_index_fields( $dataobj, [$dataset->get_fields] );
}

sub removed
{
	my( $self, $datasetid, $id ) = @_;

	my $dataset = $self->{session}->dataset( $datasetid );
	return if !defined $dataset;

	my $rc = $self->{session}->run_trigger( EPrints::Const::EP_TRIGGER_INDEX_REMOVED,
		dataset => $dataset,
		id => $id,
	);
	return 1 if defined $rc && $rc eq EPrints::Const::EP_TRIGGER_DONE;

	foreach my $field ($dataset->fields)
	{
		EPrints::Index::remove( $self->{session}, $dataset, $id, $field->name );
	}
}

sub _index_fields
{
	my( $self, $dataobj, $fields ) = @_;

	my $session = $self->{session};
	my $dataset = $dataobj->get_dataset;

	my $rc = $session->run_trigger( EPrints::Const::EP_TRIGGER_INDEX_FIELDS,
		dataobj => $dataobj,
		fields => $fields,
	);
	return 1 if defined $rc && $rc eq EPrints::Const::EP_TRIGGER_DONE;

	foreach my $field (@$fields)
	{
		EPrints::Index::remove( $session, $dataset, $dataobj->get_id, $field->get_name );
		next unless( $field->get_property( "text_index" ) );

		my $value = $field->get_value( $dataobj );
		next unless EPrints::Utils::is_set( $value );	

		EPrints::Index::add( $session, $dataset, $dataobj->get_id, $field->get_name, $value );
	}

	return 1;
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

