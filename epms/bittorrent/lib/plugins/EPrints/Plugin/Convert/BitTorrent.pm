package EPrints::Plugin::Convert::BitTorrent;

=pod

=head1 NAME

EPrints::Plugin::Convert::BitTorrent - create a BitTorrent .torrent from a document

=head1 DESCRIPTION

=cut

use EPrints::Plugin::Convert;
use Bencode;
use Digest::SHA;

@ISA = qw( EPrints::Plugin::Convert );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Create .torrent";
	$self->{visible} = "all";
	$self->{advertise} = 0;
	$self->{mimetype} = "application/x-bittorrent";

	return $self;
}

sub can_convert
{
	my ($self, $doc) = @_;

	return ($self->{mimetype} => {
			plugin => $self,
		});
}

sub export
{
	my ( $self, $dir, $doc, $type ) = @_;

	my $repo = $self->{repository};
	my $eprint = $doc->parent;
	my $files = $doc->value( "files" );

	my $desc = $eprint->render_citation_link;
	my $comment = EPrints::Utils::tree_to_utf8( $desc );

	my $web_seed;
	if( @$files == 1 )
	{
		$web_seed = $doc->get_url( $files->[0]->value( "filename" ) );
	}
	else
	{
		$web_seed = $repo->get_url( host => 1, path => "cgi", "tracker/seed/" );
	}

	my %metainfo = (
		announce => "".$repo->get_url( host => 1, path => "cgi", "tracker/announce" ),
		comment => $comment,
		encoding => "UTF-8",
		'creation date' => time(),
		'created by' => $repo->config( "version" ),
		'url-list' => ["".$web_seed],
		private => 1,
	);

	$repo->xml->dispose( $desc );

	my $name = sprintf("%s-%08d-%02d", $repo->get_id, $eprint->id, $doc->value( "pos" ));

	my %info = ();
	$metainfo{info} = \%info;

	if( @$files == 1 )
	{
		foreach my $file (@$files)
		{
			$info{name} = $info{'name.utf-8'} = $file->value( "filename" );
			$info{length} = $file->value( "filesize" );
			$info{md5sum} = $file->value( "hash" );
		}
	}
	else
	{
		$info{name} = $info{'name.utf-8'} = \$name;
		$info{files} = [];
		foreach my $file (@$files)
		{
			my @path = map { \(my $s = $_) } split '/', $file->value( "filename" );
			push @{$info{files}}, {
				length => $file->value( "filesize" ),
				md5sum => $file->value( "hash" ),
				path => \@path,
				'path.utf-8' => \@path,
			};
		}
	}
	# fixed size, for now
	my $piece_size = 2 ** 19;

	$info{'piece length'} = $piece_size;
	$info{pieces} = '';

	my $buffer = '';
	foreach my $file (@$files)
	{
		use bytes;
		$file->get_file( sub {
			$buffer .= $_[0];
			while(length($buffer) > $piece_size)
			{
				$info{pieces} .= Digest::SHA::sha1( substr($buffer,0,$piece_size) );
				substr($buffer,0,$piece_size) = '';
			}
			return 1;
		});
	}
	$info{pieces} .= Digest::SHA::sha1( $buffer )
		if length($buffer) || $info{pieces} eq '';

	my $fn = "$name.torrent";
	open(my $fh, ">", "$dir/$fn") or die "Error writing to $dir/$fn: $!";
	syswrite($fh, Bencode::bencode( \%metainfo ));
	close($fh);
	open($fh, ">", "$dir/info_hash");
	syswrite($fh, Digest::SHA::sha1( Bencode::bencode( $metainfo{info} )));
	close($fh);

	return( $fn, "info_hash" );
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

