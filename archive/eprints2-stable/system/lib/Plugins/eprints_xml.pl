
package EPrints::Plugins::eprints_xml;
use strict;
use EPrints::Session;

EPrints::Plugins::register( 'type/convert/eprints_xml/system.primitive', \&primitive_to_eprints_xml );
EPrints::Plugins::register( 'type/convert/eprints_xml/system.list', \&list_to_eprints_xml );
EPrints::Plugins::register( 'type/convert/eprints_xml/system.struct', \&struct_to_eprints_xml );


sub primitive_to_eprints_xml
{
	my( %opts ) = @_;

	$opts{indent} = 0 unless defined $opts{indent};

	my $str;
	if( defined $opts{value} ) 
	{
		$str .= $opts{value};
	}
	else
	{
		$str .= '';
	}
	return &SESSION->make_text( $str );
}



sub list_to_eprints_xml
{
	my( %opts ) = @_;

	$opts{indent} = 0 unless defined $opts{indent};
	$opts{value} = [] unless defined $opts{value};

	my $subtype = $opts{type}->getType;

	my %subopts = %opts;
	$subopts{indent} += 1;
	my $f = &SESSION->make_doc_fragment;
	foreach my $v ( @{$opts{value}} )
	{
		$subopts{value} = $v;
		$f->appendChild( &SESSION->make_text( "\n" ) );
		$f->appendChild( &SESSION->make_text( '  'x$opts{indent} ) );
		my $item = &SESSION->make_element( 'item' );
		$item->appendChild( 
			$subtype->plugin( 'convert/eprints_xml', %subopts ) );
		$f->appendChild( $item );
	}

	return $f;
}


sub struct_to_eprints_xml
{
	my( %opts ) = @_;

	$opts{indent} = 0 unless defined $opts{indent};
	$opts{value} = {} unless defined $opts{value};

	my $subfields = $opts{type}->getFields;

	my $f = &SESSION->make_doc_fragment;
	$f->appendChild( &SESSION->make_text( "\n" ) );
	$f->appendChild( &SESSION->make_text( '  'x$opts{indent} ) );
	my $el = &SESSION->make_element( 'struct' );
	$f->appendChild( $el );
	$el->appendChild( &SESSION->make_text( "\n" ) );

	my %subopts = %opts;
	$subopts{indent} += 2;
	foreach my $field ( @{$subfields} )
	{	
		$el->appendChild( &SESSION->make_text( 
			'  'x$opts{indent}.'  ' ) );
		my $fel = &SESSION->make_element( 
					'field',
					name=>$field->getName );
		$subopts{value} = $opts{value}->{$field->getName};
		$fel->appendChild( $field->getType->plugin( 	
			'convert/eprints_xml', 
			%subopts ));
		$el->appendChild( $fel );
		$el->appendChild( &SESSION->make_text( "\n" ) );
	}
	$el->appendChild( &SESSION->make_text( '  'x$opts{indent} ) );

	return $f;
}










1;
