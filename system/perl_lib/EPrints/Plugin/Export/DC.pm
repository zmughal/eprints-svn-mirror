=head1 NAME

EPrints::Plugin::Export::DC

=cut

package EPrints::Plugin::Export::DC;

# eprint needs magic documents field

# documents needs magic files field

use EPrints::Plugin::Export::TextFile;

@ISA = ( "EPrints::Plugin::Export::TextFile" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Dublin Core";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "all";

	return $self;
}


sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj );

	my $r = "";
	foreach( @{$data} )
	{
		my( $term, $v, $opts ) = @$_;
		next if !defined $v;

		$v =~ s/[\r\n]/ /g;
		$term .= ".$opts->{lang}" if defined $opts->{lang};
		$r .= "$term: $v\n";
	}
	$r.="\n";
	return $r;
}

sub dataobj_to_html_header
{
	my( $plugin, $dataobj ) = @_;

	my $links = $plugin->{session}->make_doc_fragment;

	$links->appendChild( $plugin->{session}->make_element(
		"link",
		rel => "schema.DC",
		href => "http://purl.org/DC/elements/1.0/" ) );
	$links->appendChild( $plugin->{session}->make_text( "\n" ));
	my $dc = $plugin->convert_dataobj( $dataobj );
	foreach( @{$dc} )
	{
		$links->appendChild( $plugin->{session}->make_element(
			"meta",
			name => "DC.".$_->[0],
			content => $_->[1],
			%{$_->[2]} ) );
		$links->appendChild( $plugin->{session}->make_text( "\n" ));
	}
	return $links;
}

	

sub convert_dataobj
{
	my( $self, $eprint ) = @_;

	my $dataset = $eprint->{dataset};

	my @dcdata = (
		$self->simple_value( $eprint, title => "title" ),
		$self->simple_value( $eprint, abstract => "description" ),
		$self->simple_value( $eprint, creators_name => "creator" ),
		$self->simple_value( $eprint, editors_name => "contributor" ),
		$self->simple_value( $eprint, publisher => "publisher" ),
		$self->simple_value( $eprint, type => "type" ),
		$self->simple_value( $eprint, official_url => "relation" ),
		);

	if( $eprint->exists_and_set( "subjects" ) )
	{
		foreach my $subjectid ( @{$eprint->get_value( "subjects" )} )
		{
			my $subject = EPrints::DataObj::Subject->new( $self->{session}, $subjectid );
			# avoid problems with bad subjects
			next unless( defined $subject ); 
			foreach my $item (@{$subject->field_value( "name" )})
			{
				push @dcdata, [ subject => $item, { lang => $item->lang } ];
			}
		}
	}

	## Date for discovery. For a month/day we don't have, assume 01.
	if( $eprint->exists_and_set( "date" ) )
	{
		push @dcdata, [ date => $eprint->field_value( "date" )->iso_8601, {} ];
	}

	if( $eprint->exists_and_set( "refereed" ) && $eprint->value( "refereed" ) eq "TRUE" )
	{
		push @dcdata, [ type => "PeerReviewed", {} ];
	}
	else
	{
		push @dcdata, [ type => "NonPeerReviewed", {} ];
	}

	foreach( $eprint->get_all_documents() )
	{
		push @dcdata, [ "format", $_->value( "mime_type" ), {} ];
		push @dcdata, [ "identifier", $_->get_url(), {} ];
	}

	# The citation for this eprint
	push @dcdata, [ "identifier",
		EPrints::Utils::tree_to_utf8( $eprint->render_citation() ), {} ];

	# The URL of the abstract page
	if( $eprint->is_set( "eprintid" ) )
	{
		push @dcdata, [ "relation", $eprint->get_url(), {} ];
	}

	# dc.language not handled yet.
	# dc.source not handled yet.
	# dc.coverage not handled yet.
	# dc.rights not handled yet.

	return \@dcdata;
}

# map eprint values directly into DC equivalents
sub simple_value
{
	my( $self, $eprint, $fieldid, $term ) = @_;

	return () if !$eprint->exists_and_set( $fieldid );

	my @dcdata;

	foreach my $item (@{$eprint->field_value( $fieldid )})
	{
		push @dcdata, [ $term, $item, { lang => $item->lang } ];
	}

	return @dcdata;
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

