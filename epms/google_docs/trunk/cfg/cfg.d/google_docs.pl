use EPrints::DataObj::OAuth;

$c->{datasets}->{oauth} = {
	sqlname => "oauth",
	class => "EPrints::DataObj::OAuth",
	import => 0,
	index => 0,
	order => 0,
};

$c->{plugins}{"Screen::EPrint::UploadMethod::Google"}{params}{disable} = 0;
