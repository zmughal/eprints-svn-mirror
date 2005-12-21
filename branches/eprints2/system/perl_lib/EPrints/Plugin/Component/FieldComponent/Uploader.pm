package EPrints::Plugin::Component::FieldComponent::Uploader;

use EPrints::Plugin::Component;
use EPrints::XML;
@ISA = ( "EPrints::Plugin::Component::FieldComponent" );

use Unicode::String qw(latin1);

use strict;

sub defaults
{
	my %d = $_[0]->SUPER::defaults();

	$d{id} = "component/uploader";
	$d{name} = "Uploader";
	$d{visible} = "all";

	return %d;
}


sub render
{
	my( $self, $defobj, $params ) = @_;


	my $session = $params->{session};
	my $workflow = $params->{workflow};

	my $doc = $session->{doc};
# moj: Move this into config file
my $component = EPrints::XML::parse_xml_string('<div class="wf_component">
<div class="wf_control_name">Document Upload</div>
<form id="uploadform" method="post" enctype="multipart/form-data" action="test.php">
<table id="uploader">
	<tr><td><div class="help">Please select the files you would like to add to this EPrint.</div></td></tr>
	<tr><td>

	<table id="filelist"> 
		<tbody id="fulllist">
		<tr><th>Filename</th><th>Primary File</th></tr>
		</tbody>
	</table>

	</td></tr>

	<tr><td><input id="file_element" type="file" name="file_1" /></td></tr>
	<tr><td align="right"><input type="submit" value="Continue" /></td></tr>
</table>
</form>
<script>
<!-- Create an instance of the multiSelector class, pass it the output target and the max number of files -->
var multi_selector = new MultiSelector( document.getElementById( \'fulllist\' ), 3 );
<!-- Pass in the file element -->
multi_selector.addElement( document.getElementById( \'file_element\' ) );
</script>
</div>');

	return EPrints::XML::clone_and_own( $component->getDocumentElement(), $doc, 1 );
}

1;





