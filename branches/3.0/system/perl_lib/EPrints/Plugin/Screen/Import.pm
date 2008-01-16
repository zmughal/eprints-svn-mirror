
package EPrints::Plugin::Screen::Import;

use EPrints::Plugin::Screen;

use Fcntl qw(:DEFAULT :seek);
use File::Temp qw/ tempfile /;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ test import /];

	$self->{appears} = [
		{
			place => "item_tools",
			position => 200,
		}
	];

	return $self;
}

sub properties_from
{

	my( $self ) = @_;
	
	$self->SUPER::properties_from;

	my $pluginid = $self->{session}->param( "pluginid" );
	
	if( defined $pluginid )
	{
		my $plugin = $self->{session}->plugin( $pluginid, session=>$self->{session}, dataset=>$self->{session}->get_repository->get_dataset( "inbox" ), processor=>$self->{processor} );
		if( !defined $plugin || $plugin->broken )
		{
			$self->{processor}->add_message( "error", $self->{session}->html_phrase( "general:bad_param" ) );
			return;
		}

		my $req_plugin_type = "list/eprint";
		unless( $plugin->can_produce( $req_plugin_type ) )
		{
			$self->{processor}->add_message( "error", $self->{session}->html_phrase( "general:bad_param" ) );
			return;
		}

		$self->{processor}->{plugin} = $plugin;

	}
}

sub can_be_viewed
{
	my( $self ) = @_;
	return $self->allow( "create_eprint" );
}

sub allow_test
{
	my( $self ) = @_;
	return $self->can_be_viewed;
}

sub allow_import
{
	my( $self ) = @_;
	return $self->allow_test;
}

sub action_test
{
	my ( $self ) = @_;

	my $tmp_file = $self->make_tmp_file;
	return if !defined $tmp_file;

	$self->_import( 1, 0, $tmp_file ); # dry run with messages

	undef $tmp_file;
}

sub action_import
{
	my ( $self ) = @_;

	my $tmp_file = $self->make_tmp_file;
	return if !defined $tmp_file;

	my $ok = $self->_import( 1, 1, $tmp_file ); # quiet dry run
	$self->_import( 0, 0, $tmp_file ) if $ok; # real run with messages

	undef $tmp_file;

	$self->{processor}->{screenid} = "Items";
}


sub make_tmp_file
{
	my ( $self ) = @_;

	# Write import records to temp file
	my $tmp_file = new File::Temp;
	$tmp_file->autoflush;

	my $import_fh = $self->{session}->{query}->upload( "import_filename" );
	my $import_data = $self->{session}->param( "import_data" );

	unless( defined $import_fh || ( defined $import_data && $import_data ne "" ) )
	{
		$self->{processor}->add_message( "error", $self->html_phrase( "nothing_to_import" ) );
		return undef;
	}

	if( defined $import_fh )
	{
		seek( $import_fh, 0, SEEK_SET );

		my( $buffer );
		while( read( $import_fh, $buffer, 1024 ) )
		{
			print $tmp_file $buffer;
		}
	}
	else
	{
		print $tmp_file $import_data;
	}

	return $tmp_file;
}

sub _import
{
	my( $self, $dryrun, $quiet, $tmp_file ) = @_;

	my $session = $self->{session};
	my $ds = $session->get_repository->get_dataset( "inbox" );
	my $user = $self->{processor}->{user};

	my $plugin = $self->{processor}->{plugin};

	my $handler = EPrints::Plugin::Screen::Import::Handler->new(
		processor => $self->{processor},
	);

	$plugin->{Handler} = $handler;
	$plugin->{parse_only} = $dryrun;

	my $err_file = File::Temp->new(
		UNLINK => 1
	);

	# We'll capture anything from STDERR that an import library may
	# spew out
	{
	# Perl complains about OLD_STDERR being used only once with warnings
	no warnings;
	open(OLD_STDERR, ">&STDERR") or die "Failed to save STDERR";
	}
	open(STDERR, ">$err_file") or die "Failed to redirect STDERR";

	my @problems;

	# Don't let an import plugin die() on us
	eval {
		$plugin->input_file(
			dataset=>$ds,
			filename=>"$tmp_file",
			user=>$user,
		);
	};
	push @problems, "Unhandled exception in ".$plugin->{id}.": $@" if $@;

	my $count = $dryrun ? $handler->{parsed} : $handler->{wrote};

	open(STDERR,">&OLD_STDERR") or die "Failed to restore STDERR";

	seek( $err_file, 0, SEEK_SET );

	while(<$err_file>)
	{
		$_ =~ s/^\s+//;
		$_ =~ s/\s+$//;
		next unless length($_);
		push @problems, "Unhandled warning in ".$plugin->{id}.": $_";
	}

	splice(@problems,100);
	for(@problems)
	{
		s/^(.{400}).*$/$1 .../s;
		$self->{processor}->add_message( "warning", $session->make_text( $_ ));
	}

	my $ok = (scalar(@problems) == 0 and $count > 0);

	if( $dryrun )
	{
		if( $ok )
		{
			$self->{processor}->add_message( "message", $session->html_phrase(
				"Plugin/Screen/Import:test_completed", 
				count => $session->make_text( $count ) ) ) unless $quiet;
		}
		else
		{
			$self->{processor}->add_message( "warning", $session->html_phrase( 
				"Plugin/Screen/Import:test_failed", 
				count => $session->make_text( $count ) ) );
		}
	}
	else
	{
		if( $ok )
		{
			$self->{processor}->add_message( "message", $session->html_phrase( 
				"Plugin/Screen/Import:import_completed", 
				count => $session->make_text( $count ) ) );
		}
		else
		{
			$self->{processor}->add_message( "warning", $session->html_phrase( 
				"Plugin/Screen/Import:import_failed", 
				count => $session->make_text( $count ) ) );
		}
	}
}

sub redirect_to_me_url
{
	my( $self ) = @_;
	return $self->SUPER::redirect_to_me_url."&import_filename=" . $self->{session}->param( "import_filename" ) . "&pluginid=" . $self->{processor}->{plugin}->get_id;
}

sub render
{
	my ( $self ) = @_;

	my $session = $self->{session};
	my $ds = $session->get_repository->get_dataset( "inbox" );

	my $page = $session->make_doc_fragment;

	# Preamble
	$page->appendChild( $self->html_phrase( "intro" ) );

	my $form =  $session->render_form( "post" );
	$form->appendChild( $session->render_hidden_field( "screen", $self->{processor}->{screenid} ) );
	$page->appendChild( $form );

	my $table = $session->make_element( "table", width=>"100%" );

	my $frag = $session->make_doc_fragment;
	$frag->appendChild( $session->make_element(
		"textarea",
		"accept-charset" => "utf-8",
		name => "import_data",
		rows => 10,
		cols => 50,
		wrap => "virtual" ) );
	$frag->appendChild( $session->make_element( "br" ) );
	$frag->appendChild( $session->make_element( "br" ) );
	$frag->appendChild( $session->render_upload_field( "import_filename" ) );

	$table->appendChild( $session->render_row_with_help(
		help => $session->make_doc_fragment,
		label => $self->html_phrase( "step1" ),
		class => "ep_first",
		field => $frag,
	));
	
	my @plugins = $session->plugin_list( 
			type=>"Import",
			is_advertised=>1,
			is_visible=>"all",
			can_produce=>"list/".$ds->confid );

	my $select = $session->make_element( "select", name => "pluginid" );
	$table->appendChild( $session->render_row_with_help(
		help => $session->make_doc_fragment,
		label => $self->html_phrase( "step2" ),
		field => $select,
	));
	
	for( @plugins )
	{
		my $plugin = $session->plugin( $_,
			processor => $self->{processor},
		);
		next if $plugin->broken;
		my $opt = $session->make_element( "option", value => $_  );
		$opt->setAttribute( "selected", "selected" ) if $self->{processor}->{plugin} && $_ eq $self->{processor}->{plugin}->get_id;
		$opt->appendChild( $plugin->render_name );
		$select->appendChild( $opt );
	}

	$form->appendChild( $session->render_toolbox( undef, $table ) );

	$form->appendChild( $session->render_action_buttons( 
		_class => "ep_form_button_bar",
		test => $self->phrase( "action:test:title" ), 
		import => $self->phrase( "action:import:title" ) ) );

	return $page;

}

package EPrints::Plugin::Screen::Import::Handler;

sub new
{
	my( $class, %self ) = @_;

	$self{wrote} = 0;
	$self{parsed} = 0;

	bless \%self, $class;
}

sub message
{
	my( $self, $type, $msg ) = @_;

	$self->{processor}->add_message( $type, $msg );
}

sub parsed
{
	my( $self, $epdata ) = @_;

	$self->{parsed}++;
}

sub object
{
	my( $self, $dataset, $dataobj ) = @_;

	$self->{wrote}++;
}

1;
