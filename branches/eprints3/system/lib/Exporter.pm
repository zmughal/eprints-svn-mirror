######################################################################
#
# EPrints::Exporter
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

B<EPrints::Exporter> - 

=head1 DESCRIPTION


=over 4

=cut

package EPrints::Exporter;


use strict;

######################################################################
=pod

=item $exporter = EPrints::Exporter->new( %properties )

Create a new exporter. 

=cut
######################################################################

sub new
{
	my( $class, %opts ) = @_;

	my $self = { opts=>{%opts} };
	bless $self, $class;

	if( $self->{opts}->{output} eq 'fh' )
	{
		if( !defined $self->{opts}->{fh} )
		{
			EPrints::Config::abort( 'fh exporter does not have fh set' );
		} 
	}
	elsif( $self->{opts}->{output} eq 'web' )
	{
		if( !defined $self->{opts}->{mimetype} )
		{
			EPrints::Config::abort( 'web exporter does not have mimetype set' );
		} 
		&SESSION->send_http_header( content_type=>$self->{opts}->{mimetype} );
	}
	else
	{
		EPrints::Config::abort( 'unsupported exporter output type: '.$self->{opts}->{output} );
	}

	return( $self );
}

######################################################################
=pod

=item $exporter->data( $data )

Do with the $data whetever this type of exporter does.

=cut
######################################################################

sub data
{
	my( $self, $data )= @_;

	if( $self->{opts}->{output} eq 'fh' )
	{
		print {$self->{opts}->{fh}} $data;
	}
	elsif( $self->{opts}->{output} eq 'web' )
	{
		print $data;	
	}
}

######################################################################
=pod

=item $exporter->finish()

Clean up and pass a return value if appropriate.

=cut
######################################################################

sub finish
{
	my( $self ) = @_;
}


1;
