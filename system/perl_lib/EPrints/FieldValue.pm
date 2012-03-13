=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::FieldValue> - values with behaviour

=head1 SYNOPSIS

	$v = $dataobj->field_value( "title" );
	print "$v";
	print $v->to_xml->toString();
	print $v->to_json;
	
	$v = $dataobj->field_value( "datestamp" );
	if( $v->field->can( "year" ) )
	{
		print $v->year;
	}
	
	$v = $dataobj->field_value( "creators_name" );
	foreach my $item (@{$v})
	{
		print "$v\n";
	}

=head1 DESCRIPTION

A FieldValue wraps a field and value enabling easier access to value-formatting commands. Any method called on the FieldValue will be passed to the <EPrints::MetaField> object with the value as the first argument.

	$xml = $dataobj->field_value( "title" )->to_xml( version => 3 );
	# is equivalent to
	$xml = $dataobj->{dataset}->field( "title" )
		->to_xml( $dataobj->value( "title" ), version => 3 )

=head2 Stringification

The stringified form of a FieldValue is equivalent to calling L<EPrints::MetaField/to_text> on the field.

	$v = $eprint->field_value( "creators_name" );
	"$v"; # Smith, J; Jones, P

=head2 List-Deferencing

To hide the complexity of working with fields with the C<multiple> property set, FieldValue provides list-dereferencing of both multiple and single values.

	# Doesn't matter if "title" is multiple or not
	foreach my $title (@{$eprint->field_value( "title" )})
	{
		...
	}

Dereferencing a field value results in a list of FieldValues containing a single value from the multiple.

=head1 METHODS

=over 4

=item $value = EPrints::FieldValue->new( $field, $value )

Returns a new EPrints::FieldValue with behaviour from L<$field|EPrints::MetaField>.

If the metafield is multiple $value must be an array reference.

=cut

package EPrints::FieldValue;

use overload
	'""' => \&stringify,
	'@{}' => \&listify;

use Scalar::Util qw( refaddr );
use EPrints::FieldValue::Item;

use strict;

my %FIELD;
my %VALUE;

our $AUTOLOAD;

sub new
{
	my( $class, $field, $value ) = @_;

	my $self = bless \$value, $class;

	$FIELD{refaddr($self)} = $field;
	$VALUE{refaddr($self)} = $value;

	return $self;
}

sub DESTROY
{
	delete $FIELD{refaddr($_[0])};
	delete $VALUE{refaddr($_[0])};
}

=item $field = $value->field()

Returns the L<EPrints::MetaField> attached to this value.

=cut

sub field { $FIELD{refaddr($_[0])} }

=item $v = $value->value()

Returns the raw Perl value attached to this value.

The type of thing returned will depend on the field type and may be an array reference, hash reference, simple scalar or L<EPrints::DataObj>.

=cut

sub value { $VALUE{refaddr($_[0])} }

sub stringify
{
	my( $self ) = @_;

	return $FIELD{refaddr($self)}->to_text( $VALUE{refaddr($self)} );
}

sub listify
{
	my( $self ) = @_;

	my $field = $FIELD{refaddr($self)};
	return [ $self ] if !$field->property( "multiple" );

	return [ map { EPrints::FieldValue::Item->new( $field, [ $_ ] ) } @{$VALUE{refaddr($self)}} ];
}

sub AUTOLOAD
{
	my( $self, @args ) = @_;
	$AUTOLOAD =~ s/^.*:://;
	my $field = $self->field;
	Carp::croak( "Can't locate object method \"$AUTOLOAD\" via package \"".ref($field)."\"" )
		if !$field->can( $AUTOLOAD );
	return $field->$AUTOLOAD( $VALUE{refaddr($_[0])}, @args );
}

=back

=cut

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

