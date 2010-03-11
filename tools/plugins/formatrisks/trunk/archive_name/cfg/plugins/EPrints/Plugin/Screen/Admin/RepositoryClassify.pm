package EPrints::Plugin::Screen::Admin::RepositoryClassify;

@ISA = ( 'EPrints::Plugin::Screen' );

#use strict;
use threads;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ repository_classify /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions", 
			position => 1000, 
			#action => "repository_classify",
		},
	];

	return $self;
}

sub allow_regen_views
{
	my( $self ) = @_;

	return $self->allow( "config/edit" );
}

sub render
{
	my( $plugin ) = @_;

	my $session = $plugin->{session};

#	my $plugin_datasets = $plugin->fetch_data();
	my $plugin_datasets = {};
	
	my( $html, $h1 );

	my $foo;
	
	my $err_file = File::Temp->new(
                UNLINK => 1
        );

        {
        no warnings;
        open(OLD_STDERR, ">&STDERR") or die "Failed to save STDERR";
        }
        open(STDERR, ">$err_file") or die "Failed to redirect STDERR";	

	my $repo = $session->get_repository->get_id();

	my $fred = async { system("/usr/share/eprints3/tools/update_pronom_puids $repo ") };

	#open(STDERR,">&OLD_STDERR") or die "Failed to restore STDERR";

        #seek( $err_file, 0, SEEK_SET );

	#our $MAX_ERR_LEN = 1024;
	
	$html = $session->make_doc_fragment;
	
	my $input_url = $session->get_repository->get_conf( "base_url" ) . "/droid_classification_ajax.xml";

	my $javascript = $session->make_javascript('
	var ret;
	function ajaxFunction()
{
      var xmlhttp;
      if (window.XMLHttpRequest)
      {
            // code for IE7+, Firefox, Chrome, Opera, Safari
            xmlhttp=new XMLHttpRequest();
            }
      else
      {
            // code for IE6, IE5
            xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
      }
      xmlhttp.onreadystatechange=function()
      {
            if(xmlhttp.readyState == 4)
            {
                  ret = xmlhttp.responseText;
		  document.getElementById("status").innerHTML=ret;
            }
      }
      xmlhttp.open("GET","'.$input_url.'",true);
      xmlhttp.send(null);
}
setInterval("ajaxFunction()",3000);
');

        #while(<$err_file>)
        #{
        #        $_ =~ s/\s+$//;
        #        next unless length($_);
##		$html->appendText("$_<br/>");
#		$html->appendChild( $session->make_text("$_"));
#		$html->appendChild( $session->make_element( "br" ));
#                last if length($err) > $MAX_ERR_LEN;
#        }

	$html->appendChild($javascript);
	my $div = $plugin->{session}->make_element(
			"div",
			id => "status",
			align => "center" );
	$div->appendText("Processing...");
	$html->appendChild($div);
	return $html;

}



1;
