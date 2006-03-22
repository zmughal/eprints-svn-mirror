
=pod

=head1 FILE FORMAT

From L<Text::Refer>:

The bibliographic database is a text file consisting of records separated by one or more blank lines. Within each record fields start with a % at the beginning of a line. Each field has a one character name that immediately follows the %. The name of the field should be followed by exactly one space, and then by the contents of the field.

=head2 Supported Fields

EPrints mappings shown in B<bold>,

=over 8

=item 0 (the digit zero) Citation Type. Supported types:

=over 8

=item Book B<book>

=item Book Section B<book_section>

=item Conference Paper B<conference_item>

=item Conference Proceedings B<book>

=item Edited Book B<book>

=item Electronic Article B<article>

=item Electronic Book B<book>

=item Journal Article B<article>

=item Magazine Article B<article>

=item Newspaper Article B<article>

=item Patent B<patent>

=item Report B<monograph>

=item Thesis B<thesis>

=back

B<NOTE:> For the Conference Paper type, the C<pres_type> field is set to C<paper>.

=item D 

Year B<date_issue>

=item J 

Journal (Journal Article only) B<publication>

=item K 

Keywords B<keywords>

=item T 

Title B<title>

=item U 

URL B<official_url>

=item X 

Abstract B<abstract>

=item Z 

Notes B<note>

B<NOTE:> Use of Z field for Image data not supported

=item 9

=over 8

=item Type of Article (Journal Article, Newspaper Article, Magazine Article)

=item Thesis Type (Thesis) B<thesis_type>

=item Report Type (Report) B<monograph_type>

=item Patent Type (Patent)

=item Type of Medium (Electronic Book)

=back

B<NOTE:> You may need to define your own regexps to munge this free text field into the values accepted by B<thesis_type> and B<monograph_type>.

=item A

=over 8

=item Inventor (Patent) B<creators>

=item Editor (Edited Book) B<editors>

=item Reporter (Newspaper Article) B<creators>

=item Author (Other Types) B<creators>

=back

B<FORMAT:> Lastname, Firstname, Lineage

=item B

=over 8

=item Series Title (Edited Book, Book, Report) B<series>

=item Academic Department (Thesis) B<department>

=item Newspaper (Newspaper Article) B<publication>

=item Magazine (Magazine Article) B<publication>

=item Book Title (Book Section) B<book_title>

=item Conference Name (Conference Paper, Conference Proceedings) B<event_title>

=item Periodical Title (Electronic Article) B<publication>

=item Secondary Title (Electronic Book)

=back

=item C

=over 8

=item Country (Patent)

=item Conference Location (Conference Paper, Conference Proceedings) B<event_location>

=item City (Other Types) B<place_of_pub>

=back

=item E

=over 8

=item Series Editor (Report, Book, Edited Book)

=item Issuing Organisation (Patent) B<institution>

=item Editor (Other Types) B<editors>

=back

B<FORMAT:> Lastname, Firstname, Lineage

=item I

=over 8

=item University (Thesis) B<institution>

=item Institution (Report) B<institution>

=item Assignee (Patent)

=item Publisher (Other Types) B<publisher>

=back

=item N

=over 8

=item Application Number (Patent)

=item Issue (Other Types) B<number>

=back

=item P

=over 8

=item Number of Pages (Book, Thesis, Edited Book) B<pages>

=item Pages (Other Types) B<pagerange>

=back

=item S 

=over 8

=item Series Title (Book Section, Conference Proceedings) B<series>

=item International Author (Patent)

=back

=item V

=over 8

=item Degree (Thesis)

=item Patent Version Number (Patent)

=item Volume (Other Types) B<volume>

=back

=item @

=over 8

=item ISSN (Journal Article, Newspaper Article, Magazine Article, Electronic Article) B<issn>

=item ISBN (Book, Book Section, Edited Book, Conference Proceedings, Electronic Book) B<isbn>

=item Report Number (Report) B<id_number>

=item Patent Number (Patent) B<id_number>

=back

=back

=head2 Unsupported Fields

=over 8

=item 2 

Issue Date (Patent)

=item 3 

Designated States (Patent)

=item 4 

Attorney/Agent (Patent)

=item 6 

Number of Volumes

=item 7 

International Patent Classification (Patent), Edition (Other Types)

=item 8

Date Accessed (Electronic Article, Electronic Book), Date (Other Types)

=item F

Label

=item G

Language

=item H

Translated Author

=item L

Call Number

=item M

Accession Number

=item O

Alternate Journal (Journal Article), Alternate Magazine (Magazine Article), Alternate Title (Other Types)

=item Q

Translated Title

=item R

Electronic Resource Number

=item W

Database Provider

=item Y

Advisor (Thesis), Series Editor (Book Section, Conference Proceedings), International Title (Patent)

=item [

Access Date

=item +

Inventor Address (Patent), Author Address

=item ^

Caption

=item =

Last Modified Date

=item $

Legal Status (Patent)

=item >

Link to PDF

=item ~

Name of Database

=item (

Priority Number (Patent), Original Publication (Other Types)

=item )

Reprint Edition

=item <

Research Notes

=item *

Reviewed Item

=item &

Section (Newspaper Article), International Patent Number (Patent)

=item !

Short Title

=item #

References (Patent)

=item ?

Sponsor (Conference Proceedings), Translator (Other Types)

=back

=head1 SEE ALSO

L<Text::Refer>, L<XML::Writer>, L<EPrints::Plugin::Output::EndNote>

=cut

package EPrints::Plugin::Input::EndNote;

use strict;

our @ISA = qw/ EPrints::Plugin::Input /;

sub new
{
	my( $class, %params ) = @_;

	my $rc = eval( "use Text::Refer;" );
	unless( $rc ) 
	{
		print STDERR "Failed to load Text::Refer. Disabling Endnote Import plugin.\n";
		return undef;
	}
	$rc = eval( "use File::Temp qw( tempfile );" );
	unless( $rc ) 
	{
		print STDERR "Failed to load File::Temp. Disabling Endnote Import plugin.\n";
		return undef;
	}

	my $self = $class->SUPER::new( %params );

	$self->{name} = "EndNote";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint', 'dataobj/eprint' ];

	return $self;
}

# TODO sort out warnings
# TODO creators and editors need main
# TODO type keeps getting changed to article?!

# parse a file of records.
# return an EPrints::List of the imported items.
sub input_list
{
	my( $plugin, %opts ) = @_;

	my $parser = new Text::Refer::Parser(
		LeadWhite=> "KILLALL", 
		Newline => "TOSPACE",
		ForgiveEOF => 1
	);

	#my $list = EPrints::List->new;

	#TODO: need temp file
	my ( $fh, $filename ) = tempfile( DIR => '/tmp' );
	print $fh $opts{ data };
	close $fh;

	open( IN, $filename );

	my @ids;
	while (my $ref = $parser->input( *IN ) ) {
		my $data = $plugin->ref_to_data( $ref );
		if( defined $data )
		{
			use Data::Dumper;
			print Dumper( $data );
			my $dataobj = $plugin->data_to_dataobj( $opts{dataset}, $data );
			if( defined $dataobj )
			{
				push @ids, $dataobj->get_id;
			}
		}
	}
	
	close( IN );

	return EPrints::List->new( 
		dataset => $opts{dataset}, 
		session => $plugin->{session},
		ids=>\@ids );
}

sub ref_to_data {
	my ( $plugin, $ref ) = @_;
	my $data = ();

	# 0 Citation type
	my $ref_type = $ref->get( "0" ) || "[none]";
	$data->{type} = "article" if $ref_type =~ /Article/;
	$data->{type} = "book" if $ref_type =~ /Book/ || $ref_type eq "Conference Proceedings";
	$data->{type} = "book_section" if $ref_type eq "Book Section";
	if( $ref_type eq "Conference Paper" )
	{
		$data->{type} = "conference_item";
		$data->{pres_type} = "paper";
	}
	$data->{type} = "monograph" if $ref_type eq "Report";
	$data->{type} = "patent" if $ref_type eq "Patent";
	$data->{type} = "thesis" if $ref_type eq "Thesis";
	if( !defined $data->{type} ) {
		$plugin->warning( "Skipping unsupported citation type $ref_type" );
		return undef;
	}

	# D Year
	$data->{date_issue} = $ref->date if defined $ref->date;
	# J Journal
	$data->{publication} = $ref->journal if defined $ref->journal && $ref_type eq "Journal Article";
	# K Keywords
	$data->{keywords} = $ref->keywords if defined $ref->keywords;
	# T Title
	$data->{title} = $ref->title if defined $ref->title;
	# U URL
	$data->{official_url} = $ref->get( "U" ) if defined $ref->get( "U" );
	# X Abstract
	$data->{abstract} = $ref->abstract if defined $ref->abstract;
	# Z Notes
	$data->{note} = $ref->get( "Z" ) if defined $ref->get( "Z" );

	# 9 Thesis Type, Report Type
	if( defined $ref->get( "9" ) )
	{

		my $type = $ref->get( "9" );
		if( $ref_type eq "Thesis" )
		{
			$data->{thesis_type} = "phd" if $type =~ /ph\.?d/i;
			$data->{thesis_type} = "masters" if $type =~ /master/i;
		}
		elsif( $ref_type eq "Report" )
		{
			$data->{monograph_type} = "technical_report" if $type =~ /tech/i;
			$data->{monograph_type} = "project_report" if $type =~ /proj/i;
			$data->{monograph_type} = "documentation" if $type =~ /doc/i;
			$data->{monograph_type} = "manual" if $type =~ /manual/i;
		}
	}

	# A Editor (Edited Book), Author (Other Types)
	for ( $ref->author )
	{
		# Author's names should be in Lastname, Firstname format
		if( /^(.*?),(.*?)(,(.*?))?$/ )
		{
			if( $ref_type eq "Edited Book" )
			{
				push @{$data->{editors}}, { family => $1, given => $2, lineage => $4 };
			}
			else
			{
				push @{$data->{creators}}, { family => $1, given => $2, lineage => $4 };
			}
		} else {
			output_warning($ref, "Could not parse author: $_");
		}
	}

	# B Conference Name, Department (Thesis), Newspaper, Magazine, Series (Book, Edited Book, Report), Book Title (Book Section)
	if( defined $ref->book )
	{
		if( $ref_type eq "Conference Paper" || $ref_type eq "Conference Proceedings" )
		{
			$data->{event_title} = $ref->book;
		}
		elsif( $ref_type eq "Thesis" )
		{
			$data->{department} = $ref->book;
		}
		elsif( $ref_type eq "Newspaper Article" || $ref_type eq "Magazine Article" || $ref_type eq "Electronic Article" )
		{
			$data->{publication} = $ref->book;
		}
		elsif( $ref_type eq "Book" || $ref_type eq "Edited Book" || $ref_type eq "Report" )
		{
			$data->{series} = $ref->book;
		}
		elsif( $ref_type eq "Book Section" ) 
		{
			$data->{book_title} = $ref->book;
		}
	}

	# C Conference Location, Country (Patent), City (Other Types)
	if( defined $ref->city )
	{
		if( $ref_type eq "Conference Paper" || $ref_type eq "Conference Proceedings" )
		{
			$data->{event_location} = $ref->city;
		}
		elsif( $ref_type eq "Patent" )
		{
			# Unsupported
		}
		else
		{
			$data->{place_of_pub} = $ref->city;
		}
	}

	# E Issuing Organisation (Patent), Series Editor (Book, Edited Book, Report), Editor (Other Types)
	for ( $ref->editor )
	{
		if( $ref_type eq "Patent" ) {
			$data->{institution} = $_;
		}
		# Editor's names should be in Lastname, Firstname format
		elsif( /^(.*?),(.*?)(,(.*?))?$/ )
		{
			if( $ref_type eq "Book" || $ref_type eq "Edited Book" || $ref_type eq "Report" )
			{
				# Unsupported
			}
			else
			{
				push @{$data->{editors}}, { family => $1, given => $2, lineage => $4 };
			}
		} else {
			output_warning($ref, "Could not parse editor: $_");
		}
	}

	# I Institution (Report), University (Thesis), Assignee (Patent), Publisher (Other Types)
	if( defined $ref->publisher )
	{
		if( $ref_type eq "Report" || $ref_type eq "Thesis" )
		{
			$data->{institution} = $ref->publisher;
		}
		elsif( $ref_type eq "Patent" )
		{
			# Unsupported
		}
		else
		{
			$data->{publisher} = $ref->publisher;
		}
	}

	# N Application Number (Patent), Issue (Other Types)
	if( defined $ref->number )
	{
		if( $ref_type eq "Patent" )
		{
			# Unsupported
		}
		else
		{
			$data->{number} = $ref->number;
		}
	}

	# P Number of Pages (Book, Edited Book, Thesis), Pages (Other Types)
	if( defined $ref->page )
	{
		if( $ref_type eq "Book" || $ref_type eq "Edited Book" || $ref_type eq "Thesis" )
		{
			$data->{pages} = $ref->page;
		}
		else
		{
			$data->{pagerange} = $ref->page;
		}
	}

	# S Series (Book Section, Conference Proceedings)
	if( defined $ref->series )
	{
		if( $ref_type eq "Book Section" || $ref_type eq "Conference Proceedings" )
		{
			$data->{series} = $ref->series;
		}
	}

	# V Patent Version Number, Degree (Thesis), Volume (Other Types) 
	if( defined $ref->volume )
	{
		if( $ref_type eq "Patent" ) 
		{
			# Unsupported
		}
		elsif( $ref_type eq "Thesis" )
		{
			# Unsupported
		}
		else
		{
			$data->{volume} = $ref->volume;
		}
	}

	# @ ISSN (Journal Article, Newspaper Article, Magazine Article), 
	#   Patent Number, Report Number, 
	#   ISBN (Book, Edited Book, Book Section, Conference Proceedings)
	if( defined $ref->get( "@" ) )
	{
		if( $ref_type =~ /Article/ )
		{
			$data->{issn} = $ref->get( "@" );
		}
		elsif( $ref_type eq "Patent" || $ref_type eq "Report" )
		{
			$data->{id_number} = $ref->get( "@" );
		}
		elsif( $ref_type =~ /Book/ || $ref_type eq "Conference Proceedings" )
		{
			$data->{isbn} = $ref->get( "@" );
		}
	}

	return $data;
}

1;
