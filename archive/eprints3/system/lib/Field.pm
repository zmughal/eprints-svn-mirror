######################################################################
#
# EPrints::Field
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

B<EPrints::Field> - Class representing a named field.

=head1 DESCRIPTION

This represents a single field with a name and a type.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
# name (string)
#
#  The name of this field. Lowercase alphanumerics only and must 
#  start with a letter.
#
# type (EPrints::Type)
#
#  The id of the user who deposited this eprint (if any). Scripted importing
#  could cause this not to be set.
#
######################################################################

package EPrints::Field;

use strict;

use EPrints::Type;
use EPrints::Session;


######################################################################
=pod

=item $field = EPrints::Field->new( $name, $type );

Construct a new field with the given name and type.

=cut
######################################################################

sub new
{
	my( $class, $name, $type ) = @_;

	my $self = {
		name => $name,
		type => $type 
	};

	bless $self, $class;

	return $self;
}

######################################################################
=pod

=item $string = $field->toString( [$indent] )

Convert this object to a string.

=cut
######################################################################

sub toString
{
	my( $self, $indent ) = @_;

	$indent = 0 unless defined $indent;

	return "    "x$indent."\$".$self->{name}."[\n".$self->{type}->toString($indent+1)."    "x$indent."]\n";
}

######################################################################
=pod

=item $string = $type->toXML( [$indent] )

Convert this object to an XML config fragment. 

=cut
######################################################################

sub toXML
{
	my( $self, $indent ) = @_;

	$indent = 0 unless defined $indent;

	my $f = &SESSION->make_doc_fragment;
	my $el = &SESSION->make_element( 'field', name=>$self->{name} );
	$f->appendChild( &SESSION->make_text( "    "x$indent ) );
	$f->appendChild( $el );
	$el->appendChild( &SESSION->make_text("\n"));
	$el->appendChild( $self->{type}->toXML( $indent+1 ) );
	$el->appendChild( &SESSION->make_text( "    "x$indent ) );
	$f->appendChild( &SESSION->make_text("\n"));

	return $f;
}
	
######################################################################
=pod

=item $fieldname = $field->getName()

Return the name string of this field.

=cut
######################################################################

sub getName
{
	my( $self ) = @_;

	return $self->{"name"};
}
	
######################################################################

=pod

=item $type = $field->getType()

Return the type (obj) of this field.

=cut
######################################################################

sub getType
{
	my( $self ) = @_;

	return $self->{"type"};
}
	
######################################################################

=pod

=item $type = $field->getSQLType()

Return the SQL field type of this field.

=cut
######################################################################

sub getSQLType
{
	my( $self ) = @_;

	my $sqltype = $self->{"type"}->getSQLType();

	return undef if( !defined $sqltype );
		
	return $self->{"name"}.' '.$sqltype;
}
	



######################################################################
1; # For use/require success
######################################################################

=pod
=back
=cut

