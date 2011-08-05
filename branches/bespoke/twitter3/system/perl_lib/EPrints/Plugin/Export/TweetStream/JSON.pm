=head1 NAME

EPrints::Plugin::Export::JSON

=cut

package EPrints::Plugin::Export::TweetStream::JSON;

use EPrints::Plugin::Export::JSON;
use JSON;

@ISA = ( "EPrints::Plugin::Export::JSON" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "JSON TweetStream";
	$self->{accept} = [ 'dataobj/tweetstream' ];
	$self->{visible} = "all"; 
	$self->{suffix} = ".js";
	$self->{mimetype} = "application/json; charset=utf-8";

	return $self;
}

sub _epdata_to_json
{
	my( $self, $epdata, $depth, $in_hash, %opts ) = @_;

	my $pad = "   " x $depth;
	my $pre_pad = $in_hash ? "" : $pad;

	my $json = JSON->new->allow_nonref;

	if( ref ($epdata) eq 'EPrints::DataObj::Tweet' )
	{
		my $data = $epdata->data_for_export;

		my $json_data = $json->pretty->encode($data);
		chomp $json_data;
		$json_data =~ s/^/$pre_pad/g;
		$json_data =~ s/\n/\r$pre_pad/g;

		return $json_data;
	}

	my $r = "{\n";

	my $data = $epdata->data_for_export;
	my $json_data = $json->pretty->encode($data);
	chomp $json_data;

	$json_data =~ s/^\s*{\n//;
	$json_data =~ s/\n\s*}$//g;
	$r .= $json_data . ",\n";

	$r .= $pre_pad."\"tweets\" : \[\n";

	my $first = 1;
	foreach my $tweetid (@{$epdata->value('items')})
	{
		$r .= ",\n"if !$first;
		$first = 0;
		my $tweet = EPrints::DataObj::Tweet->new($epdata->{session}, $tweetid);
		next unless $tweet;
		$r .= $self->_epdata_to_json($tweet, $depth + 1, 0, %opts )
	}
	$r .= "\n$pad\]\n}\n";
	return $r;
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

