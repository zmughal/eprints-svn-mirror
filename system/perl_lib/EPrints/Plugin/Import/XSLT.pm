package EPrints::Plugin::Import::XSLT;

use EPrints::Plugin::Import;

@ISA = ( "EPrints::Plugin::Import" );

use strict;

sub input_fh
{
	my( $self, %opts ) = @_;

	my $fh = $opts{fh};
	my $session = $self->{session};

	my $dataset = $opts{dataset};
	my $class = $dataset->get_object_class;
	my $root_name = $dataset->base_id;

	# read the source XML
	# note: LibXSLT will only work with LibXML, so that's what we use here
	my $source = XML::LibXML->new->parse_fh( $fh );

	# transform it using our stylesheet
	my $result = $self->transform( $source );

	my @ids;

	my $root = $result->documentElement;

	foreach my $node ($root->getElementsByTagName( $root_name ))
	{
		my $epdata = $class->xml_to_epdata( $session, $node );
		my $dataobj = $self->epdata_to_dataobj( $dataset, $epdata );
		next if !defined $dataobj;
		push @ids, $dataobj->id;
	}

	$session->xml->dispose( $source );
	$session->xml->dispose( $result );

	return EPrints::List->new(
		session => $session,
		dataset => $dataset,
		ids => \@ids );
}

sub transform
{
	my( $self, $doc ) = @_;

	return $self->{stylesheet}->transform( $doc );
}

1;
