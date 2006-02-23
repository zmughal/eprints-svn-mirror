package EPrints::Plugin::Output::METS;

=head1 NAME

Output module for the METS format (version 1.5)

=head1 SEE ALSO

L<http://www.loc.gov/standards/mets/>

=cut

# eprint needs magic documents field

# documents needs magic files field

use Unicode::String qw( utf8 );

use EPrints::Plugin::Output;
use Carp;

@ISA = ( "EPrints::Plugin::Output" );

use strict;

# The utf8() method is called to ensure that
# any broken characters are removed. There should
# not be any broken characters, but better to be
# sure.

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "METS";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "text/xml";

	$self->{xmlns} = "http://www.loc.gov/METS/";
	$self->{schemaLocation} = "http://www.loc.gov/standards/mets/mets.xsd";

	return $self;
}



sub xml_dataobj
{
	my( $plugin, $obj ) = @_;

	if( $obj->isa("EPrints::EPrint") )
	{
		return _eprint($plugin, $obj);
	}
	# Support for EPrints::Document

	croak("Unsupported object type [".ref($obj)."]");
}

sub _eprint
{
	my( $self, $eprint ) = @_;
	my $session = $self->{ "session" };

	my $mets = $session->make_element(
		"mets:mets",
		"xmlns:mets"=>$self->{ "xmlns" },
		"xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
		"xmlns:xlink"=>"http://www.w3.org/1999/xlink",
		"xsi:schemaLocation"=>$self->{ "xmlns" } . " " . $self->{ "schemaLocation" }
	);

	my $file_sec = $session->make_element( "mets:fileSec" );
	$mets->appendChild( $file_sec );
	my $struct_map = $session->make_element( "mets:structMap" );
	$mets->appendChild( $struct_map );
	$struct_map->setAttribute( "TYPE", "PHYSICAL" );
	$struct_map->setAttribute( "LABEL", "Documents and Files" );

	foreach my $doc ( $eprint->get_all_documents )
	{
		my $file_grp = $session->make_element( "mets:fileGrp" );
		$file_sec->appendChild( $file_grp );

		my $div_files = $session->make_element( "mets:div" );
		$struct_map->appendChild( $div_files );
		$div_files->setAttribute( "TYPE", "document" );
		
		my $fptr = $session->make_element( "mets:fptr" );
		$div_files->appendChild( $fptr );
		
		$file_grp->setAttribute( "ID", $doc->get_value( "docid" ) );
		$fptr->setAttribute( "FILEID", $doc->get_value( "docid" ) );

		my %files = $doc->files;
		my $i = 0;
		while( my( $fn, $size ) = each %files )
		{
			my $file = $session->make_element( "mets:file" );
			$file_grp->appendChild( $file );

			if( $fn eq $doc->get_main )
			{
				$file->setAttribute( "USE", "preferred" );
			}

			$file->setAttribute( "SIZE", $size );
			$file->setAttribute( "SEQ", $i++ );

			my $flocat = $session->make_element( "mets:FLocat",
				"LOCTYPE" => "URL",
				"xlink:type" => "simple",
				"xlink:href" => $doc->get_baseurl . $fn
			);
			$file->appendChild( $flocat );
		}
	}

	return $mets;
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $xml = $plugin->xml_dataobj( $dataobj );

	return EPrints::XML::to_string( $xml );
}


1;
