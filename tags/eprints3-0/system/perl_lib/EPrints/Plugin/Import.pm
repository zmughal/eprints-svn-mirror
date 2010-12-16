package EPrints::Plugin::Import;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::Import::DISABLE = 1;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Base input plugin: This should have been subclassed";
	$self->{visible} = "all";
	$self->{advertise} = 1;

	return $self;
}

sub render_name
{
	my( $plugin ) = @_;

	return $plugin->{session}->make_text( $plugin->param("name") );
}

sub matches 
{
	my( $self, $test, $param ) = @_;

	if( $test eq "is_visible" )
	{
		return( $self->is_visible( $param ) );
	}
	if( $test eq "can_produce" )
	{
		return( $self->can_produce( $param ) );
	}
	if( $test eq "is_advertised" )
	{
		return( $self->param( "advertise" ) == $param );
	}

	# didn't understand this match 
	return $self->SUPER::matches( $test, $param );
}


# all, staff or ""
sub is_visible
{
	my( $plugin, $vis_level ) = @_;

	return( 1 ) unless( defined $vis_level );

	my $visible = $plugin->param("visible");
	return( 0 ) unless( defined $visible );

	if( $vis_level eq "all" && $visible ne "all" ) {
		return 0;
	}

	if( $vis_level eq "staff" && $visible ne "all" && $visible ne "staff" ) {
		return 0;
	}

	return 1;
}

sub can_produce
{
	my( $plugin, $format ) = @_;

	my $produce = $plugin->param( "produce" );
	foreach my $a_format ( @{$produce} ) {
		if( $a_format =~ m/^(.*)\*$/ ) {
			my $base = $1;
			return( 1 ) if( substr( $format, 0, length $base ) eq $base );
		}
		else {
			return( 1 ) if( $format eq $a_format );
		}
	}

	return 0;
}

=item $plugin->input_fh( fh => FILEHANDLE [, %opts] )

Import one or more objects from filehandle FILEHANDLE. FILEHANDLE should be set to binary semantics.

This method should by subclassed.

=cut

sub input_fh
{
	my( $plugin, %opts ) = @_;

	return undef;
}

=item $plugin->input_file( filename => FILENAME [, %opts] )

Opens FILENAME for reading, sets binary semantics and calls input_fh to actually read the file.

This method may be subclassed (e.g. see L<EPrints::Plugin::Import::TextFile>).

=cut

sub input_file
{
	my( $plugin, %opts ) = @_;

	my $fh;
	if( $opts{filename} eq '-' )
	{
		$fh = *STDIN;
	}
	else
	{
		unless( open($fh, "<", $opts{filename}) )
		{
			$plugin->error("Could not open file $opts{filename} for import: $!");

			return undef;
		}
		binmode($fh);
	}
	$opts{fh} = $fh;

	my $list = $plugin->input_fh( %opts );

	unless( $opts{filename} eq '-' )
	{
		close($fh);
	}

	return $list;
}

sub input_dataobj
{
	my( $plugin, $input_data ) = @_;

	my $epdata = $plugin->convert_input( $input_data );

	return $plugin->epdata_to_dataobj( $plugin->{dataset}, $epdata ); 
}

sub convert_input
{
	my( $plugin, $input_data ) = @_;

	my $r = "error. convert_dataobj should be overridden";

	$plugin->log( $r );
}

sub epdata_to_dataobj
{
	my( $plugin, $dataset, $epdata ) = @_;
	
	if( $plugin->{parse_only} )
	{
		if( $plugin->{session}->get_noise > 1 )
		{
			print STDERR "Would have imported an object into dataset ".$dataset->id."\n";
		}	
		if( $plugin->{scripted} )
		{
			print "EPRINTS_IMPORT: ITEM_PARSED\n";
		}
		return;
	}

	if( $dataset->id eq "eprint" && !defined $epdata->{eprint_status} )
	{
		$plugin->warning( "Importing an EPrint record into 'eprint' dataset without eprint_status being set. Using 'buffer' as default." );
		$epdata->{eprint_status} = "buffer";
	}

	my $item = $dataset->create_object( $plugin->{session}, $epdata );
	if( $plugin->{session}->get_noise > 1 )
	{
		print STDERR "Imported ".$dataset->id.".".$item->get_id."\n";
	}	
	if( $plugin->{scripted} )
	{
		print "EPRINTS_IMPORT: ITEM_IMPORTED ".$item->get_id."\n";
	}
	return $item;
}

sub warning
{
	my( $plugin, $msg ) = @_;

	$plugin->{session}->get_repository->log( $plugin->{id}.": ".$msg );
}	

sub error
{
	my( $plugin, $msg ) = @_;

	$plugin->warning( $msg );
}

1;