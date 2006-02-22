package EPrints::Plugin::Input;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::Input::ABSTRACT = 1;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Base input plugin: This should have been subclassed";
	$self->{visible} = "all";

	return $self;
}

sub render_name
{
	my( $plugin ) = @_;

	return $plugin->{session}->make_text( $plugin->{name} );
}

sub matches 
{
	my( $self, $test, $param ) = @_;

	if( $test eq "is_visible" )
	{
		return( $self->is_visible( $param ) );
	}
	if( $test eq "can_produce" )
	{
		return( $self->can_produce( $param ) );
	}

	# didn't understand this match 
	return $self->SUPER::matches( $test, $param );
}


# all, staff or ""
sub is_visible
{
	my( $plugin, $vis_level ) = @_;

	return( 1 ) unless( defined $vis_level );

	return( 0 ) unless( defined $plugin->{visible} );

	if( $vis_level eq "all" && $plugin->{visible} ne "all" ) {
		return 0;
	}

	if( $vis_level eq "staff" && $plugin->{visible} ne "all" && $plugin->{visible} ne "staff" ) {
		return 0;
	}

	return 1;
}

sub can_produce
{
	my( $plugin, $format ) = @_;

	foreach my $a_format ( @{$plugin->{produce}} ) {
		if( $a_format =~ m/^(.*)\*$/ ) {
			my $base = $1;
			return( 1 ) if( substr( $format, 0, length $base ) eq $base );
		}
		else {
			return( 1 ) if( $format eq $a_format );
		}
	}

	return 0;
}


# parse a file of records.
# return an EPrints::List of the imported items.
sub input_list
{
	my( $plugin, %opts ) = @_;

	return undef;
}

#stub.
sub input_dataobj
{
	my( $plugin, $data ) = @_;
	
	my $r = "error. input_dataobj should be overridden";

	$plugin->log( $r );

	return $r;
}

sub data_to_dataobj
{
	my( $plugin, $dataset, $data ) = @_;
	
	if( $plugin->{parse_only} )
	{
		return;
	}

	return $dataset->create_object( $plugin->{session}, $data );
}

sub warning
{
	my( $plugin, $msg ) = @_;

	$plugin->{session}->get_repository->log( $plugin->{id}.": ".$msg );
}	

sub error
{
	my( $plugin, $msg ) = @_;

	$plugin->warning( $msg );
}

1;
