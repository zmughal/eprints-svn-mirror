######################################################################
#
# EPrints::Probity
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=head1 NAME

B<EPrints::Probity> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{foo}
#     undefined
#
######################################################################

######################################################################
#
#  EPrints Probity module
#
#   Provides functions for logging checksums of documents
#
######################################################################
#
#  __LICENSE__
#
######################################################################

package EPrints::Probity;
use strict;
use File::Path;
use URI;
use Carp;
use Digest::MD5;

use EPrints::XML;
use EPrints::Utils;
use EPrints::Session;


######################################################################
=pod

=item $xml = EPrints::Probity::process_file( $filename, [$name] );

Process the given file and return an XML chunk in the format. 

 <hash>
    <name>/opt/eprints2/documents/disk0/00/00/05/04/02/stuff.pdf</name>
    <algorithm>SHA-1</algorithm>
    <value>cc7a32915ab0a73ba1f94b34d3a265bdccd3c8b9</value>
    <date>Fri Sep 27 10:53:10 BST 2002</date>
 </hash>

If $name is not specified then the name is $filename.

If there is a problem return a empty XML document fragment.

=cut
######################################################################

sub process_file
{
	my( $filename, $name ) = trim_params(@_);

	$name = $filename unless defined $name;

	my( $value, $alg ) = _md5( $filename );

	unless( defined $alg )
	{
		&ARCHIVE->log( 
"EPrints::Probity: Failed to create hash for '$filename'" );
		return &SESSION->make_doc_fragment;
	}

	my $hash = &SESSION->make_element( "hash" );
	$hash->appendChild( &SESSION->render_data_element( 6, "name", $name ) );
	$hash->appendChild( &SESSION->render_data_element( 6, "algorithm", $alg ) );
	$hash->appendChild( &SESSION->render_data_element( 6, "value", $value ) );
	$hash->appendChild( &SESSION->render_data_element( 6, "date", EPrints::Utils::get_timestamp() ) );

	return $hash;
}

sub _md5
{
	my( $filename ) = @_;

	my $md5 = Digest::MD5->new;
	if( open( FILE, $filename ) )
	{
		binmode FILE;
		$md5->addfile( *FILE );
		close FILE;
	}
	else
	{
		&ARCHIVE->log( "Error opening '$filename' to create hash: $!" );
		return undef;
	}
	my $value = $md5->hexdigest;

	return( $value, "MD5" );
}


######################################################################
=pod

=item $xml = EPrints::Probity::create_log( $filenames, [$outfile] )

Create an XML file $outfile of the format:

 <?xml version="1.0" encoding="UTF-8"?>
 <hashlist xmlns="http://probity.org/XMLprobity">
    <hash>
       <name>/opt/eprints2/documents/disk0/00/00/05/04/02/stuff.pdf</name>
       <algorithm>SHA-1</algorithm>
       <value>cc7a32915ab0a73ba1f94b34d3a265bdccd3c8b9</value>
       <date>Fri Sep 27 10:53:10 BST 2002</date>
    </hash>
    .
    .
    .

From the filenames in array ref $filenames.

If $outfile is not specified then the XML is sent to STDOUT.

=cut
######################################################################

sub create_log
{
	my( $filenames, $outfile ) = trim_params(@_);

	my $hashlist = &SESSION->make_element( 
		"hashlist", 
		xmlns=>"http://probity.org/XMLprobity" );
	foreach my $filename ( @{$filenames} )
	{
		$hashlist->appendChild( &SESSION->make_indent( 3 ) );
		$hashlist->appendChild( process_file( $filename ) );
	}

	if( defined $outfile )
	{
		if( open( FILE, ">$outfile" ) )
		{
			print FILE '<?xml version="1.0" encoding="UTF-8" ?>'."\n";
			print FILE $hashlist->toString."\n";
			close FILE;
		}
		else
		{
			&ARCHIVE->log(
"Error opening '$outfile' to write log: $!" );
		}
	}
	else
	{
		print '<?xml version="1.0" encoding="UTF-8" ?>'."\n";
		print $hashlist->toString."\n";
	}
	EPrints::XML::dispose( $hashlist );
}
	

1;

######################################################################
=pod

=back

=cut
