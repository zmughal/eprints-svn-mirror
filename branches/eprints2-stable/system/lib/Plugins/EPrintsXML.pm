
package EPrints::Plugins::EPrintsXML;
use strict;

EPrints::Plugins::register( 'convert/obj.eprint/eprints_xml/default',	\&object_to_xml );
EPrints::Plugins::register( 'convert/obj.document/eprints_xml/default', 	\&object_to_xml );
EPrints::Plugins::register( 'convert/obj.subject/eprints_xml/default', 	\&object_to_xml );
EPrints::Plugins::register( 'convert/obj.subscription/eprints_xml/default',	\&object_to_xml );
EPrints::Plugins::register( 'convert/obj.user/eprints_xml/default', 	\&object_to_xml );
EPrints::Plugins::register( 'convert/obj/eprints_xml/default', 	\&object_to_xml );

EPrints::Plugins::register( 'export/objs.eprint/eprints_xml/default',	\&objects_to_xml );
EPrints::Plugins::register( 'export/objs.document/eprints_xml/default',	\&objects_to_xml );
EPrints::Plugins::register( 'export/objs.subject/eprints_xml/default',	\&objects_to_xml );
EPrints::Plugins::register( 'export/objs.subscription/eprints_xml/default',	\&objects_to_xml );
EPrints::Plugins::register( 'export/objs.user/eprints_xml/default',	\&objects_to_xml );
EPrints::Plugins::register( 'export/objs/eprints_xml/default',	\&objects_to_xml );

# additional parameter: mode_obj_to_xml
sub objects_to_xml
{
	my( %opts ) = @_;

	if( !defined $opts{objs} ) { EPrints::Config::abort( 'objects_to_xml as not passed an object set (objs)' ); }
	if( !defined $opts{session} ) { EPrints::Config::abort( 'objects_to_xml as not passed a session.' ); }
	if( !defined $opts{mode_obj_to_xml} ) { $opts{mode_obj_to_xml} = 'default'; };

	my $exp = new EPrints::Exporter( %opts, mimetype=>'text/xml' );
	$exp->data( '<?xml version="1.0" encoding="UTF-8" ?>'."\n" );
	$exp->data( "<eprintsdata xmlns='http://eprints.org/ep2/data' type='".$opts{objs}->get_dataset->confid."'>\n" );
	$opts{objs}->map( sub { 
		my( $session, $dataset, $obj, $info ) = @_;
		my $xml = EPrints::Plugins::call(
			'convert/obj/eprints_xml/'.$opts{mode_obj_to_xml},
			$obj,	
			$session );
		$exp->data( EPrints::XML::to_string( $xml ) );
	}, {}, $opts{'offset'}, $opts{'count'} );
	$exp->data( "</eprintsdata>\n" );
	return $exp->finish;	
}

sub object_to_xml
{
	my( $obj, $session ) = @_;

	my $dataset = $obj->get_dataset;

	#my $frag = $session->make_doc_fragment;
	#$frag->appendChild( $session->make_text( "  " ) );
	my $r = $session->make_element( 
		"record",
		xmlns => 'http://eprints.org/ep2/data' );
	$r->appendChild( $session->make_text( "\n" ) );
	foreach my $field ( $dataset->get_fields() )
	{
		next unless( $field->get_property( "export_as_xml" ) );

		$r->appendChild( &mk_xml( 
			$session, 
			$field,
			$obj->get_value( $field->get_name() ) ) );
	}
	$r->appendChild( $session->make_text( "  " ) );
	#$frag->appendChild( $r );
	#$frag->appendChild( $session->make_text( "\n" ) );

	return $r;
}

sub mk_xml
{
	my( $session, $field, $v ) = @_;

	my $r = $session->make_doc_fragment;
	if( $field->get_property( "multiple" ) )
	{
		foreach( @{$v} )
		{
			$r->appendChild( $session->make_text( "    " ) );
			$r->appendChild( &mk_xml2( $session, $field, $_ ) );
			$r->appendChild( $session->make_text( "\n" ) );
		}
	}
	else
	{
		$r->appendChild( $session->make_text( "    " ) );
		$r->appendChild( &mk_xml2( $session, $field, $v ) );
		$r->appendChild( $session->make_text( "\n" ) );
	}
	return $r;
}

sub mk_xml2
{
	my( $session, $field, $v ) = @_;

	my %attrs = ( name=>$field->get_name() );
	if( $field->get_property( "hasid" ) )
	{
		$attrs{id} = $v->{id};
		$v = $v->{main};
	}
	my $r = $session->make_element( "field", %attrs );

	if( $field->get_property( "multilang" ) )
	{
		foreach( keys %{$v} )
		{
			my $l = $session->make_element( "lang", id=>$_ );
			$l->appendChild( mk_xml3( $session, $field, $v->{$_} ) );
			$r->appendChild( $l );
		}
	}
	else
	{
		$r->appendChild( mk_xml3( $session, $field, $v ) );
	}

	return $r;
}

sub mk_xml3
{
	my( $session, $field, $v ) = @_;

	my $r = $session->make_doc_fragment;
	if( $field->is_type( "name" ) )
	{
		foreach( "honourific", "given", "family", "lineage" )
		{
			next unless( defined $v->{$_} && $v->{$_} ne "" );
			my $e = $session->make_element( "part", name=>$_ );
			$e->appendChild( $session->make_text( $v->{$_} ) );
			$r->appendChild( $e );
		}
	}
	else
	{
		$r->appendChild( $session->make_text( $v ) ) if defined( $v );
	}
	return $r;
}



