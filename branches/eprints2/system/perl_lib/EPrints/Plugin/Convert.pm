package EPrints::Plugin::Convert;

=pod

=head1 NAME

EPrints::Plugin::Convert - Convert EPrints::Document into different formats

=head1 DESCRIPTION

This plugin and its dependents allow EPrints to convert documents from one format into another format.

=head1 LAST MODIFIED BY

$Id$

=head1 METHODS

=over 5

=cut

use strict;
use warnings;

use EPrints::TempDir;
use EPrints::SystemSettings;

our @ISA = qw/ EPrints::Plugin /;

our $ABSTRACT = 1;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Base convert plugin: This should have been subclassed";
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

=pod

=item $archive = $p->archive()

Returns the current archive

=cut

sub archive { shift->{archive} }

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

=pod

=item $cmd = prepare_cmd($cmd,%VARS)

Prepare command string $cmd by substituting variables (specified by $(varname)) with their values from %VARS. All %VARS are quoted before replacement.

If a variable is specified in $cmd, but not present in %VARS a die is thrown.

=cut

sub prepare_cmd {
	my ($cmd, %VARS) = @_;
	$cmd =~ s/\$\(([\w_]+)\)/defined($VARS{$1}) ? quotemeta($VARS{$1}) : die("Unspecified variable $1 in $cmd")/seg;
	$cmd;
}

=pod

=item $mime_type = mime_type($fn)

Returns the mime-type of the file located at $fn, using the Unix file command.

=cut

sub mime_type
{
	my $fn = shift;
	die "File does not exist: $fn" unless -e $fn;
	die "Can not read file: $fn" unless -r $fn;
	die "Can not type a directory: $fn" if -d $fn;

	# Prepare the command to call
	my $file = $EPrints::SystemSettings::conf->{executables}->{file} || `which file` || 'file';
	chomp($file);
	my $file_cmd = $EPrints::SystemSettings::conf->{invocation}->{file} || '$(file) -b -i $(SOURCE)';
	my $cmd = prepare_cmd(
		$file_cmd,
		file => $file,
		SOURCE => $fn,
	);
	
	# Call file and return the mime-type found
	my $mt = `$cmd`;
	chomp($mt);
	($mt) = split /,/, $mt, 2; # file can return a 'sub-type'
	return length($mt) > 0 ? $mt : undef;
}

1;

__END__

=back
