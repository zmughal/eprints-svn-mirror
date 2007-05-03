#!/usr/bin/perl -w -I/opt/eprints2/perl_lib

# map eprints 2 formats to proper mime-types
# these will need configuring in eprints 3
our %FORMAT_MAPPING = qw(
	html	text/html
	pdf	application/pdf
	ps	application/postscript
	ascii	text/plain
	msword	application/mssword
	image	image
	latex	latex
	powerpoint	application/vnd.ms-powerpoint
	coverimage	coverimage
	other	other
);

=pod

=head1 NAME

B<export3data.pl> - export data from an eprints 2 repository in eprints 3 xml format

=head1 SYNOPSIS

B<export3data.pl> [B<options>] I<archive> I<eprints|users|subjects> [B<list of ids>]

=head1 DESCRIPTION

This tool will attempt to export data from an eprints 2 repository in a format suitable for import into an appropriately configured eprints 3 repository. This is probably a good place to make alterations to your metadata layout (but you will have to customise this script).

This script will not allow you to export records that contain badly encoded records (because they'd just fail on import anyway).

This script requires Perl IO, which is only in Perl 5.8 onwards. It is anticipated that you would copy your existing eprints 2 installation to a new server, parallel to your eprints 3 installation, before executing this script.

=head1 ARGUMENTS

=over 8

=item I<archive>

The ID of the EPrint archive to export from.

=item I<eprints|users|subjects>

The dataset to export.

=back

=head1 OPTIONS

=over 8

=item B<--inline>

Base-64 encode documents and include them in the XML output.

=item B<--verbose>

Be more verbose about what's going on (repeat for more verbosity).

=item B<--skiplog>

Specify a file to write eprint ids to that are in badly encoded UTF8. You will need to fix these eprints by hand.

=back

=cut

use Carp;
use Encode;
use Pod::Usage;

# $SIG{__DIE__} = $SIG{__WARN__} = sub { Carp::confess(@_) };

use EPrints::EPrint;
use EPrints::Session;
use EPrints::Subject;

use Getopt::Long;

use strict;
use warnings;

our( $opt_help, $opt_skiplog, $opt_inline );
our $opt_verbose = 0;

GetOptions(
	'help' => \$opt_help,
	'verbose+' => \$opt_verbose,
	'skiplog=s' => \$opt_skiplog,
	'inline' => \$opt_inline,
) or pod2usage( 2 );
pod2usage( 1 ) if $opt_help;
pod2usage( 2 ) if scalar @ARGV < 2;

if( $opt_inline )
{
	eval "use PerlIO::via::Base64;";
	if( $@ )
	{
		die "Inlining files requires PerlIO::via::Base64.\n";
	}
}

my $SKIPLOG;
if( $opt_skiplog )
{
	open($SKIPLOG, ">", $opt_skiplog)
		or die "Unable to open $opt_skiplog for writing: $!";
}

# We can optionally only export a given set of items (very useful for
# debugging)
our @IDS = splice(@ARGV,2);

##############################################################################
# End of Command-Line Arguments
##############################################################################

# Global variables/constants
our $TOTAL = -1;
our $DONE = 0;
our $XMLNS = 'http://eprints.org/ep3/data/3.0';
our $UTF8_QUOTE = pack('U',0x201d); # Opening quote
Encode::_utf8_off($UTF8_QUOTE);

# Lets connect to eprints
my $session = new EPrints::Session( 1 , $ARGV[0] );
exit( 1 ) unless( defined $session );

my $archive = $session->get_archive;

my $fh = *STDOUT;
binmode($fh, ":utf8");


if( $ARGV[1] eq "subjects" )
{
	export_subjects();
}
elsif( $ARGV[1] eq "eprints" )
{
	export_eprints();
}
elsif( $ARGV[1] eq "users" )
{
	export_users();
}
else
{
	print "Unknown dataset: $ARGV[1]. (users/eprints/subjects)\n";
}


$session->terminate();
exit;


sub export_eprints
{
	print $fh "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n";
	print $fh "<eprints>\n\n";
	if( @IDS )
	{
		$TOTAL = @IDS;
		foreach my $id (@IDS)
		{
			my $item = EPrints::EPrint->new( $session, $id );
			if( !$item )
			{
				die "$id does not exist\n";
			}
			my $dataset = $item->get_dataset();
			print STDERR "Reading eprint $id from dataset ".$dataset->{id}."\n" if $opt_verbose > 1;
			export_eprint( $session, $dataset, $item );
		}
	}
	else
	{
		my @datasets = qw( inbox buffer archive deletion );
		$TOTAL = 0;
		foreach my $dsid ( @datasets )
		{
			my $dataset = $archive->get_dataset( $dsid );
			$TOTAL += $dataset->count( $session );
		}
		foreach my $dsid ( @datasets )
		{
			print STDERR "Dataset: $dsid\n" if $opt_verbose;
			my $dataset = $archive->get_dataset( $dsid );
			$dataset->map( $session, \&export_eprint );
		}
	}
	print $fh "</eprints>\n";
}

sub export_users
{
	print $fh "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n";
	print $fh "<users>\n\n";
	my $dataset = $archive->get_dataset( 'user' );
	if( @IDS )
	{
		$TOTAL = @IDS;
		foreach my $id (@IDS)
		{
			my $item = EPrints::User->new( $session, $id );
			if( !$item )
			{
				die "$id does not exist\n";
			}
			print STDERR "Reading user $id from dataset ".$dataset->{id}."\n" if $opt_verbose > 1;
			export_user( $session, $dataset, $item );
		}
	}
	else
	{
		$dataset->map( $session, \&export_user );
	}
	print $fh "</users>\n";
}

sub export_subjects
{
	print $fh "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n";
	print $fh "<subjects>\n\n";
	my $dataset = $archive->get_dataset( 'subject' );
	$dataset->map( $session, \&export_subject );
	print $fh "</subjects>\n";
}


sub export_subject
{
	my( $session, $dataset, $item ) = @_;

	my $subject = $session->make_element( 'subject', xmlns => $XMLNS );

	foreach my $field ( $dataset->get_fields )
	{
		my $name = $field->get_name;
		next if $name eq "ancestors";
		my $value = $item->get_value( $name );
		next unless EPrints::Utils::is_set $value;
		$subject->appendChild(export_value( $session, $field, $value ));
	}
	print $fh $subject->toString . "\n\n";
}


sub export_user
{
	my( $session, $dataset, $item ) = @_;

	my $user = $session->make_element( 'user', xmlns => $XMLNS );

	my $sql = "SELECT `password` FROM `users` WHERE `userid`=".$item->get_id;
	( $item->{data}->{password} ) = $session->get_db->{dbh}->selectrow_array( $sql );
	foreach my $field ( $dataset->get_fields )
	{
		my $name = $field->get_name;
		my $value = $item->get_value( $name );
		next unless EPrints::Utils::is_set $value;
		$user->appendChild( export_value( $session, $field, $value ) );
	}

	print $fh $user->toString . "\n\n";
}

sub export_value
{
	my( $session, $field, $value ) = @_;

	my $name = $field->get_name;

	my $dom = $session->make_element( $name );

	if( $field->get_property( "multilang" ) )
	{
		if( $field->get_property( "multiple" ) )
		{
			die "multiple+multilang fields not currently supported.";
		}

		foreach my $langid ( keys %{$value} )
		{
			$dom->appendChild( my $item = $session->make_element( 'item' ) );
			$item->appendChild( $session->make_element( 'name' ) )
				->appendChild( rv($session, $field, $value->{$langid}) );
			$item->appendChild( $session->make_element( 'lang' ) )
				->appendChild( $session->make_text( $langid ) );
		}
		return $dom;
	}


	if( !$field->get_property( "multiple" ) )
	{
		$dom->appendChild( rv($session, $field, $value) );
		return $dom;
	}

	foreach my $v ( @{$value} )
	{
		next unless EPrints::Utils::is_set($v);
		$dom->appendChild( my $item = $session->make_element( 'item' ) );
		if( $field->get_property( "hasid" ) )
		{
			if( EPrints::Utils::is_set($v->{id}) )
			{
				$item->appendChild( $session->make_element( 'id' ) )
					->appendChild( $session->make_text( $v->{id} ) );
			}
			if( EPrints::Utils::is_set($v->{main}) )
			{
				$item->appendChild( $session->make_element( 'name' ) )
					->appendChild( rv( $session, $field, $v->{main} ) );
			}
		}
		else
		{
			$item->appendChild( rv( $session, $field, $v ) );
		}
	}
	return $dom;
}

sub export_hashref
{
	my( $session, $value ) = @_;

	my $dom = $session->make_doc_fragment();

	if( ref($value) eq 'HASH' )
	{
		foreach my $key (keys %$value)
		{
			if( defined($value->{$key}) and $value->{$key} ne '' )
			{
				$dom->appendChild( $session->make_element( $key ) )
					->appendChild( export_hashref( $session, $value->{$key} ) );
			}
		}
	}
	elsif( defined($value) )
	{
		$dom->appendChild( $session->make_text( $value ) );
	}

	return $dom;
}

sub export_dataobj
{
	my( $session, $name, $value ) = @_;

	my $dom = $session->make_element( $name );

	if( ref($value) eq 'ARRAY' )
	{
		foreach my $v ( @$value )
		{
			$dom->appendChild( my $item = $session->make_element( 'item' ) );
			if( ref($v) eq 'HASH' )
			{
				foreach my $key (keys %$v)
				{
					$item->appendChild( $session->make_element( $key ) )
						->appendChild( export_hashref($session, $v->{$key}) );
				}
			}
			else
			{
				$item->appendChild( $session->make_text( $v ) );
			}
		}
	}
	elsif( defined( $value ) )
	{
		$dom->appendChild( $session->make_text( $value ) );
	}

	return $dom;
}

sub export_eprint
{
	my( $session, $dataset, $item ) = @_;

	$DONE++;

	print STDERR int(100*$DONE/$TOTAL) . " \%    " . $item->get_id() . "  \r" if $opt_verbose;

	my $eprint = $session->make_element( 'eprint', xmlns => $XMLNS );

	$eprint->appendChild( $session->make_element( 'eprint_status' ))
		->appendChild( $session->make_text( $dataset->id ));

	foreach my $field ( $dataset->get_fields )
	{
		my $name = $field->get_name;
		next if $name =~ /^fileinfo|date_issue|date_effective|date_sub|dir$/;
		my $value = $item->get_value( $name );
		next unless EPrints::Utils::is_set $value;

		print STDERR "Adding field: $name\n" if $opt_verbose > 1;

		$eprint->appendChild( export_value( $session, $field, $value ) );
	}

	print STDERR "Processing date fields\n" if $opt_verbose > 1;
	
	my $date = "";
	my $date_type = "";
	if( $dataset->has_field( "date_sub" ) && $item->is_set( "date_sub" ) )
	{
		$date = $item->get_value( "date_sub" );
		$date_type = "submitted";
	}
	if( $dataset->has_field( "date_issue" ) && $item->is_set( "date_issue" ) )
	{
		$date = $item->get_value( "date_issue" );
		$date_type = "published";
	}
	$eprint->appendChild( $session->make_element( 'date' ) )
		->appendChild( $session->make_text( $date ) );
	$eprint->appendChild( $session->make_element( 'date_type' ) )
		->appendChild( $session->make_text( $date_type ) );

	print STDERR "Processing documents\n" if $opt_verbose > 1;

	my $documents = $eprint->appendChild( $session->make_element( 'documents' ) );

	my @docs = $item->get_all_documents;
	
	print STDERR "Got ".@docs." documents\n" if $opt_verbose > 2;

	foreach my $doc ( @docs )
	{
		my $document = $documents->appendChild( $session->make_element( 'document' ) );
		my $docid = $doc->get_id;
		$docid=~m/^(\d+)-(\d+)$/;
		my $pos = $2+0;

		print STDERR "Processing document $pos\n" if $opt_verbose > 2;
		
		$document->appendChild( $session->make_element( 'eprintid' ) )
			->appendChild($session->make_text($doc->get_value( 'eprintid' )));

		my $format = $doc->get_value( 'format' ) || 'other';
		if( exists $FORMAT_MAPPING{$format} )
		{
			$format = $FORMAT_MAPPING{$format};
		}
		$document->appendChild( $session->make_element( 'format' ) )
			->appendChild($session->make_text($format));

		$document->appendChild( $session->make_element( 'language' ) )
			->appendChild($session->make_text($doc->get_value( 'language' )||''));
		my $security = $doc->get_value( "security" ) || "public";
		$document->appendChild( $session->make_element( 'security' ) )
			->appendChild($session->make_text($security));
		$document->appendChild( $session->make_element( 'main' ) )
			->appendChild($session->make_text($doc->get_value( 'main' )||''));
		$document->appendChild( $session->make_element( 'pos' ) )
			->appendChild($session->make_text($pos));

		my $files = $document->appendChild( $session->make_element( 'files' ) );

		my %filenames = $doc->files;
		print STDERR "Contains ".scalar(keys(%filenames))." files\n" if $opt_verbose > 2;

		# No files in this document, destroy it (something odd happened)
		if( scalar(keys %filenames) == 0 )
		{
			$documents->removeChild( $document );
		}
		else
		{
			foreach my $filename ( keys %filenames )
			{
				my $file = $files->appendChild( $session->make_element( 'file' ) );

				$file->appendChild($session->make_element( 'filename' ))
					->appendChild($session->make_text( $filename ));
				my $fullpath = $doc->local_path."/".$filename;
				$file->appendChild($session->make_element( 'data',
							'href' => "file://" . $fullpath ));
			}
		}
	}

	# In eprints.soton we have multiple isbns, which are a compound of isbn and
	# cover. There are some legacy records with a single isbn which we'll
	# resurrect if isbns isn't set

#	print STDERR "Processing ISBNs\n" if $opt_verbose > 1;

#	if( $dataset->has_field( "isbns" ) and $item->is_set( "isbns" ) )
#	{
#		my $values = $item->get_value( "isbns" );
#		if( defined $values )
#		{
#			for( @$values )
#			{
#				$_ = {
#					isbn => $_->{main},
#					cover => ((defined($_->{id}) and $_->{id} ne '') ? $_->{id} : 'unspecified'),
#				};
#			}
#			$eprint->appendChild( export_dataobj( $session, "isbns" , $values ) );
#		}
#	}
#	elsif( $item->is_set( "isbn" ) )
#	{
#		my $value = $item->get_value( "isbn" );
#		$value = {
#			isbn => $value,
#			cover => 'unspecified'
#		};
#		$eprint->appendChild( export_dataobj( $session, "isbns", [$value] ));
#	}

	# In eprints 3 issns will be flagged as electronic or paper (another
	# compound field)

#	print STDERR "Processing ISSN\n" if $opt_verbose > 1;

#	if( $dataset->has_field( "issn" ) and $item->is_set( "issn" ) )
#	{
#		my $value = $item->get_value( "issn" );
#		$eprint->appendChild( export_dataobj( $session, "issns" , [ { issn => $value, cover => 'unspecified' } ] ) );
#	}
	
	# More fields being turned into compounds

#	print STDERR "Processing exhibition_eventlocdate\n" if $opt_verbose > 1;

#	if( $dataset->has_field( "exhibition_eventlocdate" ) and $item->is_set( "exhibition_eventlocdate" ) )
#	{
#		my $values = $item->get_value( "exhibition_eventlocdate" );
#		if( defined $values )
#		{
#			for(@$values)
#			{
#				my( $date, $venue ) = split /\|/, $_, 2;
#				$_ = {
#					venue => $venue,
#					date => $date,
#				};
#			}

#			$eprint->appendChild( export_dataobj( $session, "venue_date", $values ) );
#		}
#	}

	# In eprints.soton we store the staff id for all RAE-returnable fields (or,
	# if not a member of staff, 'internal', 'external' or 'unknown'). In
	# eprints 3 this is obviously a compound field, whereas in 2 it was two
	# fields that were kept synchronised.
	# (We didn't use the id part in eprints 2, because we don't want users to be
	# able to directly edit the staff id bit)

#	foreach my $namefield (qw( creators editors exhibitors ))
#	{
#		print STDERR "Processing $namefield\n" if $opt_verbose > 1;

#		if( $dataset->has_field( $namefield ) and $item->is_set( $namefield ) )
#		{
#			my $names = $item->get_value( $namefield );
#			my $staffids = $item->get_value( $namefield."_empid" ) || [];

# Ignore the id
#			for(@$names)
#			{
#				$_ = {
#					name => $_->{main},
#					staffid => 'unknown',
#				};
#			}

#			for(my $i = 0; $i < @$staffids; $i++)
#			{
#				if( $staffids->[$i] ne '' )
#				{
#					$names->[$i]->{staffid} = $staffids->[$i];
#				}
#			}

#			$eprint->appendChild( export_dataobj( $session, $namefield, $names ));
#		}
#	}

	# Check that our output is valid utf8, otherwise we'll have trouble parsing
	# it (and import is much, much slower than export)
	# You might want to modify this to automatically replace bad chars with a
	# '?' or similar, but it's probably better to manually inspect and fix
	# problems.

	my $xml = $eprint->toString();
	$xml =~ s/\xe2\x80\x3f/$UTF8_QUOTE/sg; # Fix word's bespoke quote for Unicode
#	$xml =~ s/[\x00-\x08\x0B\x0C\x0E-\x1F]//g;
	my $error;
	unless( check_utf8($xml, \$error) )
	{
		if( defined($SKIPLOG) )
		{
			print $SKIPLOG $item->{dataset}->{id} . "\t" . $item->get_id . "\t$error\n";
		}
		else
		{
			print STDERR "Fix invalid utf8 in eprint " . $item->get_id . " (or use the skiplog argument to log all unexportable eprints): $error\n";
			exit;
		}
		return;
	}

	# inject the base64-encoded files
	if( $opt_inline )
	{
		print STDERR "Injecting base64 encoded files\n" if $opt_verbose > 1;
		# locate the <data></data> fields
		my( $pre, @files ) = split /(<data[^>]+(?:>\s*<\/\s*data\s*>|\/>))/, $xml;
		@files = grep { length($_) } @files; # remove the tween bits
		my $post = pop @files;

		print $fh $pre;
		foreach my $data (@files)
		{
			($data) = EPrints::XML::parse_xml_string( $data )->getElementsByTagName( 'data' );
			print $fh "<data encoding=\"base64\">";
			my $url = $data->getAttribute( 'href' );
			$url =~ s/^file:\/\///;
			write_base64_file( $fh, $url );
			print $fh "</data>\n";
		}
		print $fh $post if defined $post;
	}
	else
	{
		print $fh $xml . "\n";
	}
	
	print STDERR "Done Processing Eprint: " . $item->get_id . "\n" if $opt_verbose > 1;
}

# Handle name fields correctly (should this include id???)

sub rv 
{
	my( $session, $field, $value ) = @_;

	my $dom = $session->make_doc_fragment;

	if( $field->is_type( "name" ) )
	{
		foreach my $p ( qw/ family given lineage honourific / )
		{
			next if !EPrints::Utils::is_set( $value->{$p} );
			$dom->appendChild( $session->make_element( $p ) )
				->appendChild( $session->make_text( $value->{$p} ) );
		}
	}
	else
	{
		$dom->appendChild( $session->make_text( $value ) );
	}

	return $dom;
}

# write a $filename to $out in base64 encoding

sub write_base64_file
{
	my( $out, $filename ) = @_;

	binmode($out, ":via(Base64)");
	open(my $fh, "<", $filename) or die "Unable to open $filename: $!\n";
	binmode($fh);
	while(read($fh, my $buffer, 4096))
	{
		print $out $buffer;
	}
	close($fh);
	binmode($out, ":pop");
}

# fill $error with the locations of bad chars in $bytes
# returns true if the string is ok

sub check_utf8
{
	my( $bytes, $error ) = @_;

	my $max_errors = 10;
	$$error = '';

	do {
		my $str = Encode::decode("utf8", $bytes, Encode::FB_QUIET);
		if( length($bytes) )
		{
			$str =~ s/^.+(.{40})$/... $1/s;
			$$error .= "Bad char '$str'<--HERE!!! ";
			while( length($bytes) and ord(substr($bytes, 0, 1)) > 0x80 )
			{
				substr($bytes, 0, 1) = '';
			}
		}
	} while( length($bytes) and $max_errors-- );

	return length($$error) == 0;
}

__DATA__
    <eprintid>1</eprintid>
    <rev_number>11</rev_number>
    <eprint_status>buffer</eprint_status>
    <userid>1</userid>
    <dir>disk0/00/00/00/01</dir>
    <lastmod>2006-12-18 17:11:56</lastmod>
    <status_changed>2006-12-18 17:11:56</status_changed>
    <type>release</type>
    <metadata_visibility>show</metadata_visibility>
    <fileinfo>http://files3.eprints.org/style/images/fileicons/html.png;http://files3.eprints.org/1/1/versions.txt</fileinfo>
    <license>Other</license>
    <documents>
      <document xmlns="http://eprints.org/ep3/data/3.0">
        <docid>1</docid>
        <rev_number>3</rev_number>
        <eprintid>1</eprintid>
        <pos>1</pos>
        <format>html</format>
        <language>en</language>
        <security>validuser</security>
        <main>versions.txt</main>
        <files>
          <file>
            <filename>versions.txt</filename>
            <filesize>3515</filesize>
            <url>http://files3.eprints.org/1/1/versions.txt</url>
          </file>
        </files>
      </document>
    </documents>
  </eprint>

