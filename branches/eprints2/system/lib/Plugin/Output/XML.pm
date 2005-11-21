package EPrints::Plugin::Output::XML;

# eprint needs magic documents field

# documents needs magic files field

use Unicode::String qw( utf8 );

use EPrints::Plugin::Output;

@ISA = ( "EPrints::Plugin::Output" );

use strict;

# The utf8() method is called to ensure that
# any broken characters are removed. There should
# not be any broken characters, but better to be
# sure.

sub new
{
	my( $class, @params ) = @_;
	return $class->SUPER::new( @params );
}

sub id { return "output/xml"; }

sub is_visible { return 1; }

sub defaults
{
	my %d = $_[0]->SUPER::defaults();
	$d{name} = "XML";
	$d{accept} = [ 'list/*', 'dataobj/*' ];
	return %d;
}


sub mime_type
{
	my( $plugin, $searchexp ) = @_;

	return "text/xml";
}

sub suffix
{
	my( $plugin, $searchexp ) = @_;

	return ".xml";
}


sub output_list
{
	my( $plugin, %opts ) = @_;

	my $type = $opts{list}->get_dataset->confid;
	my $toplevel = $type."s";
	
	my @r = '';

	my $part;
	$part = '<?xml version="1.0" encoding="utf-8" ?>'."\n<$toplevel>\n";
	if( defined $opts{fh} ) { print {$opts{fh}} $part; } else { push @r, $part; }

	foreach my $dataobj ( $opts{list}->get_records )
	{
		$part = $plugin->output_dataobj( $dataobj );
		if( defined $opts{fh} ) { print {$opts{fh}} $part; } else { push @r, $part; }
	}	

	$part= "</$toplevel>\n";
	if( defined $opts{fh} ) { print {$opts{fh}} $part; } else { push @r, $part; }

	if( !defined $opts{fh} ) { return join( '', @r ); }
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $itemtype = $dataobj->get_dataset->confid;
	my @r = ();
	push @r, "  <",$itemtype,">";
	foreach my $field ( $dataobj->get_dataset->get_fields )
	{
		push @r, field_to_xml( $field, $dataobj->get_value( $field->get_name ), 2 );
	}
	push @r, "\n  </",$itemtype,">\n";
	return join("", @r );
}

sub field_to_xml
{
	my( $field, $value, $depth ) = @_;

	my $ind = "  "x$depth;
	my @r = ();

	push @r, "\n", $ind, "<".$field->get_name.">";	
	if( $field->get_property( "multiple" ) )
	{
		foreach my $single ( @{$value} )
		{
			push @r, "\n  ",$ind,"<item>",field_to_xml_single( $field, $single, $depth+1 ),"</item>";
		}
		push @r, "\n", $ind;
	}
	else
	{
		push @r, field_to_xml_single( $field, $value, $depth );
	}
	push @r, "</".$field->get_name.">";	
	return @r;
}

sub field_to_xml_single
{
	my( $field, $value, $depth ) = @_;

	my $ind = "  "x$depth;
	my @r = ();

	if( $field->get_property( "hasid" ) )
	{
		my $v = $value->{id};
		$v = "" unless( defined $v );
		push @r, "\n  ",$ind,"<id>",utf8($v),"</id>";
		push @r, "\n  ",$ind,"<main>",field_to_xml_noid( $field, $value->{main}, $depth+1 ),"</main>";
		push @r, "\n",$ind;
	}
	else
	{
		push @r, field_to_xml_noid( $field, $value, $depth );
	}
	return @r;
}

sub field_to_xml_noid
{
	my( $field, $value, $depth ) = @_;

	my $ind = "  "x$depth;
	my @r = ();

	if( $field->get_property( "multilang" ) )
	{
		foreach my $langid ( keys %{$value} )
		{
			push @r, "\n  ",$ind,"<langvar>";
			push @r, "\n    ",$ind,"<lang>",utf8($langid),"</lang>";
			push @r, "\n    ",$ind,"<value>",field_to_xml_basic( $field, $value->{$langid}, $depth+2 ),"</value>";
			push @r, "\n  ",$ind,"</langvar>";
			push @r, "\n",$ind;
		}
	}
	else
	{
		push  @r, field_to_xml_basic( $field, $value, $depth );
	}
	return @r;
}

sub field_to_xml_basic
{
	my( $field, $value, $depth ) = @_;

	my $ind = "  "x$depth;
	my @r = ();

	if( $field->is_type( "name" ) )
	{
		foreach my $part ( qw/ family given honourific lineage / )
		{
			my $nv = $value->{$part};
			$nv = "" unless defined $nv;
			push @r, "\n  ".$ind,"<",$part,">",utf8($nv),"</",$part,">";
		}
		push @r, "\n".$ind;
	}
	else
	{
		if( defined $value )
		{
			push @r, utf8($value);
		}
	}
	return @r;	
}

