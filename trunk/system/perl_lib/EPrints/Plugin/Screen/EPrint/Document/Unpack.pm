=head1 NAME

EPrints::Plugin::Screen::EPrint::Document::Unpack

=cut

package EPrints::Plugin::Screen::EPrint::Document::Unpack;

# Use the Handler from Extract
use EPrints::Plugin::Screen::EPrint::Document::Extract;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint::Document' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{icon} = "action_unpack.png";

	$self->{appears} = [
		{
			place => "document_item_actions",
			position => 100,
		},
	];
	
	$self->{actions} = [qw/ cancel unpack explode /];

	$self->{ajax} = "interactive";

	return $self;
}

sub allow_cancel { 1 }
sub allow_unpack { shift->can_be_viewed( @_ ) }
sub allow_explode { shift->can_be_viewed( @_ ) }

sub can_be_viewed
{
	my( $self ) = @_;

	my $doc = $self->{processor}->{document};
	return 0 if !$doc;

	return 0 if !$self->SUPER::can_be_viewed;

	my @plugins = grep {
		$_->can_produce( "dataobj/document" ) &&
		$_->can_produce( "dataobj/eprint" )
	} $self->{session}->get_plugins(
		type => "Import",
		can_accept => $doc->value( "format" ),
	);

	return scalar(@plugins) > 0;
}

sub render
{
	my( $self ) = @_;

	my $doc = $self->{processor}->{document};

	my $frag = $self->{session}->make_doc_fragment;

	my $div = $self->{session}->make_element( "div", class=>"ep_block" );
	$frag->appendChild( $div );

	$div->appendChild( $self->render_document( $doc ) );

	$div = $self->{session}->make_element( "div", class=>"ep_block" );
	$frag->appendChild( $div );

	$div->appendChild( $self->html_phrase( "help" ) );
	
	my %buttons = (
		cancel => $self->{session}->phrase(
				"lib/submissionform:action_cancel" ),
		unpack => $self->phrase( "action_unpack" ),
		explode => $self->phrase( "action_explode" ),
		_order => [ qw( unpack explode cancel ) ]
	);

	my $form= $self->render_form;
	$form->appendChild( 
		$self->{session}->render_action_buttons( 
			%buttons ) );
	$div->appendChild( $form );

	return( $frag );
}	

sub action_unpack
{
	my( $self ) = @_;

	$self->{processor}->{redirect} = $self->{processor}->{return_to}
		if !$self->wishes_to_export;

	my $eprint = $self->{processor}->{eprint};
	my $doc = $self->{processor}->{document};

	return if !$doc;

	my $newdoc = $eprint->create_subdataobj( "documents", {} );
	$newdoc->remove if !$self->_expand( $newdoc );
}

sub action_explode
{
	my( $self ) = @_;

	$self->{processor}->{redirect} = $self->{processor}->{return_to}
		if !$self->wishes_to_export;

	my $eprint = $self->{processor}->{eprint};
	my $doc = $self->{processor}->{document};

	return if !$doc;

	$self->_expand( $eprint );
}

sub _expand
{
	my( $self, $dataobj ) = @_;

	my $eprint = $self->{processor}->{eprint};
	my $doc = $self->{processor}->{document};

	return if !$doc;

	# we ask the plugin to import into either documents or eprints
	# -> produce a single document or
	# -> produce lots of documents
	# the normal epdata_to_dataobj is intercepted (parse_only=>1) and we merge
	# the new documents into our eprint
	my $handler = EPrints::Plugin::Screen::EPrint::Document::Extract::Handler->new(
		processor => $self->{processor},
		parsed => sub {
			my( $epdata ) = @_;

			$epdata = [$epdata];
			if( $dataobj->isa( "EPrints::DataObj::EPrint" ) )
			{
				$epdata = $epdata->[0]->{documents};
			}

			foreach my $docdata (@$epdata)
			{
				$docdata->{relation} ||= [];
				push @{$docdata->{relation}}, {
					type => EPrints::Utils::make_relation( "isPartOf" ),
					uri => $doc->internal_uri
				};

				return $eprint->create_subdataobj( "documents", $docdata );
			}
		},
	);

	my( $plugin ) = grep {
		$_->can_produce( "dataobj/document" ) &&
		$_->can_produce( "dataobj/eprint" )
	} $self->{session}->get_plugins({
			Handler => $handler,
			parse_only => 1,
		},
		type => "Import",
		can_accept => $doc->value( "format" ),
	);

	return if !$plugin;

	my $file = $doc->stored_file( $doc->value( "main" ) );
	return if !$file;

	my $fh = $file->get_local_copy;

	my $list = $plugin->input_fh(
		fh => $fh,
		dataset => $dataobj->get_dataset,
	);
	return if !$list || !$list->count;

	$self->{processor}->{redirect} .= "&docid=".$list->item( 0 )->id
		if !$self->wishes_to_export;

	return 1;
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

