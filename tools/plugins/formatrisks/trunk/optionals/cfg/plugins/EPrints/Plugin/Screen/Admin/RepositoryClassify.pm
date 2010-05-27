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

sub render
{

	my( $plugin ) = @_;

	my $session = $plugin->{session};

	my $plugin_datasets = {};
	
	my( $html, $h1 );

	my $repo = $session->get_repository->get_id();
	
	use Apache2::SubProcess();
	my @args_out;
	push @args_out, $repo;
	$r = $session->get_request;

	my $base_path = EPrints::Config::get( "base_path" );
	push @args_out, $base_path;

	my $command = $base_path . '/tools/update_pronom_puids_detached.pl';
	$r->spawn_proc_prog($command, \@args_out);

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
