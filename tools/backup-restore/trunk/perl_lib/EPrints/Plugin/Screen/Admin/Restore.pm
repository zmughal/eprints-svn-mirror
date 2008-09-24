package EPrints::Plugin::Screen::Admin::Restore;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ restore_repository /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions", 
			position => 1245, 
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "repository/backup" );
}

sub allow_restore_repository
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_restore_repository
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $rc = 1;

	my $fname = $self->{prefix}."_first_file";

	my $fh = $session->get_query->upload( $fname );
	if( defined( $fh ) )
	{
		binmode($fh);
		my $tmpfile = File::Temp->new( SUFFIX => ".tgz" );
		binmode($tmpfile);

		use bytes;
		while(sysread($fh,my $buffer,4096)) {
			syswrite($tmpfile,$buffer);
		}

		seek($tmpfile, 0, 0);
	
		my $database_name = $self->{session}->get_repository->get_conf('dbname');
		my $database_password = $self->{session}->get_repository->get_conf('dbpass');
		my $database_user = $self->{session}->get_repository->get_conf('dbuser');
		my $database_host = $self->{session}->get_repository->get_conf('dbhost');
		my $repository_id = $self->{session}->get_repository->get_id;
		my $eprints_base_path = $self->{session}->get_repository->get_conf('base_path');
		
		my $check_path = EPrints::TempDir->new();
		my $tar_executable = $self->{session}->get_repository->get_conf('executables','tar');
		my $mysql_executable = 'mysql';
	
		`$tar_executable -zxf $tmpfile -C $check_path --same-owner`; 

		## Stage 1
		# Replace all config files in the untar'd backup with those specific to the local install.
		# Can't see a reason for this failing.
		##
		`cp -pf $eprints_base_path/archives/$repository_id/cfg/apapche.conf $check_path/cfg/`;
		`cp -pf $eprints_base_path/archives/$repository_id/var/auto-apapche.conf $check_path/var/`;
		`cp -pf $eprints_base_path/archives/$repository_id/cfg/cfg.d/10_core.pl $check_path/cfg/cfg.d/`;
		`cp -pf $eprints_base_path/archives/$repository_id/cfg/cfg.d/database.pl $check_path/cfg/cfg.d/`;
		#End
		
		## Insert the database
		# This could fail so needs some check code at some point 
		`echo "drop database $database_name" | mysql -u $database_user -p$database_password -h $database_host`; 
		`echo "create database $database_name" | mysql -u $database_user -p$database_password -h $database_host`; 
		my $local_database_file = `ls $check_path/tmp/`;
		`mysql -u $database_user -p$database_password -h $database_host $database_name < $check_path/tmp/$local_database_file`;
		`rm -fR $check_path/tmp/`;

		##Restore the archive
		# Again probably could go wrong
		`rm -fR $eprints_base_path/archives/$repository_id/*`;
		`cp -pR $check_path/* $eprints_base_path/archives/$repository_id/`;
		`rm -fR $check_path`;
		
		$self->{processor}->add_message( "message", $session->make_text( "Repsotory Restored" ) );
					
	}
	else
	{
		$self->{processor}->add_message( "error", $session->make_text( "made a boo-boo [".$session->get_query->param( $fname )."]" ) );
	}

	$self->{processor}->{screenid} = "Admin";
}	

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my( $html , $table , $p , $span );
	
	$html = $session->make_doc_fragment;

	my $form = $self->{session}->render_form( "POST" );

	my $inner_panel = $self->{session}->make_element( 
			"div", 
			id => $self->{prefix}."_upload_panel_file" );

	$inner_panel->appendChild( $self->html_phrase( "backup_archive" ) );

	my $ffname = $self->{prefix}."_first_file";	
	my $file_button = $session->make_element( "input",
		name => $ffname,
		id => $ffname,
		type => "file",
		);
	my $upload_progress_url = $session->get_url( path => "cgi" ) . "/users/ajax/upload_progress";
	my $onclick = "return startEmbeddedProgressBar(this.form,{'url':".EPrints::Utils::js_string( $upload_progress_url )."});";
	my $upload_button = $session->render_button(
		value => $self->phrase( "upload" ), 
		class => "ep_form_internal_button",
		name => "_action_restore_repository",
		onclick => $onclick );
	$inner_panel->appendChild( $file_button );
	$inner_panel->appendChild( $session->make_text( " " ) );
	$inner_panel->appendChild( $upload_button );
	my $progress_bar = $session->make_element( "div", id => "progress" );
	$inner_panel->appendChild( $progress_bar );

	my $script = $session->make_javascript( "EPJS_register_button_code( '_action_next', function() { el = \$('$ffname'); if( el.value != '' ) { return confirm( ".EPrints::Utils::js_string($self->phrase("really_next"))." ); } return true; } );" );
	$inner_panel->appendChild( $script);
	
	$inner_panel->appendChild( $session->render_hidden_field( "screen", $self->{processor}->{screenid} ) );
	$form->appendChild( $inner_panel );
	$form->appendChild( $session->render_hidden_field( "_action_restore_repository", "Upload" ) );
	$html->appendChild( $form );
	
	return $html;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return undef;
}

1;
