
package EPrints::Plugins::render_value;
use strict;
use EPrints::Session;

EPrints::Plugins::register( 'convert/value.int/xhtml/default', \&simple_to_xhtml );
EPrints::Plugins::register( 'convert/value.text/xhtml/default', \&simple_to_xhtml );
EPrints::Plugins::register( 'convert/value.subject/xhtml/default', \&simple_to_xhtml );

EPrints::Plugins::register( 'convert/value.list/xhtml/default', \&list_to_xhtml );
EPrints::Plugins::register( 'convert/value.withid/xhtml/default', \&withid_to_xhtml );
EPrints::Plugins::register( 'convert/value.struct/xhtml/default', \&struct_to_xhtml );
EPrints::Plugins::register( 'convert/value.name/xhtml/default', \&name_to_xhtml );
EPrints::Plugins::register( 'convert/value.name/xhtml/default', \&name_to_xhtml );

sub simple_to_xhtml
{
	my( %opts ) = @_;

	my $v = &SESSION->make_text( $opts{data} );

	return $v;
}

sub list_to_xhtml
{
	my( %opts ) = @_;

#cjg hack
	my $subtype = $opts{type}->{types}->[0];

	my $ol = &SESSION->make_element( 'ol' );
	foreach my $value ( @{$opts{data}} )
	{	
		my $li = &SESSION->make_element( 'li' );
		$li->appendChild( $subtype->render_value( $value, %opts ) );
		$ol->appendChild( $li );
	}

	return $ol;
}

sub struct_to_xhtml
{
	my( %opts ) = @_;

#cjg hack
	my $subfields = $opts{type}->{fields};

	my $dl = &SESSION->make_element( 'dl' );
	foreach my $field ( @{$subfields} )
	{	
		my $dt = &SESSION->make_element( 'dt' );
		$dt->appendChild( &SESSION->make_text( $field->getName )); #cjg hack.
		$dl->appendChild( $dt );
		my $dd = &SESSION->make_element( 'dd' );
		$dd->appendChild( $field->getType->render_value( 
			$opts{data}->{$field->getName}, %opts ) );#cjg hack?
		$dl->appendChild( $dd );
	}

	return $dl;
}

sub name_to_xhtml
{
	my( %opts ) = @_;

	my $order = $opts{render_opts}->{order};

	# If the render opt "order" is set to "gf" then we order
	# the name with given name first. 

	return &SESSION->render_name(
			$opts{data},
			defined $order && $order eq "gf" );
}

sub withid_to_xhtml
{
	my( %opts ) = @_;

	# cjg hack
	return $opts{type}->{fmap}->{main}->getType->render_value( 
		$opts{data}->{main},
		%opts );
}



1;
