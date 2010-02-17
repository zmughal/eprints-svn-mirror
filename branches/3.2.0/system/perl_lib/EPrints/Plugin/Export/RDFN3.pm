package EPrints::Plugin::Export::RDFN3;

use EPrints::Plugin::Export::RDF;
use EPrints::Plugin::Export::RDFXML;

@ISA = ( "EPrints::Plugin::Export::RDF" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "RDF+N3";
	$self->{accept} = [ 'list/*', 'dataobj/*' ];
	$self->{visible} = "all";
	$self->{suffix} = ".n3";
	$self->{mimetype} = "text/n3";
	$self->{qs} = 0.84;

	return $self;
}

# static method
sub n3_header 
{
	my( $repository, $namespaces ) = @_;

	my @r = ();
	foreach my $xmlns ( keys %{$namespaces} )
	{
		push @r, "  \@prefix $xmlns: <".$namespaces->{$xmlns}."> .\n";
	}

	return join( "", @r );
}


sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $repository = $plugin->{session}->get_repository;

	my $cache = {};
	$plugin->cache_general_triples( $cache );
	$plugin->cache_dataobj_triples( $dataobj, $cache );
	my $namespaces = $plugin->get_namespaces();

	return $plugin->output_triple_cache( $cache, $namespaces );
}

# Later this may print the header then output each batch of, say, 100
# eprints so that it doesn't take up crazy memory.
sub output_list
{
	my( $plugin, %opts ) = @_;

	my $cache = {};
	$plugin->cache_general_triples( $cache );
	$opts{list}->map( sub {
		my( $session, $dataset, $dataobj ) = @_;

		$plugin->cache_dataobj_triples( $dataobj, $cache );
	} );

	return $plugin->output_triple_cache( $cache, %opts );
}

sub output_triple_cache
{
	my( $plugin, $cache, %opts ) = @_;

	my $repository = $plugin->{session}->get_repository;
	my $namespaces = $plugin->get_namespaces();

	if( defined $opts{fh} )
	{
		print {$opts{fh}} n3_header( $repository, $namespaces );
		print {$opts{fh}} cache_to_n3( $cache, $namespaces );
		return undef;
	}
	else
	{
		my $r = [];
		push @{$r}, n3_header( $repository, $namespaces );
		push @{$r}, cache_to_n3( $cache, $namespaces);
		return join( '', @{$r} );
	}
}

sub cache_to_n3
{
	my( $cache, $namespaces ) = @_;

	my @l = ();
	SUBJECT: foreach my $subject ( sort keys %{$cache} )
	{
		my $trips = $cache->{$subject};
		my @preds = ();
		PREDICATE: foreach my $pred ( sort keys %{ $trips } )
		{
			my @objects = ();
			OBJECT: foreach my $val ( sort {$a->[0] cmp $b->[0]} values %{$trips->{$pred}} )
			{
				if( !defined $val->[1] )
				{
					my $uri = expand_uri($val->[0],$namespaces);
					next OBJECT if !defined $uri;
					push @objects, $uri;
				}
				else
				{
					my $v = $val->[0];
					$v =~ s/\\/\\\\/g;
					$v =~ s/\'/\\'/g;
					$v =~ s/\"/\\"/g;
					$v =~ s/\n/\\n/g;
					$v =~ s/\r/\\r/g;
					$v =~ s/\t/\\t/g;
					my $data = '"'.$v.'"';
					if( defined $val->[2] )
					{
						$data.='@'.$val->[2];
					}
					if( $val->[1] ne "literal" )
					{
						$data.='^^'.expand_uri( $val->[1], $namespaces );
					}
					push @objects, $data;
				}
			}
			push @preds, "\t".$pred." ".join( ",\n		", @objects );
		}
		my $uri = expand_uri($subject,$namespaces);
		next SUBJECT if !defined $uri;
		push @l, "$uri\n".join( ";\n", @preds )." .\n\n";
	}
	return join ('',@l);
}

sub expand_uri 
{
	my( $obj_id, $namespaces ) = @_;

	if( $obj_id =~ /^<(.*)>$/ ) { return $obj_id; }

	if( ! $obj_id =~ m/:/ ) { 
		warn "Neither <uri> nor namespace prefix in RDF data: $obj_id";
		return;
	}

	my( $ns, $value ) = split( /:/, $obj_id, 2 );
	if( !defined $namespaces->{$ns} )
	{
		warn "Unknown namespace prefix '$ns' in RDF data: $obj_id";
		return;
	}

	return "<".$namespaces->{$ns}.$value.">";
}

	
	
	
1;
