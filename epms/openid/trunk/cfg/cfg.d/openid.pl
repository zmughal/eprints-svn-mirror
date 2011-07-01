
push @{$c->{fields}->{user}},
	{ name=>"openid_identifier", type=>"text", virtual=>1, show_in_html=>0, export_as_xml=>0, },
;

$c->{datasets}->{openid} = {
	sqlname => "openid",
	class => "EPrints::DataObj::OpenID",
	import => 0,
	index => 0,
	order => 0,
};

use EPrints::DataObj::OpenID;

$c->{plugins}{'Screen::Login::OpenID'}{params}{disable} = 0;
$c->{plugins}{'Screen::Register::OpenID'}{params}{disable} = 0;
