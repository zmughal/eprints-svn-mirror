package EPrints::Plugin::Convert;

=pod

=head1 NAME

EPrints::Plugin::Convert - Convert EPrints::Document into different formats

=head1 DESCRIPTION

This plugin and its dependents allow EPrints to convert documents from one format into another format.

=head1 METHODS

=over 5

=cut

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::Output::ABSTRACT = 1;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();
	$d{id} = "convert/abstract";
	$d{name} = "Base convert plugin: This should have been subclassed";
	return %d;
}

sub type
{
	return "convert";
}

sub render_name
{
	my( $plugin ) = @_;

	return $plugin->{session}->make_text( $plugin->{name} );
}

=pod

=item @types = $p->can_convert( $eprint, $doc )

Returns a list of mime-types that this plugin can convert the document $doc to.

=cut

sub can_convert
{
	my ($plugin, $eprint, $doc) = @_;

	return ();
}

=pod

=item $success = $p->convert( $eprint, $doc, $type )

Convert $doc to format $type and store the result in $eprint. Returns undef on failure.

=cut

sub convert
{
	my ($plugin, $eprint, $doc, $type) = @_;

	return undef;
}

1;

__END__

=back
