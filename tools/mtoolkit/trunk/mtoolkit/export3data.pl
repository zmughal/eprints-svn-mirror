#!/usr/bin/perl -w -I/opt/eprints2/perl_lib

use EPrints::EPrint;
use EPrints::Session;
use EPrints::Subject;

use Data::Dumper;
use MIME::Base64 ();
use Unicode::String qw(utf8 latin1 utf16);

use strict;

my $session = new EPrints::Session( 1 , $ARGV[0] );
exit( 1 ) unless( defined $session );

my $archive = $session->get_archive;

my $fh = *STDOUT;
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
	foreach my $dsid ( qw/ inbox buffer archive deletion / )
	{
		my $dataset = $archive->get_dataset( $dsid );
		$dataset->map( $session, \&export_eprint );
	}
	print $fh "</eprints>\n";
}

sub export_users
{
	print $fh "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n";
	print $fh "<users>\n\n";
	my $dataset = $archive->get_dataset( 'user' );
	$dataset->map( $session, \&export_user );
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

	print $fh "<subject xmlns=\"http://eprints.org/ep3/data/3.0\">\n";
	foreach my $field ( $dataset->get_fields )
	{
		my $name = $field->get_name;
		my $value = $item->get_value( $name );
		next unless EPrints::Utils::is_set $value;
		export_value( $field, $value );
	}
	print $fh "</subject>\n\n";
}


sub export_user
{
	my( $session, $dataset, $item ) = @_;

	print $fh "<user xmlns=\"http://eprints.org/ep3/data/3.0\">\n";
	my $sql = "SELECT password FROM users WHERE userid=".$item->get_id;
	( $item->{data}->{password} ) = $session->get_db->{dbh}->selectrow_array( $sql );
	foreach my $field ( $dataset->get_fields )
	{
		my $name = $field->get_name;
		my $value = $item->get_value( $name );
		next unless EPrints::Utils::is_set $value;
		export_value( $field, $value );
	}
	print $fh "</user>\n\n";
}

sub export_value
{
	my( $field, $value ) = @_;

	my $name = $field->get_name;

	if( $field->get_property( "multilang" ) )
	{
		if( $field->get_property( "multiple" ) )
		{
			die "multiple+multilang fields not currently supported.";
		}

		print $fh "  <$name>\n";
		foreach my $langid ( keys %{$value} )
		{
			print $fh "    <item>\n";
			print $fh "      <id>".esc($langid)."</id>\n";
			print $fh "      <name>".rv($field,$value->{$langid})."</name>\n";
			print $fh "    </item>\n";
		}
		print $fh "  </$name>\n";
		return;
	}


	if( !$field->get_property( "multiple" ) )
	{
		print $fh "  <$name>".rv($field,$value)."</$name>\n";
		return;
	}

	print $fh "  <$name>\n";
	foreach my $item ( @{$value} )
	{
		next unless EPrints::Utils::is_set($item);
		if( $field->get_property( "hasid" ) )
		{
			print $fh "    <item>\n";
			if( EPrints::Utils::is_set($item->{id}) )
			{
				print $fh "      <id>".esc($item->{id})."</id>\n";
			}
			if( EPrints::Utils::is_set($item->{name}) )
			{
				print $fh "      <name>".rv($field,$item->{main})."</name>\n";
			}
			print $fh "    </item>\n";
		}
		else
		{
			print $fh "    <item>".rv($field,$item)."</item>\n";
		}
	}
	print $fh "  </$name>\n";
}

sub export_eprint
{
	my( $session, $dataset, $item ) = @_;

	print $fh "<eprint xmlns=\"http://eprints.org/ep3/data/3.0\">\n";
	print $fh "  <eprint_status>".$dataset->id."</eprint_status>\n";
	foreach my $field ( $dataset->get_fields )
	{
		my $name = $field->get_name;
		next if $name eq "fileinfo";
		next if $name eq "date_issue";
		next if $name eq "date_effective";
		next if $name eq "date_sub";
		next if $name eq "dir";
		my $value = $item->get_value( $name );
		next unless EPrints::Utils::is_set $value;
		export_value( $field, $value );
	}
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
	print $fh "  <date>".esc($date)."</date>\n";
	print $fh "  <date_type>".esc($date_type)."</date_type>\n";

	my @docs = $item->get_all_documents;
	print $fh "  <documents>\n";
	foreach my $doc ( @docs )
	{
		print $fh "    <document>\n";
		my $docid = $doc->get_id;
		$docid=~m/^(\d+)-(\d+)$/;
		my $pos = $2+0;
		print $fh "      <eprintid>".esc($doc->get_value( "eprintid" ))."</eprintid>\n";
		print $fh "      <format>".esc($doc->get_value( "format" )||"")."</format>\n";
		print $fh "      <language>".esc($doc->get_value( "language" )||"")."</language>\n";
		print $fh "      <security>".esc($doc->get_value( "security" )||"")."</security>\n";
		print $fh "      <main>".esc($doc->get_value( "main" )||"")."</main>\n";
		print $fh "      <pos>$pos</pos>\n";

		print $fh "      <files>\n";

		my %files = $doc->files;
		foreach my $filename ( keys %files )
		{
			print $fh "        <file>\n";
			print $fh "          <filename>".latin1($filename)."</filename>\n";
			print $fh "          <data encoding=\"base64\">\n";
			my $fullpath = $doc->local_path."/".$filename;
			open( FH, $fullpath ) || die "fullpath '$fullpath' read error: $!";
			my $data = join( "", <FH> );
			close FH;
			print $fh MIME::Base64::encode($data);
			print $fh "          </data>\n";
			print $fh "        </file>\n";
		}

		print $fh "      </files>\n";

		print $fh "    </document>\n";
	}

	print $fh "  </documents>\n";

	print $fh "</eprint>\n\n";
}

sub rv 
{
	my( $field, $value ) = @_;

	if( $field->is_type( "name" ) )
	{
		my $r = "";
		foreach my $p ( qw/ family given lineage honourific / )
		{
			next if !EPrints::Utils::is_set( $value->{$p} );
			$r.="<$p>".esc($value->{$p})."</$p>";
		}
		return $r;
	}
	
	return esc($value);
}

sub esc
{
	my( $text ) = @_;

	$text =~ s/&/&amp;/g;
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;

	return utf8($text);
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

