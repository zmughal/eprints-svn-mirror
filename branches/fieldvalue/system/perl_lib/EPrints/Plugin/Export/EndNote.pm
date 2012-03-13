=head1 NAME

EPrints::Plugin::Export::EndNote

=cut

=pod

=head1 FILE FORMAT

See L<EPrints::Plugin::Import::EndNote>

=cut

package EPrints::Plugin::Export::EndNote;

use EPrints::Plugin::Export::TextFile;
use EPrints;

@ISA = ( "EPrints::Plugin::Export::TextFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;
	
	my $self = $class->SUPER::new( %opts );

	$self->{name} = "EndNote";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".enw";

	return $self;
}

sub convert_dataobj
{
	my( $self, $dataobj ) = @_;

	my @data;

	# 0 Citation type
	my $type = $dataobj->get_type;
	if( $type eq "book" && !$dataobj->is_set( "creators" ) && $dataobj->is_set( "editors" ) )
	{
		push @data, [ 0 => "Edited Book" ];
	}
	elsif( $type eq "book" )
	{
		push @data, [ 0 => "Book" ];
	}
	elsif( $type eq "book_section" )
	{
		push @data, [ 0 => "Book Section" ];
	}
	elsif( $type eq "conference_item" )
	{
		push @data, [ 0 => "Conference Paper" ];
	}
	elsif( $type eq "article" )
	{
		push @data, [ 0 => "Journal Article" ];
	}
	elsif( $type eq "patent" )
	{
		push @data, [ 0 => "Patent" ];
	}
	elsif( $type eq "monograph" )
	{
		push @data, [ 0 => "Report" ];
	}
	elsif( $type eq "thesis" )
	{
		push @data, [ 0 => "Thesis" ];
	}
	else
	{
		push @data, [ 0 => "Generic" ];
	}

	# D Year
	if( $dataobj->exists_and_set( "date" ) )
	{
		push @data, [ D => $dataobj->field_value( "date" )->year ];
	}
	# J Journal
	if( $type eq "article" && $dataobj->exists_and_set( "publication" ) )
	{
		push @data, [ J => $dataobj->field_value( "publication" ) ];
	}
	# K Keywords
	push @data, $self->simple_value( $dataobj, keywords => "K" );
	# T Title
	push @data, $self->simple_value( $dataobj, title => "T" );
	# U URL
	push @data, [ U => $dataobj->get_url ];
	# X Abstract
	push @data, $self->simple_value( $dataobj, abstract => "X" );
	# Z Notes
	push @data, $self->simple_value( $dataobj, note => "Z" );
	# 9 Thesis Type, Report Type
	if( $dataobj->exists_and_set( "thesis_type" ) )
	{
		push @data, [ 9 => $dataobj->field_value( "thesis_type" ) ];
	}
	elsif( $dataobj->exists_and_set( "monograph_type" ) )
	{
		push @data, [ 9 => $dataobj->field_value( "monograph_type" ) ];
	}

	# A Author	
	push @data, $self->simple_value( $dataobj, creators_name => "A" );

	# A Corporate Author - a trailing comma MUST be added, see EndNote documentation
	my $ds = $dataobj->get_dataset;
	if( $dataobj->exists_and_set( 'corp_creators' ) )
	{
		foreach my $item (@{$dataobj->field_value( "corp_creators" )})
		{
			push @data, [ A => $item."," ];
		}
	}	

	# B Conference Name, Department (Thesis), Series (Book, Report), Book Title (Book Section)
	if( $type eq "conference_item")
	{
		push @data, $self->simple_value( $dataobj, event_title => "B" );
	}
	elsif( $type eq "thesis" )
	{
		push @data, $self->simple_value( $dataobj, department => "B" );
	}
	elsif( $type eq "book" || $type eq "monograph" )
	{
		push @data, $self->simple_value( $dataobj, series => "B" );
	}
	elsif( $type eq "book_section" )
	{
		push @data, $self->simple_value( $dataobj, book_title => "B" );
	}

	# C Conference Location, Country (Patent), City (Other Types)
	if( $type eq "conference_item")
	{
		push @data, $self->simple_value( $dataobj, event_location => "C" );
	}
	elsif( $type eq "patent" )
	{
		# Unsupported
	}
	else
	{
		push @data, $self->simple_value( $dataobj, place_of_pub => "C" );
	}

	# E Issuing Organisation (Patent), Editor (Other Types)
	if( $type eq "patent")
	{
		push @data, $self->simple_value( $dataobj, institution => "E" );
	}
	elsif( $dataobj->exists_and_set( "editors" ) )
	{
		push @data, $self->simple_value( $dataobj, editors_name => "E" );
	}

	# I Institution (Report), University (Thesis), Assignee (Patent), Publisher (Other Types)
	if( $type eq "monograph" || $type eq "thesis" )
	{
		push @data, $self->simple_value( $dataobj, institution => "I" );
	}
	elsif( $type eq "patent" )
	{
		# Unsupported
	}
	else
	{
		push @data, $self->simple_value( $dataobj, publisher => "I" );
	}

	# N Application Number (Patent), Issue (Other Types)
	if( $type eq "patent" )
	{
		# Unsupported
	}
	else
	{
		push @data, $self->simple_value( $dataobj, number => "N" );
	}	

	# P Number of Pages (Book, Thesis), Pages (Other Types)
	if( $type eq "book" || $type eq "thesis" )
	{
		push @data, $self->simple_value( $dataobj, pages => "P" );
	}
	else
	{
		push @data, $self->simple_value( $dataobj, pagerange => "P" );
	}

	# S Series (Book Section)
	if( $type eq "book_section" )
	{
		push @data, $self->simple_value( $dataobj, series => "S" );
	}

	# V Patent Version Number, Degree (Thesis), Volume (Other Types)
	if( $type eq "patent" )
	{
		# Unsupported
	}
	elsif( $type eq "thesis" )
	{
		# Unsupported
	}
	else
	{
		push @data, $self->simple_value( $dataobj, volume => "V" );
	}

	# @ ISSN (Article), Patent Number, Report Number, ISBN (Book, Book Section)
	if( $type eq "article" )
	{
		push @data, $self->simple_value( $dataobj, issn => "@" );
	}
	elsif( $type eq "patent" || $type eq "monograph" )
	{
		push @data, $self->simple_value( $dataobj, id_number => "@" );
	}
	elsif( $type eq "book" || $type eq "book_section" )
	{
		push @data, $self->simple_value( $dataobj, isbn => "@" );
	}

	# F Label
	push @data, [ F => $self->{session}->get_id . ":" . $dataobj->id ];

	return \@data;
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj );

	my $out = "";
	foreach(@$data)
	{
		my( $k, $v ) = @$_;

		$v =~ s/[\r\n]/ /g;
		$out .= "\%$k $v\n";
	}
	$out .= "\n";

	return $out;
}

sub simple_value
{
	my( $self, $eprint, $fieldid, $term ) = @_;

	return if !$eprint->exists_and_set( $fieldid );

	return map { [ $term, $_ ] } @{$eprint->field_value( $fieldid )};
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

