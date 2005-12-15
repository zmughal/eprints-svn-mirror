package EPrints::Plugin::Convert;

=pod

=head1 NAME

EPrints::Plugin::Convert - Convert EPrints::Document into different formats

=head1 DESCRIPTION

This plugin and its dependents allow EPrints to convert documents from one format into another format.

=head1 LAST MODIFIED BY

$ Id $

=head1 METHODS

=over 5

=cut

use strict;
use warnings;

use EPrints::TempDir;
use EPrints::SystemSettings;

our @ISA = qw/ EPrints::Plugin /;

our $ABSTRACT = 1;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();
	$d{id} = "convert/abstract";
	$d{name} = "Base convert plugin: This should have been subclassed";
	$d{visible} = "all";
	$d{type} = "convert";
	return %d;
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

=pod

=item @types = $p->can_convert( $doc )

Returns a list of mime-types that this plugin can convert the document $doc to.

=cut

sub can_convert
{
	my ($plugin, $doc) = @_;

	return ();
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

	my $new_doc = EPrints::Document->create( $session, $eprint );
	
	$new_doc->set_format( $type );
	$new_doc->set_desc( $plugin->{name} . ' conversion from ' . $doc->get_type . ' to ' . $type );
	$new_doc->add_file( $_ ) for map { "$dir/$_" } @files;
	$new_doc->commit;

	return $new_doc;
}

1;

__END__

=back
