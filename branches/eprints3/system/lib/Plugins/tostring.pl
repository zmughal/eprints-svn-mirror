
package EPrints::Plugins::tostring;
use strict;
use EPrints::Session;

EPrints::Plugins::register( 'type/convert/string/system.primitive', \&primitive_to_string );
EPrints::Plugins::register( 'type/convert/string/system.list', \&list_to_string );
EPrints::Plugins::register( 'type/convert/string/system.struct', \&struct_to_string );

sub primitive_to_string
{
	my( %opts ) = @_;

	$opts{indent} = 0 unless defined $opts{indent};

	my $str .= "  "x$opts{indent}.$opts{type}->getClass."\n";
	return $str;
}



sub list_to_string
{
	my( %opts ) = @_;

	$opts{indent} = 0 unless defined $opts{indent};

	my $subtype = $opts{type}->getType;

	my %subopts = %opts;
	$subopts{indent} += 1;
	my $str = "";
	$str .= "  "x$opts{indent}.$opts{type}->getClass."\n";
	$str .= $subtype->plugin( 'convert/string', %subopts );

	return $str;
}


sub struct_to_string
{
	my( %opts ) = @_;

	$opts{indent} = 0 unless defined $opts{indent};

	my $subfields = $opts{type}->getFields;

	my %subopts = %opts;
	$subopts{indent} += 2;
	my $str = "";
	$str .= "  "x$opts{indent}.$opts{type}->getClass."\n";
	foreach my $field ( @{$subfields} )
	{	
		$str .= "  "."  "x$opts{indent}.'$'.$field->getName."\n";
		$str .= $field->getType->plugin( 'convert/string', %subopts );
	}

	return $str;
}











1;
