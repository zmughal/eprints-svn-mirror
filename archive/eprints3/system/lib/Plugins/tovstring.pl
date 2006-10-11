
package EPrints::Plugins::tovstring;
use strict;
use EPrints::Session;

EPrints::Plugins::register( 'type/convert/vstring/system.primitive', \&primitive_to_vstring );
EPrints::Plugins::register( 'type/convert/vstring/system.list', \&list_to_vstring );
EPrints::Plugins::register( 'type/convert/vstring/system.struct', \&struct_to_vstring );


sub primitive_to_vstring
{
	my( %opts ) = @_;

	$opts{indent} = 0 unless defined $opts{indent};

	my $str;
	$str .= "  "x$opts{indent};
	if( defined $opts{value} ) 
	{
		$str .= "\"$opts{value}\"";
	}
	else
	{
		$str .= 'undef';
	}
	$str.="\n";

	return $str;
}



sub list_to_vstring
{
	my( %opts ) = @_;

	$opts{indent} = 0 unless defined $opts{indent};
	$opts{value} = [] unless defined $opts{value};

	my $subtype = $opts{type}->getType;

	my %subopts = %opts;
	$subopts{indent} += 0;
	my $str = "";
	foreach my $v ( @{$opts{value}} )
	{
		$subopts{value} = $v;
		$str .= $subtype->plugin( 'convert/vstring', %subopts );
	}

	return $str;
}


sub struct_to_vstring
{
	my( %opts ) = @_;

	$opts{indent} = 0 unless defined $opts{indent};
	$opts{value} = {} unless defined $opts{value};

	my $subfields = $opts{type}->getFields;

	my %subopts = %opts;
	$subopts{indent} += 2;
	my $str = "";
	$str .= "  "x$opts{indent}.$opts{type}->getClass."\n";
	foreach my $field ( @{$subfields} )
	{	
		$str .= "  "x$opts{indent}.'  '.$field->getName."\n";
		$subopts{value} = $opts{value}->{$field->getName};
		$str .= $field->getType->plugin( 'convert/vstring', %subopts );
	}

	return $str;
}






1;



1;
