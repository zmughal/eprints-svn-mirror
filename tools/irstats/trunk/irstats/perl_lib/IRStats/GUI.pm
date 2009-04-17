package IRStats::GUI;

use strict;

sub handler
{
	my( $r ) = @_;
	my $eprints_session = EPrints::Session->new();
	my $session = IRStats->new(
		eprints_session => $eprints_session, request => $r
	);

	my %self = (
		session => $session,
	);
	my $cgi = $session->cgi;

	my $page = $cgi->param( 'page' ) || 'stats';

	my $class = $page;
	$class =~ s/\W+//g;
	$class = "IRStats::GUI::$class";

	eval "use $class";
	if( $@ )
	{
		Carp::confess "No such page [$page]: $@\n";
	}

	binmode(STDOUT,":utf8");

	my $self = bless \%self, $class;
	$self->generate;

	return 0;
}

sub generate
{
	$_[0]->html_page;
}

sub html_page
{
	my( $self ) = @_;

	$self->header;
	$self->start_html;
	$self->body;
	$self->end_html;
}

sub header
{
	my( $self ) = @_;
	
	print $self->{session}->cgi->header('text/html; charset=UTF-8');
}

sub start_html
{
	my( $self ) = @_;
	
	my( $static_url ) = $self->{session}->get_conf->static_url;
	my $title = $self->title;

	print <<EOH;
<html>
<head>
<title>$title</title>
<style type='text/css' media='screen'>
\@import '$static_url/generic.css';
\@import '$static_url/screen.css';
</style>
<style type='text/css' media='print'>
\@import '$static_url/generic.css';
\@import '$static_url/print.css';
</style>
</head>
<body>
EOH

}

sub end_html
{
	my( $self ) = @_;

	print <<EOH;
</body>

</html>
EOH
}

sub title
{
	my( $self ) = @_;

	"IRStats";
}

1;
