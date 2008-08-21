package Net::HoneyComb;

use 5.008008;
use strict;
use warnings;
use Carp;

require Exporter;
use AutoLoader;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Net::HoneyComb ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	HC_BINARY_TYPE
	HC_BOGUS_TYPE
	HC_BYTE_TYPE
	HC_CHAR_TYPE
	HC_DATE_TYPE
	HC_DOUBLE_TYPE
	HC_EMPTY_VALUE_INIT
	HC_LONG_TYPE
	HC_OBJECTID_TYPE
	HC_STRING_TYPE
	HC_TIMESTAMP_TYPE
	HC_TIME_TYPE
	HC_UNKNOWN_TYPE
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	HC_BINARY_TYPE
	HC_BOGUS_TYPE
	HC_BYTE_TYPE
	HC_CHAR_TYPE
	HC_DATE_TYPE
	HC_DOUBLE_TYPE
	HC_EMPTY_VALUE_INIT
	HC_LONG_TYPE
	HC_OBJECTID_TYPE
	HC_STRING_TYPE
	HC_TIMESTAMP_TYPE
	HC_TIME_TYPE
	HC_UNKNOWN_TYPE
);

our $VERSION = '0.01';

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&Net::HoneyComb::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
#XXX	if ($] >= 5.00561) {
#XXX	    *$AUTOLOAD = sub () { $val };
#XXX	}
#XXX	else {
	    *$AUTOLOAD = sub { $val };
#XXX	}
    }
    goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('Net::HoneyComb', $VERSION);

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Net::HoneyComb - Perl extension for the Sun StorageTek 5800

=head1 SYNOPSIS

  use Net::HoneyComb;

  my $honey = Net::HoneyComb->new(
  	"hc-data",
	8080
  );

  sub reader {
	  my( $ctx, $nbytes ) = @_;
	  sysread($ctx, my $buffer, $nbytes);
	  return $buffer;
  }

  my $oid = $honey->store_both( \&reader, \*STDIN, {
	  "dc.creator" => "Tim Brody",
  });

  sub writer {
	  my( $ctx, $buffer ) = @_;
	  print $buffer;
  }

  $honey->retrieve( $oid, \&writer, undef );

  my $metadata = $honey->retrieve_metadata( $oid );

  my $rset = $honey->query(
  	"'dc.creator'='Tim Brody'",
	100,
	"dcq.abstract"
  );
  my( $oid, $metadata ) = $rset->next;
  print $metadata->{"dcq.abstract"};

  $honey->delete( $oid );

=head1 DESCRIPTION

=head2 EXPORT

None by default.

=head2 Exportable constants

  HC_BINARY_TYPE
  HC_BOGUS_TYPE
  HC_BYTE_TYPE
  HC_CHAR_TYPE
  HC_DATE_TYPE
  HC_DOUBLE_TYPE
  HC_EMPTY_VALUE_INIT
  HC_LONG_TYPE
  HC_OBJECTID_TYPE
  HC_STRING_TYPE
  HC_TIMESTAMP_TYPE
  HC_TIME_TYPE
  HC_UNKNOWN_TYPE


=head1 METHODS

=over 4

=item $honey = Net::HoneyComb->new( HOST, PORT )

Create a new connection to the HoneyComb server on HOST:PORT. croaks() on error.

=item $oid = $honey->store_both( CALLBACK, CONTEXT, METADATA )

Store a file and metadata. METADATA is a reference to a hash. Returns the new object id.

The CALLBACK takes two arguments: CONTEXT and NBYTES. NBYTES is the maxmimum number of bytes to return. When the number of actual bytes returned is less than NBYTES reading finishes. E.g.

	sub {
		my( $context, $nbytes ) = @_;

		my $buffer;
		sysread($context, $buffer, $nbytes);

		return $buffer;
	}

=item $oid = $honey->store_metadata( OID, METADATA )

Store additional METADATA for OID. METADATA is a reference to a hash. Returns the new object id.

=item $hash_ref = $honey->retrieve_metadata( OID )

Retrieve the metadata stored for OID. Returns undef if OID doesn't exist.

=item $ok = $honey->retrieve( OID, CALLBACK, CONTEXT )

Retrieve the content stored for OID. Returns false if OID doesn't exist.

The CALLBACK takes two arguments: CONTEXT and BUFFER. E.g.

	sub {
		my( $context, $buffer ) = @_;

		syswrite($context, $buffer);
	}

=item $rset = $honey->query( QUERY, MAX_RECORDS [, SELECT1, SELECT2, ... ] )

Query the HoneyComb using QUERY. Returns a L<Net::HoneyComb::ResultSet>.

If you wish to retrieve metadata you must specify the fields as SELECT1, SELECT2 etc.

=item $ok = $honey->delete( OID )

Deletes the metadata stored for OID. Returns false if OID doesn't exist.

=item ( $code, $errstr ) = $honey->get_status()

Get the status of the most recent request to the HoneyComb.

=back

=head1 SEE ALSO

L<Net::Amazon::S3>

=head1 AUTHOR

Tim D Brody, E<lt>tdb2@ecs.soton.ac.uk<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Tim D Brody

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=head1 NAME

Net::HoneyComb::ResultSet - Result set

=head1 METHODS

=over 4

=item ( $oid, $metadata ) = $rset->next()

Fetch the next match from the result set. Returns empty list when the query has finished.

=back

=cut
