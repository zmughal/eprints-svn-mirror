######################################################################
#
# EPrints::OpenArchives
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

B<EPrints::OpenArchives> - Methods for open archives support in EPrints.

=head1 DESCRIPTION

This module contains methods used by the EPrints OAI interface. 
See http://www.openarchives.org/ for more information.

=head1 METHODS 

=over 4

=cut

package EPrints::OpenArchives;

use EPrints::Database;
use EPrints::EPrint;
use EPrints::MetaField;
use EPrints::Session;

use strict;


######################################################################
=pod

=item $timestamp = EPrints::OpenArchives::utc_timestamp();

Return a UTC timestamp of the form YYYY-MM-DDTHH:MM:SSZ

e.g. 2005-02-12T09:23:33Z

=cut
######################################################################

sub utc_timestamp
{
	my( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) 
		= gmtime();

	return sprintf( "%04d-%02d-%02dT%02d:%02d:%02dZ", 
			$year+1900, $mon+1, $mday, 
			$hour, $min, $sec );
}



######################################################################
=pod

=item EPrints::OpenArchives::full_timestamp()

DEPRECATED, as we no longer support OAI v1.

Return a full timestamp of the form YYYY-MM-DDTHH:MM:SS[GMT-delta]

Used by OAI v1

e.g. 2000-05-01T15:32:23+01:00

=cut
######################################################################

sub full_timestamp
{
	my $time = time;
	my @date = localtime( $time );

	my $day = $date[3];
	my $month = $date[4]+1;
	my $year = $date[5]+1900;
	my $hour = $date[2];
	my $min = $date[1];
	my $sec = $date[0];
	
	# Ensure number of digits
	while( length $day < 2 )   { $day   = "0".$day; }
	while( length $month < 2 )	{ $month = "0".$month; }
	while( length $hour < 2 )  { $hour  = "0".$hour; }
	while( length $min < 2 )	{ $min   = "0".$min; }
	while( length $sec < 2 )   { $sec   = "0".$sec; }

	# Find difference between gmt and local time zone
	my @gmtime = gmtime( $time );

	# Offset in minutes
	my $offset = $date[1] - $gmtime[1] + ( $date[2] - $gmtime[2] ) * 60;
	
	# Ensure no boundary crossed by checking day of the year...
	if( $date[7] == $gmtime[7]+1 )
	{
		# Next day
		$offset += 1440;
	}
	elsif( $date[7] == $gmtime[7]+1 )
	{
		# Previous day
		$offset -= 1440;
	}
	elsif( $date[7] < $gmtime[7] )
	{
		# Crossed year boundary
		$offset +=1440
	}
	elsif( $date[7] > $gmtime[7] )
	{
		# Crossed year boundary
		$offset -=1440;
	}
	
	# Work out in hours and minutes
	my $unsigned_offset = ( $offset < 0 ? -$offset : $offset );
	my $minutes_offset = $unsigned_offset % 60;
	my $hours_offset = ( $unsigned_offset-$minutes_offset ) / 60;
	
	while( length $hours_offset < 2 )  { $hours_offset = "0".$hours_offset; }
	while( length $minutes_offset < 2 )
	{
		$minutes_offset = "0".$minutes_offset;
	}

	# Return full timestamp
	return( "$year-$month-$day"."T$hour:$min:$sec".
		( $offset < 0 ? "-" : "+" ) . "$hours_offset:$minutes_offset" );
}


######################################################################
=pod

=item $xml = EPrints::OpenArchives::make_header( $session, $eprint, $oai2 )

Return a DOM tree containing the generic <header> part of a OAI response
describing an EPrint. 

Return the OAI2 version if $oai2 is true.

=cut
######################################################################

sub make_header
{
	my ( $session, $eprint, $oai2 ) = @_;

	my $header = $session->make_element( "header" );
	my $oai_id;
	if( $oai2 )
	{
		$oai_id = $session->get_archive()->get_conf( 
			"oai", 
			"v2", 
			"archive_id" );
	}
	else
	{
		$oai_id = $session->get_archive()->get_conf( 
			"oai", 
			"archive_id" );
	}
	
	$header->appendChild( $session->render_data_element(
		6,
		"identifier",
		EPrints::OpenArchives::to_oai_identifier(
			$oai_id,
			$eprint->get_value( "eprintid" ) ) ) );

	my $datestamp = $eprint->get_value( "datestamp" );
	unless( EPrints::Utils::is_set( $datestamp ) )
	{
		# is this a good default?
		$datestamp = '0001-01-01';
	}
	$header->appendChild( $session->render_data_element(
		6,
		"datestamp",
		$datestamp ) );

	if( EPrints::Utils::is_set( $oai2 ) )
	{
		if( $eprint->get_dataset()->id() eq "deletion" )
		{
			$header->setAttribute( "status" , "deleted" );
			return $header;
		}

		my $viewconf = $session->get_archive()->get_conf( "oai","sets" );
        	foreach my $info ( @{$viewconf} )
        	{
			my @values = $eprint->get_values( $info->{fields} );
			my $afield = EPrints::Utils::field_from_config_string( 
					$eprint->get_dataset(), 
					( split( "/" , $info->{fields} ) )[0] );

			foreach my $v ( @values )
			{
				if( $v eq "" && !$info->{allow_null} ) { next;  }

				my @l;
				if( $afield->is_type( "subject" ) )
				{
					my $subj = new EPrints::Subject( $session, $v );
					next unless( defined $subj );
	
					my @paths = $subj->get_paths( 
						$session, 
						$afield->get_property( "top" ) );

					foreach my $path ( @paths )
					{
						my @ids;
						foreach( @{$path} ) 
						{
							push @ids, $_->get_id();
						}
						push @l, encode_setspec( @ids );
					}
				}
				else
				{
					@l = ( encode_setspec( $v ) );
				}

				foreach( @l )
				{
					$header->appendChild( $session->render_data_element(
						6,
						"setSpec",
						encode_setspec( $info->{id}.'=' ).$_ ) );
				}
			}
		}
	}

	return $header;
}


######################################################################
=pod

=item $xml = EPrints::OpenArchives::make_record( $session, $eprint, $fn, $oai2 )

Return XML DOM describing the entire OAI <record> for a single eprint.

If $oai2 is true return the XML suitable for OAI v2.0

$fn is a pointer to a function which takes ( $eprint, $session ) and
returns an XML DOM tree describing the metadata in the desired format.

=cut
######################################################################

sub make_record
{
	my( $session, $eprint, $fn, $oai2 ) = @_;

	my $record = $session->make_element( "record" );

	my $header = make_header( $session, $eprint, $oai2 );
	$record->appendChild( $session->make_indent( 4 ) );
	$record->appendChild( $header );

	if( $eprint->get_dataset()->id() eq "deletion" )
	{
		unless( EPrints::Utils::is_set( $oai2 ) )
		{
			$record->setAttribute( "status" , "deleted" );
		}
		return $record;
	}

	my $md = &{$fn}( $eprint, $session );
	if( defined $md )
	{
		my $metadata = $session->make_element( "metadata" );
		$metadata->appendChild( $session->make_indent( 6 ) );
		$metadata->appendChild( $md );
		$record->appendChild( $session->make_indent( 4 ) );
		$record->appendChild( $metadata );
	}

	return $record;
}


######################################################################
=pod

=item $oai_id EPrints::OpenArchives::to_oai_identifier( $archive_id, $eprintid )

Give the full OAI identifier of an eprint, given the local eprint id.

$archive_id is the ID used for OAI, which may be different from that
used by EPrints.

=cut
######################################################################

sub to_oai_identifier
{
	my( $archive_id , $eprintid ) = @_;
	
	return( "oai:$archive_id:$eprintid" );
}


######################################################################
=pod

=item $eprintid = EPrints::OpenArchives::from_oai_identifier( $session, $oai_identifier )

Return the local eprint id of an oai eprint identifier.

Return undef if this does not match a possible eprint.

This does not check the eprint actually exists, just that the OAI
identifier is suitable.

=cut
######################################################################

sub from_oai_identifier
{
        my( $session , $oai_identifier ) = @_;
        my $arcid = $session->get_archive()->get_conf( "oai", "archive_id" );
        my $arcid2 = $session->get_archive()->get_conf( "oai", "v2", "archive_id" );
        if( $oai_identifier =~ /^oai:($arcid|$arcid2):(\d+)$/ )
        {
                return( $2 );
        }
        else
        {
                return( undef );
        }
}



######################################################################
=pod

=item $encoded = EPrints::OpenArchives::encode_setspec( @bits )

This encodes a list of values in such a way that it is a legal 
OAI setspec, even if it contains non-ascii characters etc.

=cut
######################################################################

sub encode_setspec
{
	my( @bits ) = @_;
	foreach( @bits ) { $_ = text2bytestring( $_ ); }
	return join(":",@bits);
}


######################################################################
=pod

=item @decoded = EPrints::OpenArchives::decode_setspec( $encoded )

This decodes a list of parameters encoded by encode_setspec

=cut
######################################################################

sub decode_setspec
{
	my( $encoded ) = @_;
	my @bits = split( ":", $encoded );
	foreach( @bits ) { $_ = bytestring2text( $_ ); }
	return @bits;
}


######################################################################
=pod

=item $encoded = EPrints::OpenArchives::text2bytestring( $string )

Converts a string into hex. eg. "A" becomes "41".

=cut
######################################################################

sub text2bytestring
{
	my( $string ) = @_;
	my $encstring = "";
	for(my $i=0; $i<length($string); $i++)
	{
		$encstring.=sprintf("%02X", ord(substr($string, $i, 1)));
	}
	return $encstring;
}


######################################################################
=pod

=item $decoded = EPrints::OpenArchives::bytestring2text( $encstring )

Does the reverse of text2bytestring.

=cut
######################################################################

sub bytestring2text
{
	my( $encstring ) = @_;

	my $string = "";
	for(my $i=0; $i<length($encstring); $i+=2)
	{
		$string.=pack("H*",substr($encstring,$i,2));
	}
	return $string;
}


1;


######################################################################
=pod

=back

=cut

