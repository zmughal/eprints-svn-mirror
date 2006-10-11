######################################################################
#
# EPrints::Type
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

B<EPrints::Type> - A single metadata field type.

=head1 DESCRIPTION

This object describes a single data type. It will always be
subclassed as one of the modules in EPrints::Type::

=over 4

=cut

package EPrints::Type;

use Carp;
use EPrints::Session;

######################################################################
=pod

=item $type = EPrints::Type::create( %params );

[STATIC] Create a new field type of the given type.

=cut
######################################################################

sub create
{
	my( %params ) = @_;

	my $realclass = "EPrints::Type::".$params{class};
	eval 'use '.$realclass.';';
	confess "couldn't parse $realclass: $@" if $@;
	my $self = $realclass->new( %params );
	return $self;
}

######################################################################
=pod

=item $type = EPrints::Type->new( %params );

Create a new type object.

=cut
######################################################################

sub new
{
	my( $class, %params ) = @_;

	if( $class eq "EPrints::Type" )
	{
		croak "Attempt to create new EPrints::Type (should be creating a sub-type of this abstract class)";
	}
	my $self = {};
	bless $self, $class;
	$self->{class} = $params{class};
	$self->{fields} = $params{fields};
	$self->{types} = $params{types};
	$self->buildFieldMap;

	return $self;
}

######################################################################
=pod

=item $type->buildFieldMap

Rebuild the field map hash, if the fields get altered after 'new'
is called.

=cut
######################################################################

sub buildFieldMap
{
	my( $self ) = @_;

	$self->{fmap} = {};

	return unless( defined $self->{fields} );
	
	foreach my $field ( @{$self->{fields}} )
	{
		$self->{fmap}->{$field->getName} = $field;
	}
}


######################################################################
=pod

=item $type = $dataobj->render_value( $value, %opts )

Use a conversion plugin to convert a value of this type into 
an XHTML fragment.

=cut
######################################################################

sub renderValue
{
	my( $self, $value, %opts ) = @_;

	#$mode = 'default' unless defined $mode;
	$mode = 'default';
	$opts{data} = $value;
	$opts{type} = $self;
	$mode = $opts{mode} if defined( $opts{mode} );

	return &ARCHIVE->plugin(
		'convert/value.'.$self->{class}.'/xhtml/'.$mode,  
		%opts );
}

######################################################################
=pod

=item $sqltype = $type->getClass()

Return the class of this type.

=cut
######################################################################

sub getClass
{
	my( $self ) = @_;

	return $self->{class};
}

######################################################################
=pod

=item $sqltype = $type->getType

Return the subtype associated with this type. Only meaningful for
list's really.

=cut
######################################################################

sub getType
{
	my( $self ) = @_;

	return $self->{types}->[0];
}

######################################################################
=pod

=item $sqltype = $type->getFields

Return the fields associated with this type. Only meaningful for
struct's really.

=cut
######################################################################

sub getFields
{
	my( $self ) = @_;

	return $self->{fields};
}

######################################################################
=pod

=item $sqltype = $type->getSQLType()

Return the SQL equivalent of this type. Only primitives acutally
have sql types.

=cut
######################################################################

sub getSQLType
{
	my( $self ) = @_;

	return undef;
}

######################################################################
=pod

=item $something = $type->plugin( $plugin, %params );

Call the given plugin on this type with the given params.

=cut
######################################################################

sub plugin
{
	my( $self, $plugin, %params ) = @_;

	my $doclass = $self->{class};
	while( defined $doclass )
	{
		my $plugin = 'type/'.$plugin.'/system.'.$doclass;
#		print "TRY:$plugin\n";
		if( &ARCHIVE->hasPlugin( $plugin ) )
		{
			$params{type} = $self;
			return &ARCHIVE->plugin( $plugin, %params );
		}
		$doclass = &ARCHIVE->get_conf( 'type_parent_'.$doclass );
	}
	die "Could not find plugin: type/".$plugin.'/system.'.$self->{class};
}

######################################################################
1;
