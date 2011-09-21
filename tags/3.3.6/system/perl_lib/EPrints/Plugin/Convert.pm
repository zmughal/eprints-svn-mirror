package EPrints::Plugin::Convert;

=pod

=head1 NAME

EPrints::Plugin::Convert - Convert EPrints::DataObj::Document into different formats

=head1 DESCRIPTION

This plugin and its dependents allow EPrints to convert documents from one format into another format. Convert plugins are also used by the full-text indexer to extract plain-text from documents.

Convert plugins may provide conversions from any number of formats to any number of other formats (or not even 'formats' per-se e.g. unpacking/packing archives). A single plugin may represent a particular software package (e.g. ImageMagick) or a common goal (e.g. textifying documents for indexing).

Using the root Convert plugin it is possible to query all loaded conversion plugins for available conversions from a given L<EPrints::DataObj::Document>.

To allow for simpler local configuration Convert plugins should use SystemSettings to store the location of external programs.

=head1 SYNOPSIS

	my $root = $session->plugin( 'Convert' );

	my %available = $root->can_convert( $document );

	# Convert a document to plain-text
	my $txt_tool = $available{'text/plain'};
	my $plugin = $txt_tool->{ plugin };
	$plugin->convert( $eprint, $document, 'text/plain' );

=head1 METHODS

=over 4

=cut

use strict;
use warnings;

use EPrints::Utils;

our @ISA = qw/ EPrints::Plugin /;


######################################################################
=pod

=item new OPTIONS

Create a new plugin object using OPTIONS (should only be called by L<EPrints::Session>).

=cut
######################################################################

sub new
{
	my( $class, %params ) = @_;

	$params{visible} = exists $params{visible} ? $params{visible} : "all";

	return $class->SUPER::new( %params );
}

######################################################################
=pod

=item $xhtml = $plugin->render_name

Return the name of this plugin as a chunk of XHTML.

=cut
######################################################################

sub render_name
{
	my( $plugin ) = @_;

	return $plugin->{session}->make_text( $plugin->{name} );
}

######################################################################
=pod

=item $plugin->is_visible( $level )

Returns whether this plugin is visible at level (currently 'all' or '').

=cut
######################################################################

# all or ""
sub is_visible
{
	my( $plugin, $vis_level ) = @_;
	return( 1 ) unless( defined $vis_level );

	return( 0 ) unless( defined $plugin->{visible} );

	if( $vis_level eq "all" && $plugin->{visible} ne "all" ) {
		return 0;
	}

	return 1;
}

=pod

=item %types = $p->can_convert( $doc )

Returns a hash of types that this plugin can convert the document $doc to. The key is the type. The value is a hash ref containing:

=over 4

=item plugin

The object that can do the conversion.

=item encoding

The encoding this conversion generates (e.g. 'utf-8').

=item phraseid

A unique phrase id for this conversion.

=item preference

A value between 0 and 1 representing the 'quality' or confidence in this conversion.

=back

=cut

sub can_convert
{
	my ($plugin, $doc, $type) = @_;
	
	my $session = $plugin->{ "session" };
	my @ids = $session->plugin_list( type => 'Convert' );

	my %types;
	for(@ids)
	{
		next if $_ eq $plugin->get_id;
		my %avail = $session->plugin( $_ )->can_convert( $doc, $type );
		while( my( $mt, $def ) = each %avail )
		{
			next if defined( $type ) && $mt ne $type;
			if(
				!exists($types{$mt}) ||
				!$types{$mt}->{ "preference" } ||
				(defined($def->{ "preference" }) && $def->{ "preference" } > $types{$mt}->{ "preference" })
			) {
				$types{$mt} = $def;
			}
		}
	}

	return %types;
}

=pod

=item @filelist = $p->export( $dir, $doc, $type )

Convert $doc to $type and export it to $dir. Returns a list of file names that resulted from the conversion. The main file (if there is one) is the first file name returned. Returns empty list on failure.

=cut

sub export
{
	my ($plugin, $dir, $doc, $type) = @_;

	return undef;
}

=pod

=item $doc = $p->convert( $eprint, $doc, $type [, $epdata ] )

Convert $doc to format $type (as returned by can_convert). Stores the resulting $doc in $eprint, and returns the new document or undef on failure.

Optionally initialise the new document with $epdata. Specifying 'files' in $epdata will cause the converted file content to be discarded.

=cut

sub convert
{
	my ($plugin, $eprint, $doc, $type, $epdata) = @_;

	my $dir = File::Temp->newdir( "ep-convertXXXXX", TMPDIR => 1 );

	my @files = $plugin->export( $dir, $doc, $type );
	unless( @files ) {
		return undef;
	}

	my $main_file = $files[0];

	my $session = $plugin->{session};

	my @handles;

	my @filedata;
	foreach my $filename (@files)
	{
		my $fh;
		unless( open($fh, "<", "$dir/$filename") )
		{
			$session->get_repository->log( "Error reading from $dir/$filename: $!" );
			next;
		}
		push @filedata, {
			filename => $filename,
			filesize => (-s "$dir/$filename"),
			url => "file://$dir/$filename",
			_content => $fh,
		};
		# file is closed after object creation
		push @handles, $fh;
	}

	my $doc_ds = $session->dataset( "document" );
	my $new_doc = $doc_ds->create_object( $session, { 
		files => \@filedata,
		main => $main_file,
		eprintid => $eprint->get_id,
		_parent => $eprint,
		format => $type,
		security => $doc->value( "security" ),
		formatdesc => $plugin->{name} . ' conversion from ' . $doc->get_type . ' to ' . $type,
		relation => [{
			type => EPrints::Utils::make_relation( "isVersionOf" ),
			uri => $doc->internal_uri(),
		},{
			type => EPrints::Utils::make_relation( "isVolatileVersionOf" ),
			uri => $doc->internal_uri(),
		}],
		%{$epdata||{}},
	} );

	for(@handles)
	{
		close($_);
	}

	if( !defined $new_doc )
	{
		$session->log( "Failed to create document object during conversion: check your storage configuration" );
		return ();
	}

	return wantarray ? ($new_doc) : $new_doc;
}

1;

__END__

=back

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

