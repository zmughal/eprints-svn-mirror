=head1 NAME

EPrints::Plugin::Export::Simple

=head1 DESCRIPTION

Exports the raw values from an eprint as a key-value list. This is primarily used to drive the <meta> tags included in the abstract page.

Fields that are stored as hash references are processed using L<EPrints::MetaField/text_value> to get a simple text value (e.g. Names).

To override the list of fields exported define the C<fields> parameter with an array reference of field names:

	$c->{plugins}{'Export::Simple'}{params}{fields} = [qw( title abstract )];

The citation and document URLs are always exported. To suppress these as well disable this plugin.

=cut

package EPrints::Plugin::Export::Simple;

use EPrints::Plugin::Export::TextFile;

@ISA = ( "EPrints::Plugin::Export::TextFile" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Simple Metadata";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{fields} = undef;

	return $self;
}


sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj );

	my $r = "";
	foreach( @{$data} )
	{
		next unless defined( $_->[1] );
		$r.=$_->[0].": ".$_->[1]."\n";
	}
	$r.="\n";
	return $r;
}

sub dataobj_to_html_header
{
	my( $plugin, $dataobj ) = @_;

	my $links = $plugin->{session}->make_doc_fragment;

	my $epdata = $plugin->convert_dataobj( $dataobj );
	foreach( @{$epdata} )
	{
		$links->appendChild( $plugin->{session}->make_element(
			"meta",
			name => "eprints.".$_->[0],
			content => $_->[1] ) );
		$links->appendChild( $plugin->{session}->make_text( "\n" ));
	}
	return $links;
}

sub convert_dataobj
{
	my( $plugin, $eprint ) = @_;

	my @epdata = ();
	my $dataset = $eprint->get_dataset;
	my $fieldnames = $plugin->param( "fields" );
	my @fields;
	if( defined $fieldnames )
	{
		@fields = map { $dataset->field( $_ ) } @$fieldnames;
	}
	else
	{
		@fields = grep {
				$_->property( "export_as_xml" ) &&
				!$_->is_virtual
			} $dataset->fields;
	}

	foreach my $field (@fields)
	{
		my $fieldname = $field->name;
		next unless $eprint->is_set( $fieldname );
		my $field = $dataset->get_field( $fieldname );
		my $value = $eprint->field_value( $fieldname );
		foreach my $item (@{$value})
		{
			push @epdata, [ $fieldname,
				$field->isa( "EPrints::MetaField::Name" ) ? 
					"$item" :
					$item->value
				];
		}
	}

	# The citation for this eprint
	push @epdata, [ "citation",
		EPrints::Utils::tree_to_utf8( $eprint->render_citation() ) ];

	foreach my $doc ( $eprint->get_all_documents )
	{
		push @epdata, [ "document_url", $doc->get_url() ];
	}

	return \@epdata;
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

