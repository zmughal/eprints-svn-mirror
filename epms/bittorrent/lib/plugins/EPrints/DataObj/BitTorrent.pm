=head1 NAME

B<EPrints::DataObj::BitTorrent> - bittorrent tracker

=head1 DESCRIPTION

This is an internal class.

=head1 METHODS

=over 4

=cut

package EPrints::DataObj::BitTorrent;

@ISA = ( 'EPrints::DataObj' );

use EPrints;
use List::Util;

use strict;

=item $thing = EPrints::DataObj::BitTorrent->get_system_field_info

Core fields.

=cut

sub get_system_field_info
{
	my( $class ) = @_;

	return
	( 
		{ name=>"bittorrentid", type=>"id", required=>1 },

		{ name=>"document", type=>"itemref", datasetid=>"document", required=>1 },

		{
			name=>"peers",
			type=>"multipart",
			multiple=>1,
			fields=>[
				{ sub_name=>"mtime", type=>"int", },
				{ sub_name=>"ip", type=>"id", },
				{ sub_name=>"port", type=>"int", maxlength=>5, },
				{ sub_name=>"left", type=>"bigint", },
				{ sub_name=>"uploaded", type=>"bigint", },
				{ sub_name=>"downloaded", type=>"bigint", },
				{ sub_name=>"peer_id", type=>"id", },
			],
		},
	);
}

######################################################################

=back

=head2 Class Methods

=cut

######################################################################

######################################################################
=pod

=item $dataset = EPrints::DataObj::UploadProgress->get_dataset_id

Returns the id of the L<EPrints::DataSet> object to which this record belongs.

=cut
######################################################################

sub get_dataset_id
{
	return "bittorrent";
}

######################################################################

=head2 Object Methods

=cut

######################################################################

=item $peers = $bittorrent->peers( [ $n ] )

Returns the peers in non-compact form (upto $n picked randomly):

	[{
		'peer id' => ...,
		ip => ...,
		port => ...,
	}]

=cut

sub peers
{
	my( $self, $n ) = @_;

	my $peers = $self->value( "peers" );
	$n = @$peers if !defined $n;

	my @picklist = List::Util::shuffle( 0 .. $#$peers );
	splice(@picklist,$n);

	return [
		map { {
			'peer id' => $_->{peer_id},
			ip => $_->{ip},
			port => $_->{port},
		} } @$peers[@picklist]
	];
}

=item $peers = $bittorrent->compact_peers( [ $n ] )

Returns the peers in compact (6-byte) form (upto $n picked randomly).

=cut

sub compact_peers
{
	my( $self, $n ) = @_;

	my $peers = $self->peers( $n );

	return join '', map {
			pack("C4n", split(/\./, $_->{ip}), $_->{port})
		}
		grep {
			$_->{ip} =~ /^\d{1,3}(\.\d{1,3}){3}$/
		} @$peers;
}

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::DataObj> and L<EPrints::DataSet>.

=cut


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

