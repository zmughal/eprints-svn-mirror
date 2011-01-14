package EPrints::Plugin::Convert;

=pod

=head1 NAME

EPrints::Plugin::Convert - Convert EPrints::DataObj::Document into different formats

=head1 DESCRIPTION

This plugin and its dependents allow EPrints to convert documents from one format into another format.

=head1 METHODS

=over 5

=cut

use strict;
use warnings;

use EPrints::TempDir;
use EPrints::SystemSettings;
use EPrints::Utils;

our @ISA = qw/ EPrints::Plugin /;


sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Base convert plugin";
	$self->{visible} = "all";

	return $self;
}

sub render_name
{
	my( $plugin ) = @_;

	return $plugin->{session}->make_text( $plugin->{name} );
}

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

=item $repository = $p->get_repository

Returns the current respository

=cut

sub get_repository
{
	my( $plugin ) = @_;
	
	return $plugin->{ "session" }->get_repository;
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
	my ($plugin, $doc) = @_;
	
	my $session = $plugin->{ "session" };
	my @ids = $session->plugin_list( type => 'Convert' );

	my %types;
	for(@ids)
	{
		next if $_ eq $plugin->get_id;
		my %avail = $session->plugin( $_ )->can_convert( $doc );
		while( my( $mt, $def ) = each %avail )
		{
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

=item $doc = $p->convert( $eprint, $doc, $type )

Convert $doc to format $type. Stores the resulting $doc in $eprint, and returns the new document or undef on failure.

=cut

sub convert
{
	my ($plugin, $eprint, $doc, $type) = @_;

	my $dir = EPrints::TempDir->new( "ep-convertXXXXX", UNLINK => 1);

	my @files;
	unless( @files = $plugin->export( $dir, $doc, $type ) ) {
		return undef;
	}

	my $session = $plugin->{session};

	my $doc_ds = $session->get_repository->get_dataset( "document" );
	my $new_doc = $doc_ds->create_object( $session, { 
		eprintid => $eprint->get_id,
		type => $type,
		format_desc => $plugin->{name} . ' conversion from ' . $doc->get_type . ' to ' . $type } );
	$new_doc->add_file( $_ ) for map { "$dir/$_" } @files;
	$new_doc->commit; # can this be done without a commit at all?

	return $new_doc;
}

1;

__END__

=back