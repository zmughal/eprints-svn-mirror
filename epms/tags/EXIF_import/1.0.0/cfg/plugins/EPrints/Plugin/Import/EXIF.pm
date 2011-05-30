=head1 NAME

EPrints::Plugin::Import::EXIF

=cut

package EPrints::Plugin::Import::EXIF;

use EPrints::Plugin::Import;

@ISA = qw( EPrints::Plugin::Import );

use strict;

eval "use IMAGE::Exif";

our $DISABLE = $@ ? 1 : 0;

our $exiftool;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	my $repo = $self->{repository};
	$exiftool = $repo->get_repository->get_conf( "exif_import", "exif_path" );
	if ( -e $exiftool ) {
		$DISABLE = 0;
	} elsif ( !$DISABLE ) {
		$exiftool = undef;
	}

	$self->{name} = "Import (exif)";
	$self->{produce} = [qw( dataobj/eprint )];
	$self->{accept} = [qw( image/jpeg )];
	$self->{advertise} = 1;
	$self->{actions} = [qw( metadata )];

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $session = $self->{session};

	my %flags = map { $_ => 1 } @{$opts{actions}};
	my $filename = $opts{filename};

	my $format = $session->call( "guess_doc_type", $session, $filename );

	my $epdata = {
		documents => [{
			format => $format,
			main => $filename,
			files => [{
				filename => $filename,
				filesize => (-s $opts{fh}),
				_content => $opts{fh}
			}],
		}],
	};

	my $filepath = "$opts{fh}";

	if( $flags{metadata} )
	{
		$self->_parse_exif( $filepath, %opts, epdata => $epdata );
	}

	my @ids;
	my $dataobj = $self->epdata_to_dataobj( $opts{dataset}, $epdata );
	push @ids, $dataobj->id if $dataobj;

	return EPrints::List->new(
		session => $session,
		dataset => $opts{dataset},
		ids => \@ids,
	);
}

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub _parse_exif
{
	my( $self, $filepath, %opts ) = @_;

	my $epdata = $opts{epdata};

	my $all_data = {};

	if ($exiftool) {
		my $cmd = $exiftool . " " . $filepath;
		my $ret = `$cmd`;
		my @lines = split(/\n/,$ret);
		foreach my $line(@lines) {
			my @parts = split(/:/,$line,2);
			my $key = trim(@parts[0]);
			my $value = trim(@parts[1]);
			$all_data->{$key} = $value;
		}
	} else {
		my $exif = new Image::EXIF($filepath);

		my $all_info = $exif->get_all_info();

		foreach my $category(keys %$all_info){
			foreach my $item(keys %{$all_info->{$category}}) {
				$all_data->{$item} = $all_info->{$category}->{$item};
			}
		}
	}

	foreach my $item(keys %$all_data) {
		$epdata->{title} = $all_data->{$item} if ($item eq "Title");
		$epdata->{title} = $all_data->{$item} if ($item eq "XP Title");
		$epdata->{keywords} = $all_data->{$item} if ($item eq "Last Keyword XMP");
		$epdata->{keywords} = $all_data->{$item} if ($item eq "XP Keywords");
		$epdata->{creators_name} = $all_data->{$item} if ($item eq "Creator");
		$epdata->{creators_name} = $all_data->{$item} if ($item eq "XP Author");
		$epdata->{abstract} = $all_data->{$item} if ($item eq "Description");
		$epdata->{abstract} = $all_data->{$item} if ($item eq "XP Comment");
	}

	$epdata->{keywords} =~ s/;/,/g;

	$epdata = $self->encode_creators($epdata) if (defined $epdata->{creators_name});

}

sub encode_creators
{
	my ( $self, $epdata ) = @_;

	my $creators = $epdata->{creators_name};

	my @people = split(/,/,$creators);
	if ((scalar @people) < 2) {
		@people = split(/;/,$creators);
	}

	my @names;

	foreach my $person(@people) {
		my @parts = split(/ /,$person);
		my $given = @parts[0];
		my $surname;
		if ((lc($given) eq "mr") || (lc($given) eq "mrs") || (lc($given) eq "miss") || (lc($given) eq "dr") || (lc($given) eq "ms") || (lc($given) eq "doctor") || (lc($given) eq "professor") || (lc($given) eq "sir") || (lc($given) eq "dame")) {
			$given .= ' ' . @parts[1];
			for (my $i=2;$i<@parts;$i++) {
				$surname .= ' ' . @parts[$i]; 
			}
		}
		if (!defined $surname) {
			for (my $i=1;$i<@parts;$i++) {
				$surname .= ' ' . @parts[$i]; 
			}
		}
		$surname = substr($surname,1,length($surname)) if defined $surname;
		push @names, {
			family => $surname,
			given => $given,
		};
	}
	$epdata->{creators_name} = \@names if scalar @names;

	return $epdata;
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

