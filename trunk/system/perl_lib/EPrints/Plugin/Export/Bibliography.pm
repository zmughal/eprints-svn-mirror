=head1 NAME

EPrints::Plugin::Export::Bibliography

=cut

package EPrints::Plugin::Export::Bibliography;

@ISA = qw( EPrints::Plugin::Export );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Bibliography";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "";
	$self->{advertise} = 0;

	return $self;
}

sub convert_dataobj
{
	my( $self, $eprint ) = @_;

	my @refs;

	my $doc = $self->{session}->dataset( "document" )->search(
		filters => [
			{ meta_fields => [qw( content )], value => "bibliography" },
			{ meta_fields => [qw( format )], value => "text/xml" },
			{ meta_fields => [qw( eprintid )], value => $eprint->id },
		])->item( 0 );

	if( defined $doc )
	{
		my $buffer = "";
		$doc->stored_file( $doc->get_main )->get_file( sub { $buffer .= $_[0] } );
		my $xml = eval { $self->{session}->xml->parse_string( $buffer ) };
		if( defined $xml )
		{
			for($xml->documentElement->childNodes)
			{
				next if $_->nodeName ne "eprint";
				my $epdata = EPrints::DataObj::EPrint->xml_to_epdata(
					$self->{session},
					$_ );
				my $ep = EPrints::DataObj::EPrint->new_from_data(
					$self->{session},
					$epdata );
				push @refs, $ep;
			}
			$self->{session}->xml->dispose( $xml );
		}
	}
	elsif( $eprint->exists_and_set( "referencetext" ) )
	{
		my $bibl = $eprint->value( "referencetext" );
		for(split /\s*\n\s*\n+/, $bibl)
		{
			push @refs, $_;
		}
	}

	return \@refs;
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

