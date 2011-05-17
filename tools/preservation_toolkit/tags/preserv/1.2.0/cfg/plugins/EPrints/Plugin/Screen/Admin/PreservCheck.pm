#####################################################################
#
# EPrints::Plugin::Screen::Admin::PreservCheck
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2011 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::Plugin::Screen::Admin::PreservCheck;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ postinst prerm edit_config /];
	
	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 1;
}

sub allow_action_postinst
{
	my ( $self ) = @_;

	return 1;
}

sub allow_action_prerm
{
	my ( $self ) = @_;

	return 1;
}

sub allow_edit_config
{
        my( $self ) = @_;
                
        return 1;
}

sub action_edit_config 
{
        my ( $self ) = @_;
        
        my $session = $self->{session};

        my $config_file = $self->{session}->param( "configfile" );

	if (!defined $config_file or $config_file eq "Admin::PreservCheck") {
		$config_file = "cfg/cfg.d/pronom.pl";
	}

        my $screen_id;

        if ((substr $config_file, 0,9) eq "cfg/cfg.d") {
                $config_file = substr $config_file, 4;
                $screen_id = "Admin::Config::View::Perl";
                my $redirect_url = $session->current_url() . "?screen=" . $screen_id . "&configfile=" . $config_file;
                $session->redirect( $redirect_url );
		exit();
        } else {
                $screen_id = $config_file;
                $self->{processor}->{screenid} = $screen_id;
        }
}

sub action_postinst
{
	my ( $self ) = @_;

	my $session = $self->{session};
	
	return $self->java_droid_check();
}

sub action_prerm
{
        my ( $self ) = @_;

        my $session = $self->{session};

        my $output_file = $session->get_repository->get_conf( "htdocs_path" ) . "/en/droid_classification_ajax.xml";

        my $rc = 0;
        my $message;

	if ( -e $output_file ) {
	        unlink($output_file) or $rc = 1;
	}

        if ($rc > 0) {
                $message = "Could not remove status log";
        }

        return ($rc,$message);

}

sub java_droid_check 
{
	
	my ( $self ) = @_;

	my $session = $self->{session};

	my $java = $session->get_repository->get_conf( 'executables', 'java' );
	
	my $droid = $session->get_repository->get_conf( 'executables', 'droid' );

	my $rc = 0;
	my $message;

	if (!defined $java) {
		$java = 'java';
	}
	
	my $ret = `$java -version 2>&1`;

	my $index = index $ret,"gij";

	if ($index > 0) {
		$message .= "Sun/Oracle Java is not installed/configured";
		$rc = 0.5;
	} else {
		$index = 0;
		$index = index $ret,"Environment";
		if ($index > 0) {
		} else {
			$message .= "Sun/Oracle Java is not installed/configured";
			$rc = 0.5;
		}
	}

	if (!defined $droid) {
		if (defined $message) {
			$message .= ", "; 
		}
		$message .= "DROID not installed";
		$rc = 0.5;
	}

	return ($rc,$message);
}

sub render 
{
	my ( $self ) = @_;
	
	my $session = $self->{session};

	my ($rc, $message_text) = $self->java_droid_check();

	if (!defined $message_text) {
		$self->action_edit_config()
	}

#	print STDERR $message_text;
	my $html = $session->make_doc_fragment;

	my $warning = $session->make_doc_fragment;

	my $message = $session->make_text($message_text);
	
	my $message_container = $session->make_doc_fragment;
	$message_container->appendChild($message);
	my $div = $session->make_element("div", align=>"center");
	$message_container->appendChild($div);
	
	my $screen_id = "Screen::".$self->{processor}->{screenid};
	my $screen = $session->plugin( $screen_id, processor => $self->{processor} );
	my $edit_button = $screen->render_action_button(
		{
			action => "edit_config",
			screen => $screen,
			screen_id => $screen_id,
			hidden => {
			configfile => "cfg/cfg.d/pronom.pl",
			}
		});
	$div->appendChild($edit_button);
	if ($rc > 0) {
		$warning = $session->render_message("error",$message_container);
	} else {
		$warning = $session->render_message("message",$message_container);
	}
	$html->appendChild($warning);

	return $html;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return undef;
}

1;
