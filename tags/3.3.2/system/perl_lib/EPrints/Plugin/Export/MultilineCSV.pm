=head1 NAME

EPrints::Plugin::Export::MultilineCSV

=cut

package EPrints::Plugin::Export::MultilineCSV;

use EPrints::Plugin::Export;
use EPrints::Plugin::Export::Grid;

@ISA = ( "EPrints::Plugin::Export::Grid" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Multiline CSV";
	$self->{accept} = [ 'dataobj/eprint', 'list/eprint', ];
	$self->{visible} = "staff";
	$self->{suffix} = ".csv";
	$self->{mimetype} = "text/csv";
	
	return $self;
}


sub output_list
{
	my( $plugin, %opts ) = @_;

	my $part = csv( $plugin->header_row( %opts ) );

	my $r = [];

	binmode( $opts{fh}, ":utf8" );

	if( defined $opts{fh} )
	{
		print {$opts{fh}} $part;
	}
	else
	{
		push @{$r}, $part;
	}

	# list of things

	$opts{list}->map( sub {
		my( $session, $dataset, $item ) = @_;

		my $part = $plugin->output_dataobj( $item, %opts );
		if( defined $opts{fh} )
		{
			print {$opts{fh}} $part;
		}
		else
		{
			push @{$r}, $part;
		}
	} );

	return if( defined $opts{fh} );

	return join( '', @{$r} );
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $rows = $plugin->dataobj_to_rows( $dataobj );

	my $r = [];
	for( my $row_n=0;$row_n<scalar @{$rows};++$row_n  )
	{
		my $row = $rows->[$row_n];
		push @{$r}, csv( @{$row} );
	}

	return join( "", @{$r} );
}

sub csv
{
	my( @row ) = @_;

	my @r = ();
	foreach my $item ( @row )
	{
		if( !defined $item )
		{
			push @r, '""';
			next;
		}
		$item =~ s/(["\\])/\\$1/g;
		$item =~ s/\r?\n//g;
		push @r, '"'.$item.'"';
	}
	return join( ",", @r )."\n";
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

